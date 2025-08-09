#!/usr/bin/env python
# coding: utf-8

# In[1]:


from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.functions import broadcast
import time

spark = SparkSession.builder \
    .master("local") \
    .appName("spark_homework") \
    .getOrCreate()

spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")

data_path = "../../data"


# In[2]:


match_details = spark.read.option("header", "true").option("inferSchema", "true") \
    .csv(f"{data_path}/match_details.csv")

matches = spark.read.option("header", "true").option("inferSchema", "true") \
    .csv(f"{data_path}/matches.csv")

medals_matches_players = spark.read.option("header", "true").option("inferSchema", "true") \
    .csv(f"{data_path}/medals_matches_players.csv")

medals = spark.read.option("header", "true").option("inferSchema", "true") \
    .csv(f"{data_path}/medals.csv")

maps = spark.read.option("header", "true").option("inferSchema", "true") \
    .csv(f"{data_path}/maps.csv")
print("Data loaded")


# In[3]:


match_details.createOrReplaceTempView("match_details_temp")
matches.createOrReplaceTempView("matches_temp")
medals_matches_players.createOrReplaceTempView("medals_matches_players_temp")

spark.sql("""
    CREATE OR REPLACE TABLE local.homework.match_details_bucketed
    USING iceberg
    PARTITIONED BY (bucket(16, match_id))
    AS SELECT * FROM match_details_temp
""")

spark.sql("""
    CREATE OR REPLACE TABLE local.homework.matches_bucketed
    USING iceberg
    PARTITIONED BY (bucket(16, match_id))
    AS SELECT * FROM matches_temp
""")

spark.sql("""
    CREATE OR REPLACE TABLE local.homework.medals_matches_players_bucketed
    USING iceberg
    PARTITIONED BY (bucket(16, match_id))
    AS SELECT * FROM medals_matches_players_temp
""")

print("Created tables")


# In[14]:


match_details_bucketed = spark.table("local.homework.match_details_bucketed")
matches_bucketed = spark.table("local.homework.matches_bucketed")
medals_matches_players_bucketed = spark.table("local.homework.medals_matches_players_bucketed")

match_with_details = match_details_bucketed.join(
    matches_bucketed, 
    "match_id", 
    "inner"
)

full_match_data = match_with_details.join(
    medals_matches_players_bucketed,
    ["match_id", "player_gamertag"],
    "left"
)

final_data = full_match_data \
    .join(broadcast(medals.withColumnRenamed("name", "medal_name")), "medal_id", "left") \
    .join(broadcast(maps.withColumnRenamed("name", "map_name")), "mapid", "left")

final_data.show(3)

print(f"Final data has {final_data.count()} rows")


# In[6]:


kills_per_player = final_data.groupBy("player_gamertag") \
    .agg(
        avg("player_total_kills").alias("avg_kills_per_game"),
        count("match_id").alias("games_played")
    ) \
    .filter(col("games_played") >= 5) \
    .orderBy(desc("avg_kills_per_game"))
print("Which player averages the most kills per game?")
kills_per_player.show(10)


# In[7]:


playlist_popularity = final_data.groupBy("playlist_id") \
    .agg(
        countDistinct("match_id").alias("total_matches"),
        countDistinct("player_gamertag").alias("unique_players")
    ) \
    .orderBy(desc("total_matches"))
print("Which playlist gets played the most?")
playlist_popularity.show(10)


# In[15]:


map_popularity = final_data.groupBy("mapid", "map_name") \
    .agg(
        countDistinct("match_id").alias("total_matches"),
        countDistinct("player_gamertag").alias("unique_players")
    ) \
    .orderBy(desc("total_matches"))
print("Which map gets played the most?")
map_popularity.show(10)


# In[19]:


killing_spree_maps = final_data \
    .filter(col("medal_name").like("%Killing Spree%")) \
    .groupBy("mapid", "map_name", "medal_name") \
    .agg(
        count("medal_id").alias("killing_spree_count"),
        countDistinct("player_gamertag").alias("unique_players")
    ) \
    .orderBy(desc("killing_spree_count"))
print("Which map do players get the most Killing Spree medals on?")
killing_spree_maps.show(10)


# In[30]:


final_data_other = full_match_data \
    .join(broadcast(medals.select("medal_id", col("name").alias("medal_name"), col("description").alias("medal_description"))), "medal_id", "left") \
    .join(broadcast(maps.select("mapid", col("name").alias("map_name"), col("description").alias("map_description"))), "mapid", "left")

sorted_by_playlist = final_data_other.sortWithinPartitions("playlist_id")
sorted_by_map = final_data_other.sortWithinPartitions("mapid")
sorted_by_match = final_data_other.sortWithinPartitions("match_id")
sorted_by_combined = final_data_other.sortWithinPartitions("playlist_id", "mapid")

final_data_other.write.mode("overwrite").parquet("../../warehouse/unsorted")
sorted_by_playlist.write.mode("overwrite").parquet("../../warehouse/sorted_by_playlist")
sorted_by_map.write.mode("overwrite").parquet("../../warehouse/sorted_by_map")
sorted_by_match.write.mode("overwrite").parquet("../../warehouse/sorted_by_match")
sorted_by_combined.write.mode("overwrite").parquet("../../warehouse/sorted_by_combined")


final_data_other.write.mode("overwrite").saveAsTable("local.homework.unsorted")
sorted_by_playlist.write.mode("overwrite").saveAsTable("local.homework.sorted_by_playlist")
sorted_by_map.write.mode("overwrite").saveAsTable("local.homework.sorted_by_map")
sorted_by_match.write.mode("overwrite").saveAsTable("local.homework.sorted_by_match")
sorted_by_combined.write.mode("overwrite").saveAsTable("local.homework.sorted_by_combined")

print("Different sorted data written again")


# In[33]:


get_ipython().run_cell_magic('sql', '', "\nSELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'sorted_by_playlist' \nFROM local.homework.sorted_by_playlist.files\nUNION ALL\nSELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'sorted_by_map' \nFROM local.homework.sorted_by_map.files\nUNION ALL\nSELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'sorted_by_match' \nFROM local.homework.sorted_by_match.files\nUNION ALL\nSELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'sorted_by_combined' \nFROM local.homework.sorted_by_combined.files\nUNION ALL\nSELECT SUM(file_size_in_bytes) as size, COUNT(1) as num_files, 'unsorted' \nFROM local.homework.unsorted.files\n")

