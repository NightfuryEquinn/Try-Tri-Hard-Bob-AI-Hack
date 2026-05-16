"""
Pytest Test Generator for LegacyLink AI
Generates starter pytest test files for generated SQLAlchemy models.
"""

import re
from typing import List, Dict


class TestGenerator:
    """Generate pytest test files for SQLAlchemy models."""

    def generate_tests(self, tables: List[Dict]) -> str:
        """
        Generate complete test_models.py file content.

        Args:
            tables: List of table dictionaries with normalized names.

        Returns:
            Complete Python code for test_models.py.
        """
        imports = self._generate_imports(tables)
        tests = []

        for table in tables:
            table_tests = self._generate_table_tests(table)
            tests.extend(table_tests)

        return imports + "\n\n" + "\n\n".join(tests) + "\n"

    def _generate_imports(self, tables: List[Dict]) -> str:
        """Generate import statements for the generated test file."""
        class_names = [table["clean_name"] for table in tables]

        imports = [
            '"""',
            "Test suite for generated SQLAlchemy models.",
            "Run with: python -m pytest -q",
            '"""',
            "",
            "import pytest",
            "from sqlalchemy import inspect",
            f"from models import {', '.join(class_names)}",
        ]

        return "\n".join(imports)

    def _generate_table_tests(self, table: Dict) -> List[str]:
        """
        Generate test functions for a single table.

        Args:
            table: Table dictionary with metadata.

        Returns:
            List of test function code strings.
        """
        class_name = table["clean_name"]
        table_name = table["table_name"]
        columns = table["columns"]

        safe_test_name = self._safe_test_name(table_name)
        tests = []

        tests.append(self._generate_table_name_test(class_name, table_name, safe_test_name))
        tests.append(self._generate_primary_key_test(class_name, columns, safe_test_name))
        tests.append(self._generate_column_existence_test(class_name, columns, safe_test_name))
        tests.append(self._generate_column_type_test(class_name, columns, safe_test_name))

        nullable_test = self._generate_nullable_test(class_name, columns, safe_test_name)
        if nullable_test:
            tests.append(nullable_test)

        return tests

    def _generate_table_name_test(self, class_name: str, table_name: str, safe_test_name: str) -> str:
        """Generate test for __tablename__."""
        lines = [
            f"def test_{safe_test_name}_table_name():",
            f'    """Verify {class_name} has correct table name."""',
            f'    assert {class_name}.__tablename__ == "{table_name}"',
        ]
        return "\n".join(lines)

    def _generate_primary_key_test(self, class_name: str, columns: List[Dict], safe_test_name: str) -> str:
        """Generate test for primary key columns."""
        primary_keys = [col["clean_name"] for col in columns if col.get("primary_key")]

        lines = [
            f"def test_{safe_test_name}_has_primary_key():",
            f'    """Verify {class_name} has expected primary key columns."""',
            f"    mapper = inspect({class_name})",
            "    pk_columns = [col.name for col in mapper.primary_key]",
            f"    expected_primary_keys = {primary_keys!r}",
            "    assert pk_columns == expected_primary_keys",
        ]

        return "\n".join(lines)

    def _generate_column_existence_test(self, class_name: str, columns: List[Dict], safe_test_name: str) -> str:
        """Generate test for expected column existence."""
        column_names = [col["clean_name"] for col in columns]

        lines = [
            f"def test_{safe_test_name}_has_expected_columns():",
            f'    """Verify {class_name} has all expected columns."""',
            f"    mapper = inspect({class_name})",
            "    actual_columns = [col.name for col in mapper.columns]",
            f"    expected_columns = {column_names!r}",
            "",
            "    for column in expected_columns:",
            f'        assert column in actual_columns, f"Column {{column}} not found in {class_name}"',
        ]

        return "\n".join(lines)

    def _generate_column_type_test(self, class_name: str, columns: List[Dict], safe_test_name: str) -> str:
        """
        Generate tests for SQLAlchemy column types.

        Important:
        SQLAlchemy type class names are Python class names.
        For example:
        - VARCHAR becomes String, so class name is STRING
        - INT becomes Integer, so class name is INTEGER
        - TIMESTAMP becomes DateTime, so class name is DATETIME
        """
        lines = [
            f"def test_{safe_test_name}_column_types():",
            f'    """Verify {class_name} column types are compatible with expected SQLAlchemy types."""',
            f"    mapper = inspect({class_name})",
            "",
        ]

        for col in columns:
            col_name = col["clean_name"]
            sql_type = col.get("type", "VARCHAR")
            expected_types = self._get_expected_sqlalchemy_type_names(sql_type)
            safe_col_var = self._safe_variable_name(col_name)

            lines.extend([
                f'    col_{safe_col_var} = mapper.columns["{col_name}"]',
                f"    actual_type = col_{safe_col_var}.type.__class__.__name__.upper()",
                f"    assert actual_type in {expected_types!r}",
                "",
            ])

        return "\n".join(lines).rstrip()

    def _generate_nullable_test(self, class_name: str, columns: List[Dict], safe_test_name: str) -> str:
        """
        Generate tests for non-nullable constraints.

        This only checks primary keys and explicitly non-nullable columns.
        SQLAlchemy may infer nullable=False from Mapped[int] or Mapped[str],
        so this test avoids over-checking columns that were not explicitly marked.
        """
        lines = [
            f"def test_{safe_test_name}_nullable_constraints():",
            f'    """Verify {class_name} primary key and explicit nullable constraints."""',
            f"    mapper = inspect({class_name})",
            "",
        ]

        assertion_count = 0

        for col in columns:
            col_name = col["clean_name"]
            is_nullable = col.get("nullable", True)
            is_primary = col.get("primary_key", False)

            if is_primary:
                lines.append(
                    f'    assert not mapper.columns["{col_name}"].nullable, '
                    f'"{col_name} should not be nullable because it is a primary key"'
                )
                assertion_count += 1
            elif is_nullable is False:
                lines.append(
                    f'    assert not mapper.columns["{col_name}"].nullable, '
                    f'"{col_name} should not be nullable"'
                )
                assertion_count += 1

        if assertion_count == 0:
            return ""

        return "\n".join(lines)

    def _get_expected_sqlalchemy_type_names(self, sql_type: str) -> List[str]:
        """
        Map SQL type string to acceptable SQLAlchemy type class names.

        Example:
        SQL VARCHAR(50) is generated as SQLAlchemy String(50).
        SQLAlchemy class name becomes "String", so pytest sees "STRING".
        """
        sql_type_upper = str(sql_type).upper().split("(")[0].strip()

        if sql_type_upper in ["INT", "INTEGER", "BIGINT", "SMALLINT"]:
            return ["INTEGER", "INT", "BIGINTEGER", "SMALLINTEGER"]

        if sql_type_upper in ["VARCHAR", "CHAR", "NCHAR", "NVARCHAR"]:
            return ["STRING", "VARCHAR"]

        if sql_type_upper in ["TEXT", "LONGTEXT", "MEDIUMTEXT"]:
            return ["TEXT", "STRING"]

        if sql_type_upper in ["TIMESTAMP", "DATETIME"]:
            return ["DATETIME"]

        if sql_type_upper == "DATE":
            return ["DATE"]

        if sql_type_upper in ["BOOLEAN", "BOOL"]:
            return ["BOOLEAN"]

        if sql_type_upper in ["DECIMAL", "NUMERIC", "NUMBER"]:
            return ["NUMERIC", "DECIMAL"]

        if sql_type_upper in ["FLOAT", "DOUBLE", "REAL"]:
            return ["FLOAT", "DOUBLE", "REAL"]

        return ["STRING", "VARCHAR"]

    def _safe_test_name(self, name: str) -> str:
        """Convert table name into a safe pytest function name part."""
        safe = re.sub(r"[^a-zA-Z0-9_]", "_", name.lower())
        safe = re.sub(r"_+", "_", safe).strip("_")
        return safe or "model"

    def _safe_variable_name(self, name: str) -> str:
        """Convert column name into a safe Python variable name part."""
        safe = re.sub(r"[^a-zA-Z0-9_]", "_", name.lower())
        safe = re.sub(r"_+", "_", safe).strip("_")

        if not safe:
            return "column"

        if safe[0].isdigit():
            safe = f"col_{safe}"

        return safe


# Made with Bob