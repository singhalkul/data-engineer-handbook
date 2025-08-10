from chispa.dataframe_comparer import assert_df_equality
from collections import namedtuple
from ..jobs.hw_actors_history_scd_job import do_actors_history_scd_transformation

Actor = namedtuple("Actor", "actor actorid current_year quality_class is_active")
ActorSCD = namedtuple("ActorSCD", "actor actorid quality_class is_active start_date end_date current_year")

def test_single_streak(spark):
    data = [Actor("A", 1, 2000, "Good", True),
            Actor("A", 1, 2001, "Good", True)]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [ActorSCD("A", 1, "Good", True, 2000, 2001, 2001)]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_quality_class_change(spark):
    data = [Actor("A", 1, 2000, "Good", True),
            Actor("A", 1, 2001, "Bad", True)]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [
        ActorSCD("A", 1, "Good", True, 2000, 2000, 2000),
        ActorSCD("A", 1, "Bad", True, 2001, 2001, 2001)
    ]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_is_active_change(spark):
    data = [Actor("A", 1, 2000, "Good", True),
            Actor("A", 1, 2001, "Good", False)]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [
        ActorSCD("A", 1, "Good", True, 2000, 2000, 2000),
        ActorSCD("A", 1, "Good", False, 2001, 2001, 2001)
    ]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_both_changes(spark):
    data = [Actor("A", 1, 2000, "Good", True),
            Actor("A", 1, 2001, "Bad", False),
            Actor("A", 1, 2002, "Bad", True)]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [
        ActorSCD("A", 1, "Good", True, 2000, 2000, 2000),
        ActorSCD("A", 1, "Bad", False, 2001, 2001, 2001),
        ActorSCD("A", 1, "Bad", True, 2002, 2002, 2002)
    ]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_multiple_actors(spark):
    data = [
        Actor("A", 1, 2000, "Good", True),
        Actor("A", 1, 2001, "Good", True),
        Actor("B", 2, 2000, "Bad", False),
        Actor("B", 2, 2001, "Bad", False)
    ]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [
        ActorSCD("A", 1, "Good", True, 2000, 2001, 2001),
        ActorSCD("B", 2, "Bad", False, 2000, 2001, 2001)
    ]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_single_year_actor(spark):
    data = [Actor("A", 1, 2000, "Good", True)]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [ActorSCD("A", 1, "Good", True, 2000, 2000, 2000)]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)

def test_alternating_changes(spark):
    data = [
        Actor("A", 1, 2000, "Good", True),
        Actor("A", 1, 2001, "Bad", True),
        Actor("A", 1, 2002, "Good", True),
        Actor("A", 1, 2003, "Bad", True)
    ]
    df = spark.createDataFrame(data)
    result = do_actors_history_scd_transformation(spark, df)
    expected = [
        ActorSCD("A", 1, "Good", True, 2000, 2000, 2000),
        ActorSCD("A", 1, "Bad", True, 2001, 2001, 2001),
        ActorSCD("A", 1, "Good", True, 2002, 2002, 2002),
        ActorSCD("A", 1, "Bad", True, 2003, 2003, 2003)
    ]
    expected_df = spark.createDataFrame(expected)
    assert_df_equality(result, expected_df)