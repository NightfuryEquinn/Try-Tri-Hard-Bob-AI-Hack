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
    
    def parse_sql_file(self, sql_content: str) -> List[Dict]:
        """
        Parse SQL content and extract table definitions
        
        Args:
            sql_content: Raw SQL file content
            
        Returns:
            List of table dictionaries with metadata
        """
        self.tables = []
        
        # Remove comments
        sql_content = self._remove_comments(sql_content)
        
        # Extract CREATE TABLE statements
        create_table_pattern = r'CREATE\s+TABLE\s+(\w+)\s*\((.*?)\);'
        matches = re.finditer(create_table_pattern, sql_content, re.IGNORECASE | re.DOTALL)
        
        for match in matches:
            table_name = match.group(1)
            columns_def = match.group(2)
            
            table_info = {
                'original_name': table_name,
                'columns': self._parse_columns(columns_def)
            }
            
            self.tables.append(table_info)
        
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
