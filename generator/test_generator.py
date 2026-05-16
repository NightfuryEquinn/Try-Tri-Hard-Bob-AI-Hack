"""
Pytest Test Generator for LegacyLink AI
Generates starter pytest test files for generated models
"""

from typing import List, Dict


class TestGenerator:
    """Generate pytest test files for SQLAlchemy models"""
    
    def generate_tests(self, tables: List[Dict]) -> str:
        """
        Generate complete test_models.py file content
        
        Args:
            tables: List of table dictionaries with normalized names
            
        Returns:
            Complete Python code for test_models.py
        """
        imports = self._generate_imports(tables)
        tests = []
        
        for table in tables:
            table_tests = self._generate_table_tests(table)
            tests.extend(table_tests)
        
        return imports + '\n\n' + '\n\n'.join(tests)
    
    def _generate_imports(self, tables: List[Dict]) -> str:
        """Generate import statements"""
        class_names = [table['clean_name'] for table in tables]
        
        imports = [
            '"""',
            'Test suite for generated SQLAlchemy models',
            'Run with: pytest test_models.py',
            '"""',
            '',
            'import pytest',
            f"from models import {', '.join(class_names)}",
            'from sqlalchemy import inspect'
        ]
        
        return '\n'.join(imports)
    
    def _generate_table_tests(self, table: Dict) -> List[str]:
        """
        Generate test functions for a single table
        
        Args:
            table: Table dictionary with metadata
            
        Returns:
            List of test function code strings
        """
        class_name = table['clean_name']
        table_name = table['table_name']
        columns = table['columns']
        
        tests = []
        
        # Test 1: Table name verification
        test_tablename = [
            f"def test_{table_name}_table_name():",
            f'    """Verify {class_name} has correct table name"""',
            f'    assert {class_name}.__tablename__ == "{table_name}"'
        ]
        tests.append('\n'.join(test_tablename))
        
        # Test 2: Primary key existence
        primary_keys = [col['clean_name'] for col in columns if col.get('primary_key')]
        if primary_keys:
            test_pk = [
                f"def test_{table_name}_has_primary_key():",
                f'    """Verify {class_name} has primary key"""',
                f'    mapper = inspect({class_name})',
                f'    pk_columns = [col.name for col in mapper.primary_key]',
                f'    assert {primary_keys} == pk_columns'
            ]
            tests.append('\n'.join(test_pk))
        
        # Test 3: Column existence
        column_names = [col['clean_name'] for col in columns]
        test_columns = [
            f"def test_{table_name}_has_expected_columns():",
            f'    """Verify {class_name} has all expected columns"""',
            f'    expected_columns = {column_names}',
            f'    mapper = inspect({class_name})',
            f'    actual_columns = [col.name for col in mapper.columns]',
            f'    for column in expected_columns:',
            f'        assert column in actual_columns, f"Column {{column}} not found in {class_name}"'
        ]
        tests.append('\n'.join(test_columns))
        
        # Test 4: Column types
        test_types = [
            f"def test_{table_name}_column_types():",
            f'    """Verify {class_name} column types are correct"""',
            f'    mapper = inspect({class_name})',
            ''
        ]
        
        for col in columns:
            col_name = col['clean_name']
            sql_type = col['type']
            
            # Map to expected SQLAlchemy type name
            if sql_type in ['INT', 'INTEGER']:
                expected_type = 'INTEGER'
            elif sql_type == 'VARCHAR':
                expected_type = 'VARCHAR'
            elif sql_type == 'TEXT':
                expected_type = 'TEXT'
            elif sql_type in ['TIMESTAMP', 'DATETIME']:
                expected_type = 'DATETIME'
            elif sql_type == 'DATE':
                expected_type = 'DATE'
            elif sql_type in ['BOOLEAN', 'BOOL']:
                expected_type = 'BOOLEAN'
            elif sql_type in ['DECIMAL', 'NUMERIC']:
                expected_type = 'NUMERIC'
            elif sql_type in ['FLOAT', 'DOUBLE']:
                expected_type = 'FLOAT'
            else:
                expected_type = 'VARCHAR'
            
            test_types.append(f'    col_{col_name} = mapper.columns["{col_name}"]')
            test_types.append(f'    assert col_{col_name}.type.__class__.__name__.upper() in ["{expected_type}", "{sql_type}"]')
        
        tests.append('\n'.join(test_types))
        
        # Test 5: Nullable constraints
        test_nullable = [
            f"def test_{table_name}_nullable_constraints():",
            f'    """Verify {class_name} nullable constraints"""',
            f'    mapper = inspect({class_name})',
            ''
        ]
        
        for col in columns:
            col_name = col['clean_name']
            is_nullable = col.get('nullable', True)
            is_primary = col.get('primary_key', False)
            
            if is_primary:
                test_nullable.append(f'    assert not mapper.columns["{col_name}"].nullable, "{col_name} should not be nullable (primary key)"')
            elif not is_nullable:
                test_nullable.append(f'    assert not mapper.columns["{col_name}"].nullable, "{col_name} should not be nullable"')
        
        if len(test_nullable) > 4:  # Only add if there are actual assertions
            tests.append('\n'.join(test_nullable))
        
        return tests

# Made with Bob
