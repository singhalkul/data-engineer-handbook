

from pyspark.sql import SparkSession

def do_user_devices_cumulated_transformation(spark, cumulated_df, events_df, devices_df, previous_date, current_date):
	
    cumulated_df.createOrReplaceTempView("cumulated")
    events_df.createOrReplaceTempView("events")
    devices_df.createOrReplaceTempView("devices")

    query = f"""
	WITH yesterday AS (
		SELECT * FROM cumulated
		WHERE date = DATE('{previous_date}')
	),
	today AS (
		SELECT 
			e.user_id,
			d.browser_type,
			CAST(DATE_TRUNC('day', CAST(e.event_time AS TIMESTAMP)) AS DATE) AS today_date,
			COUNT(1) AS num_events
		FROM events e
		JOIN devices d ON e.device_id = d.device_id
		WHERE DATE_TRUNC('day', CAST(e.event_time AS TIMESTAMP)) = DATE('{current_date}')
		AND e.user_id IS NOT NULL
		GROUP BY e.user_id, d.browser_type, DATE_TRUNC('day', CAST(e.event_time AS TIMESTAMP))
	)
	SELECT
		COALESCE(t.user_id, y.user_id) AS user_id,
		COALESCE(t.browser_type, y.browser_type) AS browser_type,
		COALESCE(y.device_activity_datelist, CAST(ARRAY() AS ARRAY<DATE>)) ||
		CASE 
			WHEN t.user_id IS NOT NULL THEN ARRAY(t.today_date)
			ELSE CAST(ARRAY() AS ARRAY<DATE>)
		END AS device_activity_datelist,
		COALESCE(t.today_date, y.date + INTERVAL '1 day') AS date
	FROM yesterday y
	FULL OUTER JOIN today t ON t.user_id = y.user_id AND t.browser_type = y.browser_type;
	"""
    return spark.sql(query)

# Example main for demonstration (not used in test)
def main():
	spark = SparkSession.builder \
		.master("local") \
		.appName("user_devices_cumulated") \
		.getOrCreate()
	events_df = spark.table("events")
	devices_df = spark.table("devices")
	process_date = "2023-01-01"
	output_df = do_user_devices_cumulated_transformation(spark, events_df, devices_df, process_date)
	output_df.write.mode("overwrite").insertInto("user_devices_cumulated")
