import time
import random
import psycopg2
from datetime import datetime, timedelta

conn_params = {
    'host': 'localhost',
    'port': 5433,
    'dbname': 'postgres',
    'user': 'postgres',
    'password': 'postgres'
}

def main():
    date_str = '2023-02-01 13:30:25+00'.replace('+00', '+0000')
    base_ts = datetime.strptime(date_str, '%Y-%m-%d %H:%M:%S%z')

    try:
        with psycopg2.connect(**conn_params) as conn:
            with conn.cursor() as cur:
                for i in range(1, 1001):
                    click_ts = base_ts + timedelta(minutes=i)
                    ad_cost = round(random.uniform(0.5, 5.5), 2)
                    is_conversion = random.random() < 0.5
                    user_id = str(i).rjust(12, '0')

                    cur.execute("""
                        INSERT INTO public.clicks (click_ts, ad_cost, is_conversion, user_id)
                        VALUES (%s, %s, %s, %s)
                    """, (click_ts, ad_cost, is_conversion, user_id))

                    conn.commit()
                    print(f'Inserted row {i}')
                    time.sleep(1)

    except Exception as e:
        print("Error:", e)


if __name__ == "__main__":
    main()
