# Session Job

This job performs 5‑minute inactivity sessionization of raw web events (grouped by (ip, host)) from the Kafka source and writes:
1. Per-session facts → processed_events_sessions
2. Host session metrics → processed_events_session_host_metrics
3. Global average metric → processed_events_session_overall

## Session Definition
A session = contiguous events for (ip, host) where the gap between consecutive events is < SESSION_GAP_MINUTES (default 5). Flink Session windows may merge; hence sinks receive UPDATE/DELETE (retraction) messages. Primary keys are declared (NOT ENFORCED) in the Flink DDL so JDBC upsert works.

## Tables
- processed_events_sessions (one row per finalized session)
- processed_events_session_host_metrics (aggregated continuously; host-level)
- processed_events_session_overall (single metric row: global_avg_events_per_session)

## Required Environment Variables
See `../example.env`. These must already be loaded into the JobManager container (e.g. via docker-compose env file).

## Run
1. Apply SQL bootstrap (creates physical tables):
   docker exec -i postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < sql/init.sql
2. Submit job:
   make session_job
   (or)
   docker-compose exec jobmanager ./bin/flink run -py /opt/src/homework/session_job.py --pyFiles /opt/src -d
3. Query results (examples):
   SELECT * FROM processed_events_sessions ORDER BY session_start DESC LIMIT 20;
   SELECT * FROM processed_events_session_host_metrics;
   SELECT * FROM processed_events_session_overall;

## Troubleshooting
- Error: please declare primary key for sink table... → Ensure you used the updated Flink DDL with PRIMARY KEY ... NOT ENFORCED.
- Count aggregation error (variadic count) → Use COUNT(1) pattern (lit(1).count) as implemented.
- If sessions look fragmented → Increase SESSION_GAP_MINUTES or verify timestamp parsing pattern matches event_time format.

## Changing Session Gap
Set env SESSION_GAP_MINUTES (int). Defaults to 5 if unset (hard-coded constant if not parameterized yet).

## Cleanup
Cancel job: 
  docker-compose exec jobmanager ./bin/flink list
  docker-compose exec jobmanager ./bin/flink cancel <job_id>

## Analytical Queries

See sql/homework_queries.sql. Key examples:

Global:
SELECT AVG(event_count) FROM processed_events_sessions;

Per host:
SELECT host, COUNT(*) num_sessions, AVG(event_count) avg_events_per_session
FROM processed_events_sessions GROUP BY host ORDER BY avg_events_per_session DESC;

Tech Creator (user focus):
SELECT ip, AVG(event_count) avg_events_per_session
FROM processed_events_sessions
WHERE host LIKE '%techcreator.io'
GROUP BY ip
ORDER BY avg_events_per_session DESC
LIMIT 50;

Comparison specific hosts:
SELECT host, AVG(event_count) avg_events_per_session
FROM processed_events_sessions
WHERE host IN ('zachwilson.techcreator.io','zachwilson.tech','lulu.techcreator.io')
GROUP BY host;