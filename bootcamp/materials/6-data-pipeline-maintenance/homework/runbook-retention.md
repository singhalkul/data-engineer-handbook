# Retention Cohort Metrics Pipeline Runbook

Pipeline ID: `dag_retention_cohort_metrics`  
Last Updated: 2025-09-25  
Version: 1.0

## 1. Purpose
Compute weekly and monthly user and account cohort retention (N-week / N-month retention curves, rolling 4-week stickiness) for investor narrative and internal strategy. Feeds executive roll-up and product growth experimentation guardrails. Provides stable cohort definitions aligned with financial reporting periods.

## 2. Ownership
| Aspect | Primary Owner | Secondary Owner | Notes |
|--------|---------------|-----------------|-------|
| Domain (steady-state) | Jordan Lee | Sam Patel | Jordan leads data quality; Sam platform & performance |
| On-Call (week) | Rotating DE | Next week's DE | See index rotation policy |
| Business Alignment | Product Analytics (Growth) | Biz Analytics | Cohort definition governance |

Escalation: Primary → Secondary → Data Eng Lead → Product Analytics Lead → Director Data Platform.

## 3. Schedule & SLAs
| Process | Frequency | Target Runtime (UTC) | Freshness SLA | Notes |
|---------|-----------|----------------------|---------------|-------|
| Weekly cohort refresh | Weekly (Mon) | 12:00 | Prior week complete | Uses finalized engagement rollups |
| Monthly cohort consolidation | Monthly | T+3 business days 12:00 | Month's cohorts locked | Aligns with investor snapshot pre-final |

Freshness breach weekly (>18:00 UTC) = Sev2. Monthly breach = Sev1.

## 4. Data Sources
| Source | Layer | Description | Refresh |
|--------|-------|-------------|---------|
| `gold.engagement.daily_metrics` | Gold | Active users base & activity counts | 48h maturity window |
| `silver.accounts.dim_accounts` | Silver | Account segmentation (tier, region) | Daily |
| `silver.users.dim_users` | Silver | User creation timestamps & attributes | Daily |
| `gold.growth.weekly_summary` | Gold | Net new accounts for aligning account cohort baselines | Weekly |

## 5. Targets
| Target | Layer | Partitioning | Notes |
|--------|-------|-------------|-------|
| `gold.retention.account_weekly_cohort` | Gold | `cohort_week` | Account-level retention percentages |
| `gold.retention.user_weekly_cohort` | Gold | `cohort_week` | User-level retention curve |
| `gold.retention.user_monthly_cohort` | Gold | `cohort_month` | Month-based cohorts for investor narrative |
| `gold.retention.stickiness_metrics` | Gold | `week` | DAU/WAU, WAU/MAU proxies |
| `gold.retention.cohort_audit` | Audit | `load_date` | Consistency + drift checks |

## 6. Cohort Definition
- User Cohort (weekly): users grouped by `date_trunc('week', user_created_at)` (UTC).  
- Account Cohort: first active week (≥1 engaged user OR ≥1 revenue event).  
- Retention Metric: active in week N if user produced ≥1 qualifying engagement event (filtered by event classification).  
- Stickiness: DAU/WAU computed from engagement gold tables.

## 7. Dependencies & Risks
| Dependency | Risk | Mitigation | Monitoring Signal |
|------------|------|-----------|-------------------|
| Engagement daily metrics | Late or incomplete | Use watermark & exclude last 2 days | Watermark age >48h |
| User dimension integrity | Missing creation ts | Default to ingestion ts (flag) | Proportion missing creation_ts |
| Growth weekly summary | Misaligned account activation | Cross-check first activity vs growth net new | Activation mismatch ratio |

