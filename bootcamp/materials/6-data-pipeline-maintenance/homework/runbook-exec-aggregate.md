# Executive / Investor Aggregate Metrics Pipeline Runbook

Pipeline ID: `dag_exec_investor_rollup`  
Last Updated: 2025-09-25  
Version: 1.0

## 1. Purpose
Consolidate curated Profit, Growth, and Engagement gold layer datasets into unified executive & investor-facing KPI tables and snapshot exports used for board decks, CFO reviews, and investor updates. Ensures consistent cross-metric versioning & auditability.

## 2. Ownership
| Aspect | Primary | Secondary | Notes |
|--------|---------|-----------|-------|
| Steady-State Domain | Divya Rao | Aikya Menon | Maintains manifest logic & snapshot framework |
| On-Call (weekly) | Rotating DE | Next week's DE | See index rotation schedule |
| Business Owner | Business Analytics Team | Biz Analytics Backup | Metric definition & narrative approval |
| Finance Liaison | Finance Team | Finance Backup | Profit number sign-off |
| Accounts Liaison | Accounts Team | Accounts Backup | Growth validation |

Escalation Ladder: Primary → Secondary → Biz Analytics Lead → Data Eng Lead → Director Data Platform.

## 3. Schedule & SLAs
| Process | Frequency | Target Runtime (UTC) | Freshness / Delivery SLA | Notes |
|---------|-----------|----------------------|--------------------------|-------|
| Weekly preview build | Weekly (Wed) | 16:00 | All upstream weekly data in place | Internal review only |
| Month-end draft | Monthly | T+3 business days 16:00 | Upstream gold finalized (engagement allowed 1 late week) | Pre-CFO review |
| Month-end final | Monthly | T+4 business days 18:00 | Official investor packet | Sev1 if missed |

SLA Rationale: Investor consumption cadence (monthly/board) allows consolidation window; draft at T+3 balances need for early narrative alignment with data completeness; final at T+4 ensures late engagement week inclusion without sacrificing accuracy.

## 4. Data Sources (All Gold Unless Noted)
| Source | Description | Dependency Type |
|--------|-------------|-----------------|
| `gold.profit.monthly_summary` | Final profit figures with ledger versions | Upstream critical |
| `gold.growth.monthly_summary` | Net new, churn, expansion | Upstream critical |
| `gold.engagement.weekly_summary` | Engagement rolled up to month | Upstream important |
| `silver.calendar.dim_date` | Calendar mapping for week/month alignment | Reference |
| `silver.accounts.dim_accounts` | Account classification segments | Reference |

## 5. Targets
| Target | Layer | Partitioning | Notes |
|--------|-------|-------------|-------|
| `gold.exec.metrics_monthly` | Gold | `reporting_month` | Canonical investor KPIs |
| `gold.exec.metrics_weekly_preview` | Gold | `year_week` | Previews, not investor-official |
| `gold.exec.version_manifest` | Meta | `snapshot_id` | Links upstream dataset versions |
| Snapshot export (S3) | External | `year/month/metrics_snapshot_v{n}` | Immutable version chain |

## 6. Versioning & Manifest
Each monthly snapshot assigned `snapshot_id` and includes:  
- Profit ledger version  
- Growth dataset build hash  
- Engagement dataset watermark (latest included week)  
- Transformation code git commit hash  
A snapshot becomes "FINAL" status after CFO sign-off; prior states remain for audit.

## 7. Dependencies & Risks
| Dependency | Risk | Mitigation | Monitor |
|------------|------|-----------|--------|
| Profit dataset | Delay stalls final snapshot | Gated by manifest pre-check | Missing required version entry |
| Growth dataset | Inconsistent churn calculation | Recompute check vs prior week | Growth variance z-score |
| Engagement dataset | Late weekly roll-up causing misalignment | Use last finalized week + watermark | Engagement watermark recency |
| Spark join jobs | OOM on wide join | Broadcast small dims; memory tuning | Job failure codes |

## 8. Common Failure Modes & Detection
| ID | Failure Mode | Detection Signal | Severity |
|----|--------------|------------------|----------|
| FM1 | Upstream stale dataset | Freshness check fails | Sev2 → Sev1 near SLA |
| FM2 | Join OOM / memory error | Spark OOM log | Sev2 |
| FM3 | Version mismatch (ledger vs snapshot) | Manifest integrity query != 0 | Sev2 |
| FM4 | Divide-by-zero in per-user/seat KPIs | NULL / zero denominators logged | Sev2 |
| FM5 | KPI drift outside tolerance | Z-score > |3| vs 6-month trend | Sev2 (investigate) |
| FM6 | Export failure to S3 | Missing file or checksum mismatch | Sev1 if final run |

