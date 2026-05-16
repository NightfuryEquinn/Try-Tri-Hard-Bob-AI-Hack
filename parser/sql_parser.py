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
    
    def parse_sql_file(self, sql_content: str) -> List[Dict]:
        """
        Parse SQL content and extract table definitions, functions, and indexes
        
        Supports both CREATE TABLE and CREATE TABLE IF NOT EXISTS syntax.
        Also extracts CREATE FUNCTION/PROCEDURE and CREATE INDEX statements.
        
        Args:
            sql_content: Raw SQL file content
            
        Returns:
            List of table dictionaries with metadata
        """
        self.tables = []
        self.functions = []
        self.indexes = []
        
        # Store original content before removing comments for function body extraction
        original_content = sql_content
        
        # Remove comments for pattern matching
        sql_content_clean = self._remove_comments(sql_content)
        
        # Extract CREATE TABLE statements (with or without IF NOT EXISTS)
        create_table_pattern = r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s*\((.*?)\);'
        matches = re.finditer(create_table_pattern, sql_content_clean, re.IGNORECASE | re.DOTALL)
        
        for match in matches:
            table_name = match.group(1)
            columns_def = match.group(2)
            
            table_info = {
                'original_name': table_name,
                'columns': self._parse_columns(columns_def)
            }
            
            self.tables.append(table_info)
        
        # Extract functions and procedures
        self._parse_functions(original_content)
        
        # Extract indexes
        self._parse_indexes(sql_content_clean)
        
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
            if not line or line.upper().startswith('FOREIGN KEY') or line.upper().startswith('CONSTRAINT'):
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
        # Pattern: column_name DATA_TYPE[(size)] [PRIMARY KEY] [NOT NULL] [DEFAULT value]
        pattern = r'(\w+)\s+(VARCHAR|INT|INTEGER|TEXT|TIMESTAMP|DATETIME|DATE|BOOLEAN|BOOL|DECIMAL|NUMERIC|FLOAT|DOUBLE)(\(\d+(?:,\d+)?\))?\s*(.*)'
        
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

# Made with Bob

    
    def _parse_functions(self, sql_content: str) -> None:
        """
        Extract CREATE FUNCTION and CREATE PROCEDURE statements
        
        Args:
            sql_content: Raw SQL content (with comments preserved for context)
        """
        # Pattern for CREATE OR REPLACE FUNCTION/PROCEDURE
        # Matches until the final $$ or END; delimiter
        function_pattern = r'CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+(\w+)\s*\((.*?)\)(.*?)(?:\$\$;|\bEND\s*;)'
        
        matches = re.finditer(function_pattern, sql_content, re.IGNORECASE | re.DOTALL)
        
        for match in matches:
            function_name = match.group(1)
            parameters = match.group(2).strip()
            body_and_returns = match.group(3).strip()
            
            # Extract RETURNS clause if present
            returns_match = re.search(r'RETURNS\s+(.*?)(?:LANGUAGE|AS)', body_and_returns, re.IGNORECASE | re.DOTALL)
            returns_type = returns_match.group(1).strip() if returns_match else None
            
            # Extract LANGUAGE
            language_match = re.search(r'LANGUAGE\s+(\w+)', body_and_returns, re.IGNORECASE)
            language = language_match.group(1) if language_match else 'SQL'
            
            function_info = {
                'name': function_name,
                'parameters': parameters,
                'returns': returns_type,
                'language': language,
                'type': 'function'
            }
            
            self.functions.append(function_info)
    
    def _parse_indexes(self, sql_content: str) -> None:
        """
        Extract CREATE INDEX statements
        
        Args:
            sql_content: SQL content with comments removed
        """
        # Pattern for CREATE INDEX or CREATE UNIQUE INDEX
        index_pattern = r'CREATE\s+(?:(UNIQUE)\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s+ON\s+(\w+)\s*\((.*?)\)'
        
        matches = re.finditer(index_pattern, sql_content, re.IGNORECASE | re.DOTALL)
        
        for match in matches:
            is_unique = match.group(1) is not None
            index_name = match.group(2)
            table_name = match.group(3)
            columns = match.group(4).strip()
            
            index_info = {
                'name': index_name,
                'table': table_name,
                'columns': columns,
                'unique': is_unique
            }
            
            self.indexes.append(index_info)
    
    def get_functions(self) -> List[Dict]:
        """Get list of parsed functions"""
        return self.functions
    
    def get_indexes(self) -> List[Dict]:
        """Get list of parsed indexes"""
        return self.indexes
