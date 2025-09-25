# Growth Aggregation Pipeline Runbook

Pipeline ID: `dag_growth_aggregate`  
Last Updated: 2025-09-25  
Version: 1.0

## 1. Purpose
Produce weekly and monthly growth KPIs (net new accounts, churn, expansion via increased seats or subscription tier upgrades) for executive / investor reporting and strategic product planning.

## 2. Ownership
| Aspect | Primary | Secondary | Notes |
|--------|---------|-----------|-------|
| Steady-State Domain | Jordan Lee | Sam Patel | Jordan on data quality; Sam performance tuning |
| On-Call (weekly) | Rotating DE | Next week's DE | See index rotation policy |
| Business Owner | Accounts Team Lead | Accounts lifecycle correctness |
| Product Analytics Partner | Growth Analytics | Interprets anomalies |

Escalation Ladder: Primary → Secondary → Data Eng Lead → Accounts Lead → Director Data Platform.

## 3. Schedule & SLAs
| Process | Frequency | Target Runtime (UTC) | Freshness SLA | Notes |
|---------|-----------|----------------------|---------------|-------|
| Weekly aggregation | Weekly (Mon) | 10:00 | Prior week closed | Draft KPIs for leadership |
| Monthly aggregation | Monthly | T+2 business days 16:00 | Month transitions finalized | Feeds investor roll-up |

Weekly SLA breach (missed by 14:00 UTC) = Sev2. Monthly breach = Sev1.

## 4. Data Sources
| Source | Layer | Description | Refresh |
|--------|-------|-------------|---------|
| `raw.crm.account_events` | Raw | Account lifecycle events (A→B→C) | Near daily |
| `silver.accounts.account_state_history` | Silver | Curated ordered state transitions | Daily |
| `silver.subscriptions.license_counts_daily` | Silver | Seat/license snapshots | Daily |
| `gold.profit.account_unit_daily` | Gold | Seat & revenue context (optional derived) | Daily |

## 5. Targets
| Target | Layer | Partitioning | Notes |
|--------|-------|-------------|-------|
| `gold.growth.weekly_summary` | Gold | `year_week` | Weekly KPIs |
| `gold.growth.monthly_summary` | Gold | `reporting_month` | Investor-facing growth metrics |
| `gold.growth.transition_integrity_audit` | Audit | `date` | Missing step tracking |

## 6. Dependencies
| Dependency | Type | Risk | Mitigation | Monitor |
|------------|------|------|-----------|--------|
| CRM export feed | External | Missing events / ordering | Sequence validation, idempotent loads | Event gap ratio |
| Seat snapshot job | Internal | Late snapshot | SLA check & imputation fallback | Missing partition alert |

## 7. Common Failure Modes & Detection
| ID | Failure Mode | Detection Signal | Severity |
|----|--------------|------------------|----------|
| FM1 | Missing intermediate transition (A→C skipping B) | missing_transition_proportion >0.005 | Sev2 |
| FM2 | Duplicate churn events | churn_duplicate_proportion >0.01 | Sev2 |
| FM3 | Late license snapshot | Snapshot absent by Monday 06:00 UTC | Sev2 |
| FM4 | Null / zero seat counts | Seat_count NULL proportion >1% | Sev2 |
| FM5 | Inflation of net new accounts | Recomputed balance mismatch > ±1 | Sev2 (Sev1 if monthly) |

## 8. Run Architecture Overview
1. Consume raw account events; sort & dedupe.  
2. Build state transition chain enforcing valid sequences.  
3. Generate seat / license deltas.  
4. Derive churn, expansion, contraction, net new.  
5. Aggregate weekly & monthly; apply anomaly checks.  
6. Publish & notify.

## 9. Triage Playbooks
| Failure Mode | Immediate Actions | Remediation | Validation |
|--------------|-------------------|-------------|-----------|
| FM1 Missing B | Flag integrity; synthetic B from last known state; log imputation | Coordinate with CRM to patch historical record | Missing_B ratio <0.1% |
| FM2 Dup churn | Run de-dup keyed on (account_id, event_type, event_ts) | Patch ingest unique constraint | churn_duplicate_proportion <0.005 |
| FM3 Late snapshot | Retry snapshot task; if still absent mark week PARTIAL | Impute seats from last day & flag | Freshness restored |
| FM4 Null seats | Backfill from previous day or subscription metadata | Add QA rule to seat load | Null seat count = 0 |
| FM5 Balance mismatch | Recompute from state history; compare to derived aggregate | Identify offending event sequence; correct & rebuild | Balance diff = 0 |

## 10. Backfill Strategy
| Scenario | Command (conceptual) | Notes |
|----------|---------------------|-------|
| Weekly recompute | `growth_reprocess --week=YYYY-WW` | Non-destructive overwrite |
| Monthly recompute | `growth_reprocess --month=YYYY-MM` | Requires locking weekly table |
| Sequence fix | `growth_repair --account-id=XYZ --from=DATE` | Rebuild transitions subset |

## 11. Validation Checklist
- Net new = new − churn matches delta in active accounts.  
- Churn + retained + new explains ending active count.  
- Seat expansion sum >= 0 (no negative expansion).  
- No missing weeks.  

## 12. Rollback Procedure
- For incorrect week: copy prior version from snapshot store (time-partitioned) & mark current as `REVOKED`.  
- Trigger reprocess after fix.  

## 13. Alert Configuration
| Alert | Threshold | Channel |
|-------|-----------|---------|
| Missing_B ratio | >0.5% | #data-alerts |
| churn_duplicate_proportion | >0.01 | #data-alerts |
| Snapshot late | Missing by 06:00 Mon | Pager (Sev2) |
| Balance mismatch | >1 account | #data-alerts |

## 14. RACI
| Activity | R | A | C | I |
|----------|---|---|---|---|
| Weekly ops | DE On-Call | Data Eng Lead | Accounts Team | Exec Stakeholders |
| Monthly publication | DE On-Call | Accounts Lead | Product Analytics | Exec Stakeholders |
| Sequence repair | DE On-Call | Data Eng Lead | CRM Ops | Product Analytics |

## 15. KPIs Monitored
- Net new accounts (trend).  
- Churn rate %.  
- Expansion MRR proxy (if available).  
- Missing transition ratio.  

## 16. Change Management
- Event schema changes require mapping update & test in staging.  
- Introduce new growth classification with feature flag field `growth_metric_version`.

## 17. Contacts
| Function | Channel |
|----------|---------|
| On-Call DE | #data-oncall |
| Accounts | #accounts-team |
| CRM Ops | #crm-ops |
| Product Analytics | #growth-exp |

---
End of Growth Runbook.
