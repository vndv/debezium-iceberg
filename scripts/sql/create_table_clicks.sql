CREATE TABLE public.clicks (
    click_ts TIMESTAMP WITH TIME ZONE,
    ad_cost DECIMAL(38,2),
    is_conversion BOOLEAN,
    user_id VARCHAR
);

INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES ('2023-02-01 13:30:25+00', 1.50, true, '001234567890');


DO $$
DECLARE
  i INT := 1;
  base_ts TIMESTAMPTZ := '2023-02-01 13:30:25+00';
BEGIN
  WHILE i <= 1000 LOOP
    INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
    VALUES (
      base_ts + (i || ' minutes')::interval,
      round(random() * 5 + 0.5, 2),  
      (random() < 0.5),               
      lpad(i::text, 12, '0')        
    );
    i := i + 1;
  END LOOP;
END $$;

