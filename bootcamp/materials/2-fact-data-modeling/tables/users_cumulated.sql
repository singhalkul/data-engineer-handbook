 CREATE TABLE users_cumulated (
     user_id TEXT,
     dates_active DATE[],
     date DATE,
     PRIMARY KEY (user_id, date)
 );