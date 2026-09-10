import os
import argparse
import snowflake.connector
from faker import Faker
import random

def main():
    # 1. Set up command-line arguments
    parser = argparse.ArgumentParser(description="Snowflake Faker Data Loader")
    parser.add_argument("--env", type=str, required=True, choices=['dev', 'uat', 'prod'], help="Target environment")
    parser.add_argument("--mode", type=str, required=True, choices=['seed', 'bad_data'], help="Data generation mode")
    parser.add_argument("--customers", type=int, default=0, help="Number of customer records to generate")
    parser.add_argument("--products", type=int, default=0, help="Number of product/sales records to generate")
    
    args = parser.parse_args()
    fake = Faker()

    # 2. Determine target database dynamically based on --env
    db_name = f"SALES_{args.env.upper()}_DB"
    print(f"🚀 Starting data load...")
    print(f"Target DB: {db_name} | Mode: {args.mode} | Customers: {args.customers} | Products: {args.products}")

    # 3. Connect to Snowflake
    try:
        conn = snowflake.connector.connect(
            account=os.getenv('SNOWFLAKE_ACCOUNT'),
            user=os.getenv('SNOWFLAKE_USER'),
            password=os.getenv('SNOWFLAKE_PASSWORD'),
            database=db_name,
            schema='ANALYTICS'
        )
        cursor = conn.cursor()
    except Exception as e:
        print(f"❌ Failed to connect to Snowflake: {e}")
        return

    # 4. Generate Data based on arguments
    if args.customers > 0:
        print(f"Generating {args.customers} customers...")
        for _ in range(args.customers):
            # Example logic for customers
            name = fake.name().replace("'", "")
            cursor.execute(f"INSERT INTO RAW_CUSTOMERS (name, signup_date) VALUES ('{name}', '{fake.date_this_year()}')")

    if args.products > 0:
        print(f"Generating {args.products} product sales...")
        for _ in range(args.products):
            if args.mode == 'bad_data':
                # Deliberately inject bad data for testing
                revenue = round(random.uniform(-500.0, -10.0), 2) # Negative revenue
                orders = "NULL"
            else:
                # Seed good data
                revenue = round(random.uniform(10.0, 500.0), 2)
                orders = fake.random_int(min=1, max=10)

            cursor.execute(f"""
                INSERT INTO RAW_SALES (total_orders, total_revenue, report_date) 
                VALUES ({orders}, {revenue}, '{fake.date_this_month()}')
            """)

    conn.commit()
    cursor.close()
    conn.close()
    print("✅ Data load complete.")

if __name__ == "__main__":
    main()