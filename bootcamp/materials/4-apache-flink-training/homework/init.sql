CREATE TABLE IF NOT EXISTS processed_events_sessions (
    session_start TIMESTAMP(3) NOT NULL,
    session_end   TIMESTAMP(3) NOT NULL,
    ip            TEXT,
    host          TEXT,
    event_count   BIGINT NOT NULL,
    PRIMARY KEY (ip, host, session_start)
);

CREATE TABLE IF NOT EXISTS processed_events_session_host_metrics (
    host TEXT PRIMARY KEY,
    num_sessions BIGINT,
    avg_events_per_session NUMERIC
);

CREATE TABLE IF NOT EXISTS processed_events_session_overall (
    metric TEXT PRIMARY KEY,
    metric_value NUMERIC
);