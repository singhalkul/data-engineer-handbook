# Pipeline Runbooks & On-Call Guide (Index)

Pacific Infra Group 2  
Authoring Date: 2025-09-25  
Scope Version: v3.0

This index consolidates shared operational policies and links to individual pipeline runbooks split into dedicated files for clarity and maintainability.

## Linked Pipeline Runbooks
- [Profit Aggregation Pipeline](./runbook-profit.md)
- [Growth Aggregation Pipeline](./runbook-growth.md)
- [Engagement Aggregation Pipeline](./runbook-engagement.md)
- [Retention Cohort Metrics Pipeline](./runbook-retention.md)
- [Executive / Investor Aggregate Metrics Pipeline](./runbook-exec-aggregate.md)

## 1. Purpose & Scope
Central reference for: team roles, rotation, severity model, shared dependencies, generic backfill & data quality procedures, and RACI. Each pipeline file contains its own detailed triage playbooks and validation specifics.

## 2. Team & Roles
| Role | Name | Slack | Time Zone | Notes |
|------|------|-------|-----------|-------|
| Data Engineer (DE) | Divya Dhar | @divya | PT | Senior DE / rotation lead Q4 |
| Data Engineer (DE) | Aikya Shah | @aikya | PT | Analytics engineering focus |
| Data Engineer (DE) | Sam Patel | @sam | PT | Platform & streaming |
| Data Engineer (DE) | Jordan Lee | @jordan | PT | Data quality & cohorts |
| Finance Analyst | (Finance Team) | #finance | PT | Validates Profit metrics |
| Biz Analytics | (BA Team) | #biz-analytics | PT | Owns investor report formatting |
| Product Analytics | (Growth Exp Team) | #growth-exp | PT | Uses growth & retention feeds |
| Frontend Eng Contact | (SWE Frontend) | #frontend | PT | Source of engagement click stream |

## 3. Naming, Environments & Data Freshness Concepts
- Environments: `prod`, `staging`, `dev`.
- Orchestration: Assumed Apache Airflow (`dag_<pipeline>` IDs).
- Storage Layers: Raw → Bronze → Silver → Gold.
- Freshness vs Availability: latency vs successful completion by SLA checkpoint.
- Weeks end Sunday 23:59:59 UTC; all scheduling timestamps in UTC.

## 4. Global On‑Call Policy & Rotation
### 4.1 Cadence & Boundary
- Rotation & handoff synchronized to avoid unowned gap.
- Handoff + retrospective: Mondays 16:30 UTC (30 min). New primary assumes 17:00 UTC.
- Coverage window: Monday 17:00 UTC → following Monday 17:00 UTC.
- Secondary shadows & provides after-hours relief if primary unreachable.

### 4.2 Q4 2025 Full Rotation
| Coverage Week (Mon 17:00 UTC start) | Primary | Secondary | Weekend Buddy | Notes |
|-------------------------------------|---------|-----------|---------------|-------|
| 2025-10-06 → 2025-10-13 | Divya | Aikya | Sam | Kickoff |
| 2025-10-13 → 2025-10-20 | Aikya | Sam | Jordan |  |
| 2025-10-20 → 2025-10-27 | Sam | Jordan | Divya |  |
| 2025-10-27 → 2025-11-03 | Jordan | Divya | Aikya |  |
| 2025-11-03 → 2025-11-10 | Divya | Aikya | Sam |  |
| 2025-11-10 → 2025-11-17 | Aikya | Sam | Jordan |  |
| 2025-11-17 → 2025-11-24 | Sam | Jordan | Divya |  |
| 2025-11-24 → 2025-12-01 (Thanksgiving) | Jordan | Divya | Aikya | Pre‑holiday checklist by 2025-11-26 |
| 2025-12-01 → 2025-12-08 | Divya | Aikya | Sam |  |
| 2025-12-08 → 2025-12-15 | Aikya | Sam | Jordan |  |
| 2025-12-15 → 2025-12-22 | Sam | Jordan | Divya |  |
| 2025-12-22 → 2025-12-29 (Christmas Freeze) | Jordan | Divya | Aikya | Freeze: Sev1 fixes only |
| 2025-12-29 → 2026-01-05 (Year End Close) | Divya | Aikya | Sam | Month & year-end validation |

Distribution: Each engineer has 4 primary weeks; holiday & year-end load distributed.

### 4.3 Holidays / PTO & Weekends
- PTO swaps ≥2 weeks notice; update table & pinned Slack notice.
- Weekend paging: Primary handles Sev1/2; Weekend Buddy performs quick watermark & freshness checks Sat/Sun 18:00 UTC (≤10 min).
- Freeze window (Christmas week): only Sev1 investor-impacting fixes merged.

### 4.4 Expectations
| Activity | Primary | Secondary | Weekend Buddy | Others |
|----------|---------|-----------|---------------|--------|
| Respond to Sev1 | <15m | <30m | Assist if >20m unresolved | N/A |
| Respond to Sev2 | <30m | <45m | N/A | N/A |
| After-hours Sev1 (22:00–06:00 PT) | Yes | If primary unreachable | N/A | N/A |
| Backfill execution | Lead | Review | N/A | Informed |
| Incident review doc | Draft | Co-author | N/A | Stakeholders review |
| Weekend watermark check | Execute | Fallback | Perform | N/A |

