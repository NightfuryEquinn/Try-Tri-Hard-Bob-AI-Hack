"""Tests for LegacyLink AI name normalization."""

from parser.sql_parser import SQLParser
from parser.name_normalizer import NameNormalizer


def normalize_example_schema():
    """Parse and normalize the example legacy SQL schema."""
    with open("examples/legacy_customer_schema.sql", "r", encoding="utf-8") as f:
        sql_content = f.read()

    parser = SQLParser()
    tables = parser.parse_sql_file(sql_content)

    normalizer = NameNormalizer()

    for table in tables:
        table["clean_name"] = normalizer.normalize_table_name(table["original_name"])
        table["table_name"] = normalizer.normalize_table_name_to_tablename(table["clean_name"])

        normalizer.reset_column_context()

        for col in table["columns"]:
            col["clean_name"] = normalizer.normalize_column_name(col["original_name"])

    return tables


def test_customer_column_normalization():
    tables = normalize_example_schema()

    customer_cols = [col["clean_name"] for col in tables[0]["columns"]]

    assert customer_cols == [
        "id",
        "first_name",
        "last_name",
        "email",
        "store_id",
        "updated_at",
        "created_at",
        "status",
    ]


def test_store_column_normalization():
    tables = normalize_example_schema()

    store_cols = [col["clean_name"] for col in tables[1]["columns"]]

    assert store_cols == [
        "id",
        "store_name",
        "address",
        "city",
        "state",
        "zip",
    ]


def test_order_detail_column_normalization():
    tables = normalize_example_schema()

    order_cols = [col["clean_name"] for col in tables[2]["columns"]]

    assert order_cols == [
        "id",
        "customer_id",
        "store_id",
        "amount",
        "quantity",
        "ordered_at",
    ]


def test_no_duplicate_column_names_per_table():
    tables = normalize_example_schema()

    for table in tables:
        col_names = [col["clean_name"] for col in table["columns"]]
        assert len(col_names) == len(set(col_names)), (
            f"Duplicate column names found in {table['clean_name']}"
        )