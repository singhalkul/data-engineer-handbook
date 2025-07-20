CREATE TABLE host_activity_reduced (
    month DATE,
    host TEXT,
    hit_array INTEGER[],
    unique_visitors_array INTEGER[],
    PRIMARY KEY (month, host)
);