## 5. Severity, Alerting & Escalation Matrix
| Severity | Definition | Examples | Investor Impact | Initial Channel | Escalation (T+mins) |
|----------|-----------|----------|-----------------|-----------------|---------------------|
| Sev1 | Active or imminent investor SLA miss or correctness risk | Month-end rollup failure; Profit ledger missing Day+3; Export checksum mismatch | High | Pager + #data-oncall | 30 Director Data; 60 VP Eng |
| Sev2 | Degradation risking SLA / partial upstream delay | Engagement >24h late (<48h); Growth weekly partial; Retention watermark stale | Medium | #data-alerts | 120 Director Data |
| Sev3 | Non-urgent data quality or performance issue | Elevated duplicate proportion; minor cohort anomaly | Low | Ticket + #data-alerts (summary) | Weekly triage |
| Sev4 | Cosmetic / enhancement | Column naming drift | None | Ticket backlog | Quarterly planning |

Escalation Ladder: Primary → Secondary → Data Eng Lead → Director Data Platform → VP Eng.

### 5.1 Ratio & Metric Definition Conventions
- duplicate_proportion = duplicate_rows / total_rows (e.g. 0.02 = 2%).
- late_arrival_ratio = late_events_(24–72h) / final_event_count.
- missing_transition_proportion = events_missing_required_step / total_transitions.
- retention_monotonicity: retention_{n} ≤ retention_{n-1} + 0.01 tolerance.
- All anomaly z-scores use trailing 4-week (weekly metrics) or 8-week (retention) windows unless otherwise noted.

## 6. Cross-Pipeline Shared Dependencies
| Dependency | Used By | Risk | Mitigation | Monitoring Signal |
|------------|---------|------|-----------|-------------------|
| Kafka click stream | Engagement, Retention, Exec Aggregate | Late / drop / dup | Idempotent ingestion, watermarking | Lag >2h; duplicate_proportion >0.015 |
| Account status change feed | Growth, Profit | Missing transitions | Sequence integrity checks | missing_transition_proportion |
| Finance cost ledger | Profit, Exec Aggregate | Publication delay | Version gating | Missing ledger version Day+2 |
| Spark compute cluster | All | OOM / unavailability | Adaptive exec, retries, autoscale | OOM error count |
| Airflow metadata DB | All | Scheduler stall | HA + failover | Heartbeat latency >60s |

## 7. Named Steady-State Ownership
| Pipeline | Primary Owner | Secondary Owner | Rationale |
|----------|---------------|-----------------|-----------|
| Profit | Divya Dhar | Aikya Shah | Finance collaboration & analytics alignment |
| Growth | Jordan Lee | Sam Patel | Data quality focus & performance tuning |
| Engagement | Sam Patel | Jordan Lee | Streaming & platform expertise |
| Retention Cohort | Jordan Lee | Sam Patel | Cohort logic & performance interplay |
| Exec / Investor Aggregate | Aikya Shah | Divya Dhar | Analytics integration & finance tie-in |

## 8. Backfill & Reprocessing (Generic)
1. Scope classification (partition / week / month).  
2. Verify upstream health & no active Sev1/2.  
3. Create ticket (rationale, affected tables, validation plan).  
4. Dry-run: row counts + checksum diff.  
5. Execute backfill; capture logs + checksums.  
6. Run pipeline-specific validation (see individual runbooks).  
7. Record entry in `backfill_audit` (pipeline, initiator, scope, timestamps, before/after checksum).  
8. Notify stakeholders (#data-quality + business channel).  

## 9. Data Quality & Pre‑Holiday Checklist
| Check | Profit | Growth | Engagement | Retention | Exec |
|-------|--------|--------|-----------|-----------|------|
| Row count anomaly z-score <3 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Freshness within SLA | ✓ | ✓ | ✓ | ✓ | ✓ |
| duplicate_proportion below threshold | ✓ | ✓ | ✓ | ✓ | ✓ |
| Version manifest alignment | ✓ | n/a | n/a | n/a | ✓ |
| Referential integrity | ✓ | ✓ | n/a | n/a | ✓ |
| Metric sanity ranges | ✓ | ✓ | ✓ | ✓ | ✓ |

Pre‑Holiday (2 business days prior):  
- Confirm last 7 days DAG success.  
- Spot validate Profit & Exec KPIs.  
- Freeze non-critical schema migrations.  
- Ensure on-call coverage confirmed.  

## 10. RACI Summary
| Pipeline | R | A | C | I |
|----------|---|---|---|---|
| Profit | DE On-Call | Finance Lead | Finance Analysts | Exec Stakeholders |
| Growth | DE On-Call | Accounts Lead | Product Analytics | Exec Stakeholders |
| Engagement | DE On-Call | SWE Frontend Lead | SWE Frontend | Exec Stakeholders |
| Retention Cohort | DE On-Call | Product Analytics Lead | Product Analytics | Exec Stakeholders |
| Exec Aggregate | DE On-Call | Biz Analytics Lead | Finance + Accounts | Executives & Board |

## 11. Experiment / Unit-Level Pipelines (Scope Note)
Granular experiment datasets (unit-level profit, daily growth) share upstream layers; incidents here are Sev3 unless they risk investor KPI freshness or accuracy.

## 12. Assumptions & Open Questions
Assumptions: Airflow + Spark stack; S3-compatible storage; PT core hours; thresholds initial heuristics (tune after 2 cycles).  
Open: Confirm ledger publication exact time; adopt anomaly detection tooling; finalize retention horizon set.

## 13. Glossary
| Term | Definition |
|------|------------|
| AQE | Adaptive Query Execution in Spark. |
| duplicate_proportion | duplicate_rows / total_rows. |
| late_arrival_ratio | Late events (24–72h) / final event count. |
| Manifest | Mapping of upstream dataset versions for a snapshot. |
| Partial Dataset | Interim state awaiting missing non-critical upstream data. |
| retention_monotonicity | Constraint ensuring retention does not increase beyond tolerance. |

---
End of Index. Refer to individual runbooks for detailed triage playbooks.