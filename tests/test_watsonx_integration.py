"""
Tests for the optional IBM watsonx.ai integration.

The context builders should always work locally. Live watsonx.ai calls are
skipped when credentials, SDK support, or network access are unavailable.
"""

import pytest

from services.watsonx_client import (
    ask_watsonx,
    build_schema_context,
    build_transformation_context,
    get_watsonx_credentials,
)


def test_credentials_shape_when_configured() -> None:
    """Configured credentials include the fields required by watsonx.ai."""
    creds = get_watsonx_credentials()

    if not creds:
        pytest.skip("watsonx.ai credentials are not configured")

    assert creds["api_key"]
    assert creds["project_id"]
    assert creds["url"]
    assert creds["model_id"]


def test_context_builders() -> None:
    """Schema and transformation context builders include useful details."""
    sample_tables = [
        {
            "original_name": "tbl_CUST_MSTR",
            "clean_name": "Customer",
            "table_name": "customers",
            "columns": [
                {
                    "original_name": "c_id",
                    "clean_name": "id",
                    "type": "Integer",
                    "primary_key": True,
                },
                {
                    "original_name": "vch_fname",
                    "clean_name": "first_name",
                    "type": "String(50)",
                },
            ],
        }
    ]

    schema_context = build_schema_context(sample_tables)

    assert "Customer" in schema_context
    assert "tbl_CUST_MSTR" in schema_context
    assert "id" in schema_context
    assert "first_name" in schema_context

    sample_log = [
        {
            "type": "Table",
            "original": "tbl_CUST_MSTR",
            "normalized": "Customer",
            "change": "Removed prefix",
        },
        {
            "type": "Column",
            "original": "c_id",
            "normalized": "id",
            "change": "Removed prefix",
        },
    ]

    transformation_context = build_transformation_context(sample_log)

    assert "tbl_CUST_MSTR" in transformation_context
    assert "Customer" in transformation_context
    assert "c_id" in transformation_context
    assert "id" in transformation_context


def test_simple_query_when_live_watsonx_is_available() -> None:
    """A live query returns a model answer when watsonx.ai is reachable."""
    if not get_watsonx_credentials():
        pytest.skip("watsonx.ai credentials are not configured")

    response = ask_watsonx(
        "What is SQLAlchemy?",
        "Context: We are working with Python ORM models.",
    )

    if "Error calling IBM watsonx.ai" in response:
        pytest.skip("watsonx.ai live query is unavailable in this environment")

    if "SDK not installed" in response:
        pytest.skip("IBM watsonx.ai SDK is not installed")

    assert len(response.strip()) > 10
