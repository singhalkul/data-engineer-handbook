# Profit Aggregation Pipeline Runbook

Pipeline ID: `dag_profit_aggregate`  
Last Updated: 2025-09-25  
Version: 1.0

## 1. Purpose
Compute monthly and unit-level profit (revenue − expenses − allocated salary components) for investor reporting (monthly aggregates) and to feed experiment baselines (unit/account granularity). Investor-facing dataset is the aggregated, finalized monthly layer.

## 2. Ownership
| Aspect | Primary | Secondary | Notes |
|--------|---------|-----------|-------|
| Steady-State Domain | Divya Dhar | Aikya Shah | Finance collaboration & analytics alignment |
| On-Call (weekly) | Rotating DE | Next week's DE | See index rotation policy |
| Business Validation | Finance Team | Finance Analyst | Revenue & cost sign-off |
| Data Quality | Finance Analyst | Divya Dhar | Ledger version & reconciliation |

Escalation Ladder: Primary → Secondary → Data Eng Lead → Finance Lead → Director Data Platform.

## 3. Schedule & SLAs
| Process | Frequency | Target Runtime (UTC) | Freshness SLA | Notes |
|---------|-----------|----------------------|---------------|-------|
| Daily incremental | Daily | 05:00 | Previous day revenue + rolling cost preview | Used for anomaly early detection |
| Monthly finalization | Monthly | T+3 business days 18:00 | All cost ledger + salary allocations published | Generates authoritative snapshot |

Failure to finalize by SLA = Sev1.

## 4. Data Sources
| Source Table / System | Layer | Description | Refresh Pattern |
|-----------------------|-------|-------------|-----------------|
| `raw.finance.account_revenue_daily` | Raw | Daily revenue per account | Daily extract |
| `raw.finance.cost_ledger_monthly` | Raw | Monthly cost components (infra, SaaS) | Published T+2 |
| `raw.hr.team_salary_allocations` | Raw | Salary allocations per cost center | Monthly |
| `silver.accounts.dim_accounts` | Silver | Account metadata, seat counts | Daily |

## 5. Targets
| Target Table / Asset | Layer | Partitioning | Notes |
|----------------------|-------|--------------|-------|
| `gold.profit.account_unit_daily` | Gold | `date` | Unit-level profit feed to experiments |
| `gold.profit.monthly_summary` | Gold | `reporting_month` | Versioned; authoritative for investors |
| `gold.profit.ledger_version_manifest` | Meta | `reporting_month` | Tracks ledger + salary allocation versions |

## 6. Dependencies
| Dependency | Type | Risk | Mitigation | Monitor Signal |
|------------|------|------|-----------|----------------|
| Cost ledger publication | External (Finance) | Delay stalls final snapshot | SLA agreement; version manifest gating | Missing ledger version Day+2 noon |
| Account dimension | Data Model | New cost centers unmapped | Daily completeness test | Null `cost_center_id` proportion |
| Spark cluster | Compute | OOM on wide joins | Adaptive execution, partition tuning | OOM error code frequency |

## 7. Common Failure Modes & Detection
| ID | Failure Mode | Detection Signal | Severity |
|----|--------------|------------------|----------|
| FM1 | Ledger version missing | Alert if version absent Day+2 12:00 UTC | Sev2 → Sev1 Day+3 |
| FM2 | Revenue extract late | Freshness > 24h | Sev2 |
| FM3 | Duplicate revenue rows | duplicate_proportion > 0.02 | Sev2 |
| FM4 | Join OOM / shuffle explosion | Spark OOM / stage retries > 3 | Sev2 |
| FM5 | Negative profit anomalies | Account margin < -50% (z-score < -3) | Sev2 |

## 8. Run Architecture Overview
1. Ingest raw revenue & cost datasets.  
2. Normalize + map accounts & cost centers.  
3. Calculate unit-level metrics (per account per day).  
4. Aggregate to monthly with ledger versions; persist snapshot; update manifest.  
5. Reconcile vs Finance sources (tolerance ±0.1%).  
6. Publish to Gold + notify stakeholders.

## 9. Triage Playbooks
| Failure Mode | Immediate Actions | Remediation | Validation |
|--------------|-------------------|-------------|-----------|
| FM1 Ledger missing | Set pipeline status = WAITING; notify #finance | Confirm expected publish time; rerun finalize task once published | Manifest shows version; reconciles |
| FM2 Revenue late | Retry extract task; check upstream API status | If persistent, mark daily incremental partial; proceed with previous day data | Freshness restored <12h |
| FM3 Duplicates | Run duplicate detection job; isolate dupes to quarantine | Adjust source extraction key / enable hashing | duplicate_proportion <0.01 |
| FM4 OOM | Inspect Spark UI; enable AQE; reduce partitions; broadcast dim | Scale cluster if recurring; create optimization ticket | Job completes within 1.2x median time |
| FM5 Negative anomalies | Sample rows for impacted accounts; verify revenue double counted or cost spike | Correct mapping / remove dup rows & re-aggregate | Margins within historical range |

## 10. Backfill Strategy
| Scenario | Command (conceptual) | Notes |
|----------|---------------------|-------|
| Missing month finalization | `profit_backfill --months=YYYY-MM --mode=full` | Run after ledger published |
| Single account correction | `profit_backfill --account-id=XYZ --dates=YYYY-MM-DD:YYYY-MM-DD` | Triggers incremental recompute |
| Duplicate removal | `profit_dedupe --date=YYYY-MM-DD` then aggregate | Quarantine table updated |

Audit every backfill in `gold.profit.backfill_audit`.

## 11. Validation Checklist
- Revenue total delta vs Finance export < 0.1%.  
- Count of active accounts matches dimension table (±1 allowable for timing).  
- No NULL cost center or negative allocated cost.  
- Profit margin range sanity: (-10%, 95%).  
- Ledger version recorded for each month.

## 12. Rollback Procedure
- If new monthly summary incorrect: mark snapshot `status=REVOKED` in manifest; restore prior version pointer.  
- Rebuild monthly summary excluding faulty ledger version.  
- Notify #finance and #exec-metrics with summary & remediation ETA.

## 13. Alert Configuration (Conceptual)
| Alert | Threshold | Channel |
|-------|-----------|---------|
| Ledger missing | No version Day+2 12:00 UTC | Pager + #data-oncall |
| Revenue freshness | >24h | #data-alerts |
| duplicate_proportion | >0.02 | #data-alerts |
| Profit anomaly | >5 accounts margin < -50% | Pager (Sev2) |

## 14. RACI
| Activity | R | A | C | I |
|----------|---|---|---|---|
| Day-to-day ops | DE On-Call | Data Eng Lead | Finance | Exec Stakeholders |
| Ledger validation | Finance Analyst | Finance Lead | DE | Exec Stakeholders |
| Backfill execution | DE On-Call | Data Eng Lead | Finance | Stakeholders |
| Snapshot publication | DE On-Call | Finance Lead | Biz Analytics | Investors (indirect) |

## 15. KPIs Monitored
- Revenue vs prior 4-week moving average (z-score).  
- duplicate_proportion (target <0.01).  
- Time to finalize month (T+ days).  
- Data freshness hours (daily incremental).  

## 16. Change Management
- Schema changes require 2 business day notice in #data-changes.  
- Update runbook version after material process change.

## 17. Contacts
| Function | Channel |
|----------|---------|
| On-Call DE | #data-oncall |
| Finance | #finance |
| Data Platform | #data-platform |
| Escalation (Director) | @director-data |

---
End of Profit Runbook.
