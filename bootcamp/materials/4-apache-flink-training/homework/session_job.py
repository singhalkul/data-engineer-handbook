import os
import logging
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import EnvironmentSettings, StreamTableEnvironment, DataTypes
from pyflink.table.expressions import lit, col, call
from pyflink.table.window import Session

DEFAULT_GAP = 5
SESSION_GAP_MINUTES = int(os.environ.get("SESSION_GAP_MINUTES", DEFAULT_GAP))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
logger = logging.getLogger("session_job")

def create_events_source_kafka(t_env):
    kafka_key = os.environ.get("KAFKA_WEB_TRAFFIC_KEY", "")
    kafka_secret = os.environ.get("KAFKA_WEB_TRAFFIC_SECRET", "")
    table_name = "events_session_src"
    pattern = "yyyy-MM-dd''T''HH:mm:ss.SSS''Z''"
    source_ddl = f"""
        CREATE TABLE {table_name} (
            url VARCHAR,
            referrer VARCHAR,
            user_agent VARCHAR,
            host VARCHAR,
            ip VARCHAR,
            headers VARCHAR,
            event_time VARCHAR,
            event_ts AS TO_TIMESTAMP(event_time, '{pattern}'),
            WATERMARK FOR event_ts AS event_ts - INTERVAL '30' SECOND
        ) WITH (
            'connector' = 'kafka',
            'properties.bootstrap.servers' = '{os.environ.get('KAFKA_URL')}',
            'topic' = '{os.environ.get('KAFKA_TOPIC')}',
            'properties.group.id' = '{os.environ.get('KAFKA_GROUP')}',
            'properties.security.protocol' = 'SASL_SSL',
            'properties.sasl.mechanism' = 'PLAIN',
            'properties.sasl.jaas.config' = 'org.apache.flink.kafka.shaded.org.apache.kafka.common.security.plain.PlainLoginModule required username=\"{kafka_key}\" password=\"{kafka_secret}\";',
            'scan.startup.mode' = 'latest-offset',
            'format' = 'json'
        );
    """
    t_env.execute_sql(source_ddl)
    return table_name

def create_sessions_sink_postgres(t_env):
    table_name = "processed_events_sessions"
    sink_ddl = f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            session_start TIMESTAMP(3),
            session_end TIMESTAMP(3),
            ip VARCHAR,
            host VARCHAR,
            event_count BIGINT,
            PRIMARY KEY (ip, host, session_start) NOT ENFORCED
        ) WITH (
            'connector' = 'jdbc',
            'url' = '{os.environ.get("POSTGRES_URL")}',
            'table-name' = '{table_name}',
            'username' = '{os.environ.get("POSTGRES_USER", "postgres")}',
            'password' = '{os.environ.get("POSTGRES_PASSWORD", "postgres")}',
            'driver' = 'org.postgresql.Driver'
        );
    """
    t_env.execute_sql(sink_ddl)
    return table_name

def create_session_host_metrics_sink_postgres(t_env):
    table_name = "processed_events_session_host_metrics"
    sink_ddl = f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            host VARCHAR,
            num_sessions BIGINT,
            avg_events_per_session DOUBLE,
            PRIMARY KEY (host) NOT ENFORCED
        ) WITH (
            'connector' = 'jdbc',
            'url' = '{os.environ.get("POSTGRES_URL")}',
            'table-name' = '{table_name}',
            'username' = '{os.environ.get("POSTGRES_USER", "postgres")}',
            'password' = '{os.environ.get("POSTGRES_PASSWORD", "postgres")}',
            'driver' = 'org.postgresql.Driver'
        );
    """
    t_env.execute_sql(sink_ddl)
    return table_name

def create_session_overall_sink_postgres(t_env):
    table_name = "processed_events_session_overall"
    sink_ddl = f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            metric VARCHAR,
            metric_value DOUBLE,
            PRIMARY KEY (metric) NOT ENFORCED
        ) WITH (
            'connector' = 'jdbc',
            'url' = '{os.environ.get("POSTGRES_URL")}',
            'table-name' = '{table_name}',
            'username' = '{os.environ.get("POSTGRES_USER", "postgres")}',
            'password' = '{os.environ.get("POSTGRES_PASSWORD", "postgres")}',
            'driver' = 'org.postgresql.Driver'
        );
    """
    t_env.execute_sql(sink_ddl)
    return table_name

def sessionize():
    logger.info(f"Starting session job with SESSION_GAP_MINUTES={SESSION_GAP_MINUTES}")
    env = StreamExecutionEnvironment.get_execution_environment()
    env.enable_checkpointing(10 * 1000)
    env.set_parallelism(2)

    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    t_env = StreamTableEnvironment.create(env, environment_settings=settings)

    try:
        source = create_events_source_kafka(t_env)
        sessions_sink = create_sessions_sink_postgres(t_env)
        host_metrics_sink = create_session_host_metrics_sink_postgres(t_env)
        overall_sink = create_session_overall_sink_postgres(t_env)

        # Sessions fact
        (
            t_env.from_path(source)
                .window(
                    Session.with_gap(lit(SESSION_GAP_MINUTES).minutes).on(col("event_ts")).alias("s")
                )
                .group_by(col("s"), col("ip"), col("host"))
                .select(
                    col("s").start.alias("session_start"),
                    col("s").end.alias("session_end"),
                    col("ip"),
                    col("host"),
                    lit(1).count.alias("event_count")
                )
                .execute_insert(sessions_sink)
        )

        # Host metrics
        (
            t_env.from_path(source)
                .window(
                    Session.with_gap(lit(SESSION_GAP_MINUTES).minutes).on(col("event_ts")).alias("s")
                )
                .group_by(col("s"), col("ip"), col("host"))
                .select(
                    col("host").alias("host"),
                    lit(1).count.alias("session_event_count")
                )
                .group_by(col("host"))
                .select(
                    col("host"),
                    col("session_event_count").count.alias("num_sessions"),
                    col("session_event_count").avg.alias("avg_events_per_session")
                )
                .execute_insert(host_metrics_sink)
        )

        # Global metric
        (
            t_env.from_path(source)
                .window(
                    Session.with_gap(lit(SESSION_GAP_MINUTES).minutes).on(col("event_ts")).alias("s")
                )
                .group_by(col("s"), col("ip"), col("host"))
                .select(lit(1).count.alias("session_events"))
                .select(
                    lit("global_avg_events_per_session").alias("metric"),
                    col("session_events").avg.alias("metric_value")
                )
                .execute_insert(overall_sink)
                .wait()
        )
        logger.info("Session job running (streaming).")

    except Exception as e:
        logger.exception("Session job failed: %s", e)
        raise

if __name__ == "__main__":
    sessionize()