## 9. Run Architecture Overview
1. Validate upstream dataset freshness & version ids.  
2. Load gold datasets; standardize time dimensions.  
3. Derive composite KPIs (margins, growth rates, ARPU proxy).  
4. Apply data quality rules.  
5. Persist monthly & weekly preview tables.  
6. Generate manifest + hash; write snapshot export.  
7. Publish status & send Slack notification.  

## 10. Triage Playbooks
| Failure Mode | Immediate Action | Remediation | Validation |
|--------------|------------------|------------|-----------|
| FM1 Upstream stale | Block snapshot; notify upstream owner | Trigger upstream rerun / backfill | Freshness satisfied |
| FM2 Join OOM | Inspect Spark UI; tune broadcast thresholds | Increase executor memory; reduce partitions | Successful rerun |
| FM3 Version mismatch | Halt publication; diff manifest vs sources | Regenerate manifest; re-run snapshot | Manifest integrity=pass |
| FM4 Divide-by-zero | Apply safe denominator wrapper; set metric flag | Backfill missing seat/user counts upstream | No flagged denominators |
| FM5 KPI drift | Cross-validate with upstream tables | If upstream error escalate; else doc rationale | Drift explanation recorded |
| FM6 Export failure | Retry export step; verify permissions | Fix S3 creds / path; reissue snapshot | Export checksum valid |

## 11. Backfill Strategy
| Scenario | Action | Notes |
|----------|--------|-------|
| Incorrect derived metric logic | Recompute monthly for affected months; new snapshot version | Mark old snapshot REVOKED |
| Upstream corrected after publish | Issue incremented snapshot v{n+1}; keep prior immutable | CFO sign-off required |
| Missing engagement week | Rebuild monthly with updated watermark | Update manifest watermark |

## 12. Validation Checklist
- All required upstream versions present.  
- No NULL KPI output fields.  
- Profit total matches upstream profit summary (±0.05%).  
- Growth net new reconciles vs growth monthly summary.  
- Engagement active users ≤ total provisioned seats.  
- No division by zero substituted silently (explicit SAFE_DENOM flag=0).  
- Manifest hash reproducible (rerun dry-run).  
- Snapshot contains upstream version ids + commit hash + engagement watermark.  

## 13. Rollback Procedure
1. Set snapshot status to `REVOKED` in `gold.exec.version_manifest`.  
2. Notify #exec-metrics + CFO channel.  
3. Restore previous FINAL snapshot pointer.  
4. Document reason & corrective action in incident ticket.  

## 14. Alert Configuration
| Alert | Threshold | Channel |
|-------|-----------|---------|
| Upstream freshness failure | Any required stale | #data-alerts |
| Manifest integrity fail | >0 mismatches | Pager (Sev2) |
| Export checksum mismatch | On final run | Pager (Sev1) |
| KPI drift anomaly | Z-score >3 | #data-alerts |

## 15. RACI
| Activity | R | A | C | I |
|----------|---|---|---|---|
| Weekly preview build | DE On-Call | Data Eng Lead | Biz Analytics | Exec Stakeholders |
| Monthly final snapshot | DE On-Call | Biz Analytics Lead | Finance, Accounts | Exec + Board |
| Manifest governance | DE On-Call | Data Eng Lead | Biz Analytics | Finance |
| Backfill / correction | DE On-Call | Data Eng Lead | Biz + Finance | Exec Stakeholders |

## 16. KPIs Monitored
- Profit margin %.  
- Net new account growth %.  
- Engagement hours per active user.  
- Data freshness latency by upstream (max lag hours).  
- Manifest completeness (% required version slots filled).  
- Snapshot cycle time (days from month end to FINAL).  

## 17. Change Management
- Any new KPI requires: definition doc, QA SQL, staging dry-run, stakeholder sign-off.  
- Manifest schema changes versioned with semantic increment.  

## 18. Contacts
| Function | Channel |
|----------|---------|
| On-Call DE | #data-oncall |
| Biz Analytics | #biz-analytics |
| Finance | #finance |
| Accounts | #accounts-team |
| CFO Review | #cfo-metrics |

---
End of Executive / Investor Aggregate Runbook.
