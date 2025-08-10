from chispa.dataframe_comparer import assert_df_equality
from ..jobs.user_devices_cumulated_job import do_user_devices_cumulated_transformation
from collections import namedtuple
import datetime

Event = namedtuple("Event", ["user_id", "device_id", "event_time"])
Device = namedtuple("Device", ["device_id", "browser_type"])
UserDevicesCumulated = namedtuple("UserDevicesCumulated", ["user_id", "browser_type", "device_activity_datelist", "date"])

def test_user_devices_cumulated_transformation(spark):
    dec_31_2022 = datetime.date(2022, 12, 31)
    existing_data = [
        UserDevicesCumulated(1, "Chrome", [dec_31_2022], dec_31_2022),
        UserDevicesCumulated(2, "Firefox", [dec_31_2022], dec_31_2022),
    ]
    existing_df = spark.createDataFrame(existing_data)

    events_data = [
        Event(1, "A", "2023-01-01 10:00:00"),
        Event(1, "A", "2023-01-01 12:00:00"),
        Event(2, "B", "2023-01-01 09:00:00"),
        Event(3, "C", "2023-01-01 10:00:00"),
        Event(3, "C", "2023-01-02 10:00:00"),
        Event(None, "A", "2023-01-01 10:00:00"),
    ]
    events_df = spark.createDataFrame(events_data)

    devices_data = [
        Device("A", "Chrome"),
        Device("B", "Firefox"),
        Device("C", "Safari"),
    ]
    devices_df = spark.createDataFrame(devices_data)



    previous_date = "2022-12-31"
    current_date = "2023-01-01"
    actual_df = do_user_devices_cumulated_transformation(spark, existing_df, events_df, devices_df, previous_date, current_date)

    jan_01_2023 = datetime.date(2023, 1, 1)
    expected_data = [
        UserDevicesCumulated(1, "Chrome", [dec_31_2022, jan_01_2023], jan_01_2023),
        UserDevicesCumulated(2, "Firefox", [dec_31_2022, jan_01_2023], jan_01_2023),
        UserDevicesCumulated(3, "Safari", [jan_01_2023], jan_01_2023),
    ]
    expected_df = spark.createDataFrame(expected_data)

    assert_df_equality(
        actual_df.orderBy("user_id", "browser_type"),
        expected_df.orderBy("user_id", "browser_type"),
        ignore_nullable=True
    )
