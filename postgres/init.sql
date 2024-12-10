CREATE TABLE "items" (
    id int8 PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    value text,
    inserted_at timestamp with time zone default current_timestamp
);

CREATE TABLE "item_stats" (
    id int8 PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    item_id int8 references items (id) not null,
    n int8 not null,
    region char(3) not null,
    machine_id text not null,
    received_at timestamp with time zone not null
);

CREATE INDEX ON item_stats (item_id);
CREATE INDEX ON item_stats (region);
CREATE INDEX ON item_stats (n);

CREATE OR REPLACE VIEW insert_latencies AS
    SELECT
        items.id,
        items.inserted_at,
        item_stats.n,
        item_stats.received_at,
        item_stats.region,
        item_stats.machine_id,
        ROUND((EXTRACT(EPOCH FROM item_stats.received_at) - EXTRACT(EPOCH FROM items.inserted_at)) * 1000)  AS latency_ms
    FROM items
    INNER JOIN item_stats
        ON items.id = item_stats.item_id;

CREATE OR REPLACE VIEW region_latency_stats AS
    SELECT
        region,
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies
    GROUP BY (region);

CREATE OR REPLACE VIEW region_latency_stats1 AS
    SELECT
        region,
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies
    WHERE n = 1
    GROUP BY (region);

CREATE OR REPLACE VIEW latency_stats AS
    SELECT
        id,
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies
    GROUP BY (id);

CREATE OR REPLACE VIEW latency_stats1 AS
    SELECT
        id,
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies
    WHERE n = 1
    GROUP BY (id);

CREATE OR REPLACE VIEW latency_overview AS
    SELECT
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1)  as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1)  as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies;

CREATE OR REPLACE VIEW latency_overview1 AS
    SELECT
        min(latency_ms),
        round(cast(percentile_cont(0.01) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p01,
        round(cast(percentile_cont(0.1) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1)  as p10,
        round(cast(percentile_cont(0.5) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1)  as p50,
        round(cast(percentile_cont(0.90) WITHIN GROUP (ORDER BY insert_latencies.latency_ms) as numeric), 1) as p99,
        max(latency_ms)
    FROM insert_latencies
    WHERE n = 1;
