#!/usr/bin/env python3
"""
faker_loader.py — Seeds and drip-feeds demo data into the Snowflake DCM
sales pipeline (SALES{env_suffix}_DB.RAW.CUSTOMERS / PRODUCTS / SALES_ORDERS).

Install:
    pip install snowflake-connector-python faker

Usage:
    # One-time: seed dimension tables (customers, products)
    python faker_loader.py --env dev --mode seed --customers 50 --products 30

    # Drip-feed orders every ~20-30s, forever, for a live demo
    python faker_loader.py --env dev --mode stream

    # Drip-feed for a fixed 5-minute window, faster interval
    python faker_loader.py --env dev --mode stream --interval 10 --duration 300

    # Seed dimensions AND start streaming orders in one call
    python faker_loader.py --env dev --mode both

    # Occasionally inject rows designed to trip the data quality expectations
    # (duplicate order_id, NULL region, negative revenue) so the DMF demo
    # (step 5 of the demo script) has something to catch on cue.
    python faker_loader.py --env dev --mode stream --bad-row-rate 0.15

Connection credentials are read from environment variables (matching the
Snowflake CLI / GitHub Actions secret names already used in this repo), or
pass them explicitly with --account/--user/--password/--role/--warehouse:

    SNOWFLAKE_CONNECTIONS_DEFAULT_ACCOUNT
    SNOWFLAKE_CONNECTIONS_DEFAULT_USER
    SNOWFLAKE_CONNECTIONS_DEFAULT_PASSWORD
"""

import argparse
import os
import random
import sys
import time
from datetime import date, timedelta

try:
    import snowflake.connector
except ImportError:
    sys.exit("Missing dependency. Run: pip install snowflake-connector-python faker")

try:
    from faker import Faker
except ImportError:
    sys.exit("Missing dependency. Run: pip install snowflake-connector-python faker")

fake = Faker()

REGIONS = ["US-WEST", "US-EAST", "EMEA", "APAC"]
SEGMENTS = ["Enterprise", "SMB", "Consumer"]
CATEGORIES = ["Electronics", "Apparel", "Home", "Sporting Goods", "Office Supplies"]

ENV_SUFFIX = {"dev": "_DEV", "uat": "_UAT", "prod": ""}



def get_connection(args):
    return snowflake.connector.connect(
        account=args.account or os.environ.get("SNOWFLAKE_ACCOUNT"),
        user=args.user or os.environ.get("SNOWFLAKE_USER"),
        password=args.password or os.environ.get("SNOWFLAKE_PASSWORD"),
        role=args.role,
        warehouse=args.warehouse or f"SALES_WH{args.suffix}",
        database=f"SALES{args.suffix}_DB",
        schema="RAW",
    )


# ---------------------------------------------------------------------------
# Seeding: dimension tables (run once per environment/demo reset)
# ---------------------------------------------------------------------------

def seed_customers(cur, n, suffix):
    rows = []
    for cid in range(1, n + 1):
        rows.append((
            cid,
            fake.company(),
            random.choice(SEGMENTS),
            fake.date_between(start_date="-3y", end_date="-30d"),
            random.choice(REGIONS),
        ))
    cur.executemany(
        f"""
        INSERT INTO SALES{suffix}_DB.RAW.CUSTOMERS
            (customer_id, customer_name, segment, signup_date, region)
        VALUES (%s, %s, %s, %s, %s)
        """,
        rows,
    )
    print(f"Seeded {n} customers.")


def seed_products(cur, n, suffix):
    rows = []
    for pid in range(1, n + 1):
        rows.append((
            pid,
            fake.catch_phrase(),
            random.choice(CATEGORIES),
            round(random.uniform(5, 300), 2),
        ))
    cur.executemany(
        f"""
        INSERT INTO SALES{suffix}_DB.RAW.PRODUCTS
            (product_id, product_name, category, unit_cost)
        VALUES (%s, %s, %s, %s)
        """,
        rows,
    )
    print(f"Seeded {n} products.")


# ---------------------------------------------------------------------------
# Streaming: fact table (SALES_ORDERS) — call repeatedly during the demo
# ---------------------------------------------------------------------------

_next_order_id = [1000]  # mutable counter shared across calls
_seen_order_ids = []


def _next_id():
    _next_order_id[0] += 1
    _seen_order_ids.append(_next_order_id[0])
    return _next_order_id[0]


def generate_order(n_customers, n_products, bad_row_rate):
    """Return one order row. Occasionally return a deliberately 'bad' row
    to demonstrate the data quality expectations firing (see 06_expectations.sql):
    NULL region, negative unit_price, or a reused (duplicate) order_id."""
    is_bad = random.random() < bad_row_rate

    order_id = random.choice(_seen_order_ids) if (is_bad and _seen_order_ids and random.random() < 0.4) else _next_id()
    region = None if (is_bad and random.random() < 0.4) else random.choice(REGIONS)
    unit_price = round(random.uniform(-50, -1), 2) if (is_bad and random.random() < 0.4) else round(random.uniform(5, 300), 2)

    return (
        order_id,
        date.today() - timedelta(days=random.randint(0, 2)),
        random.randint(1, n_customers),
        random.randint(1, n_products),
        random.randint(1, 10),
        unit_price,
        region,
    )


def insert_orders(cur, suffix, batch_size, n_customers, n_products, bad_row_rate):
    rows = [generate_order(n_customers, n_products, bad_row_rate) for _ in range(batch_size)]
    cur.executemany(
        f"""
        INSERT INTO SALES{suffix}_DB.RAW.SALES_ORDERS
            (order_id, order_date, customer_id, product_id, quantity, unit_price, region)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        rows,
    )
    print(f"Inserted {batch_size} orders (order_ids up to {_next_order_id[0]}).")


def stream(cur, args):
    start = time.time()
    print(f"Streaming orders every ~{args.interval}s "
          f"(bad-row rate {args.bad_row_rate:.0%}). Ctrl+C to stop.")
    try:
        while True:
            insert_orders(
                cur, args.suffix, args.batch_size,
                args.customers, args.products, args.bad_row_rate,
            )
            if args.duration and (time.time() - start) >= args.duration:
                print("Duration reached, stopping.")
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nStopped by user.")


# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--env", choices=["dev", "uat", "prod"], default="dev",
                    help="Which environment's env_suffix to target (default: dev)")
    p.add_argument("--mode", choices=["seed", "stream", "both"], default="seed")
    p.add_argument("--customers", type=int, default=50, help="Number of customer rows to seed")
    p.add_argument("--products", type=int, default=30, help="Number of product rows to seed")
    p.add_argument("--batch-size", type=int, default=3, help="Orders inserted per streaming tick")
    p.add_argument("--interval", type=float, default=25, help="Seconds between streaming ticks")
    p.add_argument("--duration", type=float, default=None, help="Stop streaming after N seconds (default: run until Ctrl+C)")
    p.add_argument("--bad-row-rate", type=float, default=0.0,
                    help="Fraction of streamed orders that deliberately violate a data quality expectation (0.0-1.0)")
    p.add_argument("--account", default=None)
    p.add_argument("--user", default=None)
    p.add_argument("--password", default=None)
    p.add_argument("--role", default=None)
    p.add_argument("--warehouse", default=None)
    args = p.parse_args()
    args.suffix = ENV_SUFFIX[args.env]

    conn = get_connection(args)
    cur = conn.cursor()
    try:
        if args.mode in ("seed", "both"):
            seed_customers(cur, args.customers, args.suffix)
            seed_products(cur, args.products, args.suffix)
            conn.commit()
        if args.mode in ("stream", "both"):
            stream(cur, args)
            conn.commit()
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()