# Engagement Aggregation Pipeline Runbook

Pipeline ID: `dag_engagement_aggregate`  
Last Updated: 2025-09-25  
Version: 1.0

## 1. Purpose
Generate daily and weekly engagement metrics (active users, session hours, events per active user) for retention monitoring and inclusion in investor narrative (via executive roll-up). Handles late and duplicate clickstream events from Kafka ingestion.

## 2. Ownership
| Aspect | Primary | Secondary | Notes |
|--------|---------|-----------|-------|
| Steady-State Domain | Sam Patel | Jordan Lee | Streaming platform & data quality |
| On-Call (weekly) | Rotating DE | Next week's DE | See index rotation policy |
| Source System Owner | SWE Frontend Team | SWE Frontend Contact | Kafka emission integrity |
| Product Analytics Partner | Retention Analytics | Biz Analytics | Metric interpretation |

Escalation Ladder: Primary → Secondary → SWE Frontend Contact → Data Eng Lead → Director Data Platform.
## 3. Schedule & SLAs
| Process | Frequency | Target | Freshness SLA | Notes |
|---------|-----------|--------|---------------|-------|
| Raw event ingestion | Continuous | Near-real-time | n/a (<5m latency typical) | Kafka consumer |
| Daily aggregation | Daily | 06:00 UTC | Data available ≤ 48h | Includes late event window |
| Weekly roll-up | Weekly (Mon) | 10:00 UTC | Prior week complete | Feeds exec preview |

SLA Rationale: Engagement metrics consumed weekly/monthly by investors; priority is accuracy & late event completeness over sub-day latency. Breach of 48h daily freshness = Sev2; >72h = Sev1.

## 4. Data Sources
| Source | Layer | Description | Refresh |
|--------|-------|-------------|---------|
| Kafka `clickstream.events` | Raw | User interaction events | Continuous |
| `bronze.events_clean` | Bronze | Parsed & minimally validated events | Near-real-time |
| `silver.sessions` | Silver | Sessionized user activity | Hourly micro-batch |
| `silver.events_deduped` | Silver | Deduplicated + late merged events | Hourly |
| `gold.engagement.daily_metrics` | Gold | Daily aggregated engagement | Daily 06:00 UTC |
| `gold.engagement.weekly_summary` | Gold | Weekly roll-up | Weekly Mon 10:00 UTC |

## 5. Targets
| Target | Layer | Partitioning | Notes |
|--------|-------|-------------|-------|
| `gold.engagement.daily_metrics` | Gold | `date` | Late events merged up to 72h |
| `gold.engagement.weekly_summary` | Gold | `year_week` | Derived from daily |
| `gold.engagement.late_event_audit` | Audit | `date` | Track late arrival ratios |
| `gold.engagement.dup_event_audit` | Audit | `date` | Duplicate detection stats |

## 6. Dependencies
| Dependency | Type | Risk | Mitigation | Monitor |
|------------|------|------|-----------|--------|
| Kafka brokers | External infra | Outage / lag | Multi-broker, alert on lag | Consumer lag metric |
| Sessionization Spark job | Compute | Skew OOM | Salting, AQE | Stage retry count |
| Event schema | Contract | Breaks parser | Schema registry & versioning | Parse failure rate |

## 7. Common Failure Modes & Detection
| ID | Failure Mode | Detection Signal | Severity |
|----|--------------|------------------|----------|
| FM1 | Kafka partition lag | Lag > 2h (warn) >6h (Sev2) | Sev2/1 |
| FM2 | Late arrival spike | late_arrival_ratio >0.05 | Sev2 |
| FM3 | Duplicate event surge | duplicate_proportion >0.02 | Sev2 |
| FM4 | Skewed session OOM | Spark OOM + skew metrics | Sev2 |
| FM5 | Parser schema errors | Parse failure rate >0.5% | Sev2 |

## 8. Run Architecture Overview
1. Stream ingest from Kafka → Bronze.  
2. Parse & validate schema; route failures to quarantine.  
3. Deduplicate using event_id hash and fingerprint.  
4. Sessionize user events (session start/end logic).  
5. Aggregate daily metrics; merge late events (window up to 72h).  
6. Produce weekly summary.  
7. Emit audits & alerts.

## 9. Triage Playbooks
| Failure Mode | Immediate Actions | Remediation | Validation |
|--------------|-------------------|-------------|-----------|
| FM1 Lag | Check broker health; restart consumer; scale partitions | If infra issue escalate to SWE | Lag <1h sustained |
| FM2 Late spike | Trigger late-event backfill for affected date | Extend late window temporarily | late_arrival_ratio <0.02 |
| FM3 Duplicates | Examine fingerprint collisions; quarantine duplicates | Adjust dedupe key / add source_id | duplicate_proportion <0.005 |
| FM4 Skew OOM | Identify top skew keys; apply salting; rerun stage | Implement dynamic repartition | Job completes normal |
| FM5 Parser errors | Inspect failing payloads; roll back to prior schema | Coordinate schema evolution | Failure rate <0.1% |

## 10. Backfill Strategy
| Scenario | Command (conceptual) | Notes |
|----------|---------------------|-------|
| Late events merge | `engagement_reprocess --date=YYYY-MM-DD` | Merges new events into daily partition |
| Weekly rebuild | `engagement_reprocess --week=YYYY-WW` | Last 4 weeks only |
| Duplicate purge | `engagement_dedupe --date=YYYY-MM-DD` | Rewrites day & updates audit |

## 11. Validation Checklist
- Active users >= distinct users with ≥1 event.  
- Hours per active user within 4-week IQR.  
- duplicate_proportion <0.005 target (warn if >=0.02).  
- No negative session durations.  
- late_arrival_ratio <0.05 (target <0.02).  
- Rationale: Daily SLA (48h) looser because investor consumption is weekly/monthly; operational focus is completeness over low-latency.

## 12. Rollback Procedure
- Restore previous daily partition from snapshot store.  
- Mark current partition `status=REVOKED`.  
- Re-run late event merge if needed.  

## 13. Alert Configuration
| Alert | Threshold | Channel |
|-------|-----------|---------|
| Consumer lag high | >2h | #data-alerts |
| Consumer lag critical | >6h | Pager (Sev2) |
| late_arrival_ratio | >0.05 | #data-alerts |
| duplicate_proportion | >0.02 | #data-alerts |
| Parser failure | >0.5% | Pager if sustained |

## 14. RACI
| Activity | R | A | C | I |
|----------|---|---|---|---|
| Daily ops | DE On-Call | Data Eng Lead | SWE Frontend | Exec Stakeholders |
| Schema evolution | SWE Frontend | SWE Lead | DE | Product Analytics |
| Backfill | DE On-Call | Data Eng Lead | SWE | Stakeholders |

## 15. KPIs Monitored
- Active users daily & 7-day trend.  
- Average session hours per user.  
- Late arrival ratio.  
- Duplicate event ratio.  
- Consumer lag minutes.  

## 16. Change Management
- Schema changes require registry update & staging test.  
- Increase late window >72h requires capacity assessment.

## 17. Contacts
| Function | Channel |
|----------|---------|
| On-Call DE | #data-oncall |
| SWE Frontend | #frontend |
| Product Analytics | #retention-analytics |
| Data Platform | #data-platform |

---
End of Engagement Runbook.
