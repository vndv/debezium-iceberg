CREATE TABLE public.clicks (
    click_ts TIMESTAMP WITH TIME ZONE,
    ad_cost DECIMAL(38,2),
    is_conversion BOOLEAN,
    user_id VARCHAR
);

INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES ('2023-02-01 13:30:25+00', 1.50, true, '001234567890');

INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES ('2023-02-02 13:30:25+00', 2.50, true, '001234567891');

DELETE FROM public.clicks
WHERE user_id = '001234567891';

-- optimize  iceberg tables
--
ALTER TABLE iceberg.default.postgres_clicks_avro EXECUTE optimize(file_size_threshold => '10MB');
ALTER TABLE iceberg.default.postgres_clicks_avro EXECUTE expire_snapshots(retention_threshold => '0d');
ALTER TABLE iceberg.default.postgres_clicks_avro EXECUTE remove_orphan_files(retention_threshold => '0d');
