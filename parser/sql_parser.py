"""
SQL Parser Module for LegacyLink AI
Extracts schema metadata from legacy SQL DDL files
"""

import re
from typing import List, Dict, Optional


class SQLParser:
    """Parse legacy SQL CREATE TABLE statements and extract schema metadata"""

    def __init__(self):
        self.tables = []
        self.functions = []
        self.indexes = []
        self.views = []

    def parse_sql_file(self, sql_content: str) -> List[Dict]:
        """
        Parse SQL content and extract table definitions, functions, indexes, and views

        Supports:
        - CREATE TABLE / CREATE TABLE IF NOT EXISTS (with schema-qualified names)
        - CREATE FUNCTION / CREATE OR REPLACE FUNCTION
        - CREATE PROCEDURE / CREATE OR REPLACE PROCEDURE
        - CREATE INDEX / CREATE UNIQUE INDEX (with schema-qualified names)
        - CREATE VIEW / CREATE OR REPLACE VIEW
        - CREATE MATERIALIZED VIEW

        Args:
            sql_content: Raw SQL file content

        Returns:
            List of table dictionaries with metadata
        """
        self.tables = []
        self.functions = []
        self.indexes = []
        self.views = []

        # Store original content before removing comments for function body extraction
        original_content = sql_content

        # Remove comments for pattern matching
        sql_content_clean = self._remove_comments(sql_content)

        # Extract CREATE TABLE statements (with or without IF NOT EXISTS)
        # Supports schema-qualified names like raw_layer.z_customer_master_legacy
        create_table_pattern = r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w.]+)\s*\((.*?)\);'
        matches = re.finditer(create_table_pattern, sql_content_clean, re.IGNORECASE | re.DOTALL)

        for match in matches:
            table_name = match.group(1)
            columns_def = match.group(2)

            table_info = {
                'original_name': table_name,
                'columns': self._parse_columns(columns_def)
            }

            self.tables.append(table_info)

        # Also match CREATE TABLE ... AS SELECT (no column defs, just record the table)
        create_table_as_pattern = r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([\w.]+)\s+AS\s+'
        matches_as = re.finditer(create_table_as_pattern, sql_content_clean, re.IGNORECASE)
        for match in matches_as:
            table_name = match.group(1)
            # Skip if already found via the primary pattern
            if not any(t['original_name'] == table_name for t in self.tables):
                self.tables.append({
                    'original_name': table_name,
                    'columns': []
                })

        # Extract functions and procedures
        self._parse_functions(original_content)

        # Extract indexes
        self._parse_indexes(sql_content_clean)

        # Extract views
        self._parse_views(sql_content_clean)

        return self.tables

    def _remove_comments(self, sql_content: str) -> str:
        """Remove SQL comments from content"""
        # Remove single-line comments
        sql_content = re.sub(r'--.*?$', '', sql_content, flags=re.MULTILINE)
        # Remove multi-line comments
        sql_content = re.sub(r'/\*.*?\*/', '', sql_content, flags=re.DOTALL)
        return sql_content

    def _parse_columns(self, columns_def: str) -> List[Dict]:
        """
        Parse column definitions from CREATE TABLE statement

        Args:
            columns_def: Column definitions string

        Returns:
            List of column dictionaries
        """
        columns = []

        # Split by comma, but be careful with nested parentheses
        column_lines = self._split_columns(columns_def)

        for line in column_lines:
            line = line.strip()
            if not line:
                continue
            # Skip constraint lines
            line_upper = line.upper().lstrip()
            if (line_upper.startswith('FOREIGN KEY') or
                line_upper.startswith('CONSTRAINT') or
                line_upper.startswith('PRIMARY KEY') or
                line_upper.startswith('UNIQUE') or
                line_upper.startswith('CHECK')):
                continue

            column_info = self._parse_column_definition(line)
            if column_info:
                columns.append(column_info)

        return columns

    def _split_columns(self, columns_def: str) -> List[str]:
        """Split column definitions by comma, handling nested parentheses"""
        columns = []
        current = []
        paren_depth = 0

        for char in columns_def:
            if char == '(':
                paren_depth += 1
            elif char == ')':
                paren_depth -= 1
            elif char == ',' and paren_depth == 0:
                columns.append(''.join(current))
                current = []
                continue
            current.append(char)

        if current:
            columns.append(''.join(current))

        return columns

    def _parse_column_definition(self, column_def: str) -> Optional[Dict]:
        """
        Parse a single column definition

        Args:
            column_def: Single column definition string

        Returns:
            Dictionary with column metadata
        """
        # Extended pattern supporting more data types
        # Supports: VARCHAR, INT, INTEGER, BIGINT, SMALLINT, SERIAL, BIGSERIAL,
        #           TEXT, TIMESTAMP, DATETIME, DATE, BOOLEAN, BOOL, BIT,
        #           DECIMAL, NUMERIC, FLOAT, DOUBLE, REAL, CHAR, UUID, JSONB, JSON
        pattern = (
            r'(\w+)\s+'
            r'(VARCHAR|CHAR|INT|INTEGER|BIGINT|SMALLINT|SERIAL|BIGSERIAL|'
            r'TEXT|TIMESTAMP|DATETIME|DATE|'
            r'BOOLEAN|BOOL|BIT|'
            r'DECIMAL|NUMERIC|FLOAT|DOUBLE|REAL|'
            r'UUID|JSONB|JSON)'
            r'(\(\d+(?:\s*,\s*\d+)?\))?'
            r'\s*(.*)'
        )

        match = re.match(pattern, column_def.strip(), re.IGNORECASE)

        if not match:
            return None

        column_name = match.group(1)
        data_type = match.group(2).upper()
        size = match.group(3) if match.group(3) else None
        constraints = match.group(4).upper() if match.group(4) else ''

        # Parse size if present
        if size:
            size = size.strip('()')

        # Check constraints
        is_primary_key = 'PRIMARY KEY' in constraints
        is_nullable = 'NOT NULL' not in constraints
        has_default = 'DEFAULT' in constraints

        # Normalize some types for consistency
        if data_type in ('BIGINT', 'SMALLINT', 'SERIAL', 'BIGSERIAL'):
            data_type = data_type  # Keep as-is, will be mapped in model generator
        elif data_type == 'BIT':
            data_type = 'BOOLEAN'
        elif data_type == 'CHAR':
            data_type = 'CHAR'
        elif data_type == 'REAL':
            data_type = 'FLOAT'
        elif data_type == 'DOUBLE':
            data_type = 'FLOAT'

        return {
            'original_name': column_name,
            'type': data_type,
            'size': size,
            'primary_key': is_primary_key,
            'nullable': is_nullable,
            'has_default': has_default
        }

    def get_table_count(self) -> int:
        """Get number of parsed tables"""
        return len(self.tables)

    def get_column_count(self) -> int:
        """Get total number of columns across all tables"""
        return sum(len(table['columns']) for table in self.tables)

    def _parse_functions(self, sql_content: str) -> None:
        """
        Extract CREATE FUNCTION and CREATE PROCEDURE statements

        Args:
            sql_content: Raw SQL content (with comments preserved for context)
        """
        # Remove block comments to avoid false matches inside comments
        clean_for_funcs = re.sub(r'/\*.*?\*/', '', sql_content, flags=re.DOTALL)

        # Pattern for CREATE OR REPLACE FUNCTION/PROCEDURE
        # Supports schema-qualified names like feature_layer.fn_name
        # Matches until the final $$; or END; delimiter
        function_pattern = (
            r'CREATE\s+(?:OR\s+REPLACE\s+)?'
            r'(FUNCTION|PROCEDURE)\s+'
            r'([\w.]+)\s*\((.*?)\)'
            r'(.*?)'
            r'(?:\$\$;|\bEND;\s*\$\$;|\bEND\s*;)'
        )

        matches = re.finditer(function_pattern, clean_for_funcs, re.IGNORECASE | re.DOTALL)

        for match in matches:
            obj_type = match.group(1).lower()
            function_name = match.group(2)
            parameters = match.group(3).strip()
            body_and_returns = match.group(4).strip()

            # Extract RETURNS clause if present
            returns_match = re.search(r'RETURNS\s+(.*?)(?:LANGUAGE|AS|\$\$)', body_and_returns, re.IGNORECASE | re.DOTALL)
            returns_type = returns_match.group(1).strip() if returns_match else None

            # Extract LANGUAGE
            language_match = re.search(r'LANGUAGE\s+(\w+)', body_and_returns, re.IGNORECASE)
            language = language_match.group(1) if language_match else 'SQL'

            function_info = {
                'name': function_name,
                'parameters': parameters,
                'returns': returns_type,
                'language': language,
                'type': obj_type
            }

            self.functions.append(function_info)

    def _parse_indexes(self, sql_content: str) -> None:
        """
        Extract CREATE INDEX statements

        Supports:
        - CREATE INDEX / CREATE UNIQUE INDEX
        - IF NOT EXISTS
        - Schema-qualified table names (e.g. raw_layer.table_name)
        - Partial indexes with WHERE clauses
        - Expression indexes (e.g. LOWER(col))
        - USING method (GIN, BTREE, etc.)

        Args:
            sql_content: SQL content with comments removed
        """
        # Pattern for CREATE INDEX or CREATE UNIQUE INDEX
        # Supports schema-qualified table names with dots
        index_pattern = (
            r'CREATE\s+(?:(UNIQUE)\s+)?INDEX\s+'
            r'(?:IF\s+NOT\s+EXISTS\s+)?'
            r'([\w.]+)\s+'
            r'(?:USING\s+\w+\s+)?'  # Optional USING clause (GIN, BTREE, etc.)
            r'ON\s+([\w.]+)\s*'
            r'(?:USING\s+\w+\s*)?'  # USING can also appear after ON table
            r'\(([^)]+)\)'
            r'(?:\s+WHERE\s+(.+?))?'  # Optional WHERE clause for partial indexes
            r'\s*;'
        )

        matches = re.finditer(index_pattern, sql_content, re.IGNORECASE | re.DOTALL)

        for match in matches:
            is_unique = match.group(1) is not None
            index_name = match.group(2)
            table_name = match.group(3)
            columns = match.group(4).strip()
            where_clause = match.group(5).strip() if match.group(5) else None

            index_info = {
                'name': index_name,
                'table': table_name,
                'columns': columns,
                'unique': is_unique,
                'where': where_clause
            }

            self.indexes.append(index_info)

    def _parse_views(self, sql_content: str) -> None:
        """
        Extract CREATE VIEW and CREATE MATERIALIZED VIEW statements

        Args:
            sql_content: SQL content with comments removed
        """
        # Pattern for CREATE [OR REPLACE] [MATERIALIZED] VIEW
        view_pattern = (
            r'CREATE\s+(?:OR\s+REPLACE\s+)?'
            r'(MATERIALIZED\s+)?VIEW\s+'
            r'(?:IF\s+NOT\s+EXISTS\s+)?'
            r'([\w.]+)\s+AS\s+'
            r'(SELECT\b.*?)'
            r';'
        )

        matches = re.finditer(view_pattern, sql_content, re.IGNORECASE | re.DOTALL)

        for match in matches:
            is_materialized = match.group(1) is not None
            view_name = match.group(2)
            definition = match.group(3).strip()

            view_info = {
                'name': view_name,
                'materialized': is_materialized,
                'definition': definition[:500]  # Truncate long definitions
            }

            self.views.append(view_info)

    def get_functions(self) -> List[Dict]:
        """Get list of parsed functions"""
        return self.functions

    def get_indexes(self) -> List[Dict]:
        """Get list of parsed indexes"""
        return self.indexes

    def get_views(self) -> List[Dict]:
        """Get list of parsed views"""
        return self.views