## 8. Common Failure Modes & Detection
| ID | Failure Mode | Detection Signal | Severity |
|----|--------------|------------------|----------|
| FM1 | Late engagement data causing cohort undercount | Watermark >48h for prior week | Sev2 |
| FM2 | Cohort size spike anomaly | Size z-score >3 vs 8-week avg | Sev2 |
| FM3 | Retention curve monotonicity violation (increase) | Retention_{n} > Retention_{n-1} + 1% tolerance | Sev2 |
| FM4 | Missing cohort partitions | Gap in expected week sequence | Sev2 |
| FM5 | Stickiness metric outlier | DAU/WAU z-score >3 | Sev2 |

## 9. Run Architecture Overview
1. Determine finalized cohort weeks (excluding incomplete watermark days).  
2. Snapshot new cohort entries from user & account dimensions.  
3. Build activity presence matrices (user x week).  
4. Aggregate retention percentages per cohort week and horizon.  
5. Compute stickiness metrics.  
6. Run anomaly & monotonicity checks; write audit.  
7. Publish gold tables & notify #growth-exp + #data-oncall.

## 10. Triage Playbooks
| Failure Mode | Immediate Action | Remediation | Validation |
|--------------|------------------|------------|-----------|
| FM1 Late engagement | Delay cohort materialization; set status PARTIAL | Rerun after watermark <48h | Watermark freshness ok |
| FM2 Size spike | Inspect new user counts; compare to sign-up funnel | Correct upstream duplication or doc event burst | Size z-score <2 |
| FM3 Monotonicity issue | Recompute curve for affected cohort | Identify mis-filtered activity events | Curve non-increasing |
| FM4 Missing weeks | Re-run week generation job | Validate sequence continuity | No gaps |
| FM5 Stickiness outlier | Validate DAU & WAU denominators | Adjust filtering (bot traffic?) | z-score <2 |

## 11. Backfill Strategy
| Scenario | Action | Notes |
|----------|--------|-------|
| Recompute historical retention | `retention_backfill --weeks=YYYY-WW:YYYY-WW` | Expensive; schedule off-peak |
| Cohort definition change | Version cohorts (`definition_version`) & rebuild forward | Preserve old version for audit |
| Missing weeks | Generate missing partitions & recompute horizons dependent | Audit entry appended |

## 12. Validation Checklist
- No increasing retention beyond tolerance.  
- Cohort size matches user count for creation week ±1%.  
- Stickiness ratios between 0 and 1.2 (upper guard for anomalies).  
- No NULL retention percentages.  
- Monotonic retention horizon sequence per cohort.

## 13. Rollback Procedure
- Mark erroneous cohort partitions `status=REVOKED` in audit.  
- Restore previous snapshot from object store.  
- Re-run dependent executive roll-up if month impacted.  

## 14. Alert Configuration
| Alert | Threshold | Channel |
|-------|-----------|---------|
| Watermark stale | >48h | #data-alerts |
| Cohort size anomaly | z-score >3 | #data-alerts |
| Monotonicity failure | Any violation >1% | Pager (Sev2) |
| Missing week partition | Gap detected | #data-alerts |
|
## 15. RACI
| Activity | R | A | C | I |
|----------|---|---|---|---|
| Weekly cohort build | DE On-Call | Data Eng Lead | Product Analytics | Exec Stakeholders |
| Cohort definition changes | Product Analytics | Product Analytics Lead | DE, Biz Analytics | Exec Stakeholders |
| Backfill | DE On-Call | Data Eng Lead | Product Analytics | Biz Analytics |

## 16. KPIs Monitored
- Week 1 retention (%).  
- Week 4 retention (%).  
- Month 1 retention (%).  
- DAU/WAU, WAU/MAU stickiness.  
- Cohort size anomalies.  

## 17. Change Management
- Definition changes require: spec doc, approval (Product Analytics + Biz Analytics), version bump, staging dry-run.  
- Add new retention horizon only after storage & performance assessment.

## 18. Contacts
| Function | Channel |
|----------|---------|
| On-Call DE | #data-oncall |
| Product Analytics | #growth-exp |
| Biz Analytics | #biz-analytics |
| Data Platform | #data-platform |

---
End of Retention Cohort Metrics Runbook.
