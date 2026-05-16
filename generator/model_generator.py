"""
SQLAlchemy Model Generator for LegacyLink AI
Generates modern SQLAlchemy 2.0 ORM models from parsed schema
"""

from typing import List, Dict


class ModelGenerator:
    """Generate SQLAlchemy 2.0 ORM model classes"""
    
    def __init__(self):
        self.type_mapping = {
            'INT': 'Integer',
            'INTEGER': 'Integer',
            'VARCHAR': 'String',
            'TEXT': 'Text',
            'TIMESTAMP': 'DateTime',
            'DATETIME': 'DateTime',
            'DATE': 'Date',
            'BOOLEAN': 'Boolean',
            'BOOL': 'Boolean',
            'DECIMAL': 'Numeric',
            'NUMERIC': 'Numeric',
            'FLOAT': 'Float',
            'DOUBLE': 'Float'
        }
    
    def generate_models(self, tables: List[Dict]) -> str:
        """
        Generate complete models.py file content
        
        Args:
            tables: List of table dictionaries with normalized names
            
        Returns:
            Complete Python code for models.py
        """
        imports = self._generate_imports(tables)
        models = []
        
        for table in tables:
            model_code = self._generate_model_class(table)
            models.append(model_code)
        
        return imports + '\n\n' + '\n\n'.join(models)
    
    def _generate_imports(self, tables: List[Dict]) -> str:
        """Generate import statements based on used types"""
        imports = [
            "from sqlalchemy.orm import Mapped, mapped_column, DeclarativeBase",
            "from sqlalchemy import Integer, String, Text, DateTime, Date, Boolean, Numeric, Float"
        ]
        
        # Check if datetime is needed
        has_datetime = any(
            any(col['type'] in ['TIMESTAMP', 'DATETIME'] for col in table['columns'])
            for table in tables
        )
        
        if has_datetime:
            imports.append("from datetime import datetime")
        
        return '\n'.join(imports)
    
    def _generate_model_class(self, table: Dict) -> str:
        """
        Generate a single SQLAlchemy model class
        
        Args:
            table: Table dictionary with normalized names and columns
            
        Returns:
            Python code for the model class
        """
        class_name = table['clean_name']
        table_name = table['table_name']
        original_name = table['original_name']
        
        # Class definition and docstring
        code = [
            f"class {class_name}(Base):",
            f'    """',
            f'    Represents {table_name} records.',
            f'    Migrated from legacy table: {original_name}',
            f'    """',
            f'    __tablename__ = "{table_name}"',
            ''
        ]
        
        # Generate column definitions
        for column in table['columns']:
            column_def = self._generate_column_definition(column)
            code.append(f'    {column_def}')
        
        return '\n'.join(code)
    
    def _generate_column_definition(self, column: Dict) -> str:
        """
        Generate a single column definition
        
        Args:
            column: Column dictionary with metadata
            
        Returns:
            Python code for the column definition
        """
        col_name = column['clean_name']
        sql_type = column['type']
        size = column.get('size')
        is_primary = column.get('primary_key', False)
        is_nullable = column.get('nullable', True)
        
        # Map SQL type to SQLAlchemy type
        sa_type = self.type_mapping.get(sql_type, 'String')
        
        # Add size for String types
        if sa_type == 'String' and size:
            sa_type = f'String({size})'
        
        # Determine Python type hint
        if sa_type.startswith('String') or sa_type == 'Text':
            py_type = 'str'
        elif sa_type == 'Integer':
            py_type = 'int'
        elif sa_type == 'Float' or sa_type == 'Numeric':
            py_type = 'float'
        elif sa_type == 'Boolean':
            py_type = 'bool'
        elif sa_type == 'DateTime' or sa_type == 'Date':
            py_type = 'datetime'
        else:
            py_type = 'str'
        
        # Build column definition
        column_args = []
        
        if is_primary:
            column_args.append('primary_key=True')
        
        if not is_nullable and not is_primary:
            column_args.append('nullable=False')
        
        # Add index for foreign key columns
        if col_name.endswith('_id') and not is_primary:
            column_args.append('index=True')
        
        # Add default for timestamp columns
        if sa_type == 'DateTime' and ('updated' in col_name or 'created' in col_name):
            column_args.append('default=datetime.utcnow')
        
        # Build the complete definition
        args_str = ', '.join(column_args) if column_args else ''
        
        if args_str:
            definition = f"{col_name}: Mapped[{py_type}] = mapped_column({sa_type}, {args_str})"
        else:
            definition = f"{col_name}: Mapped[{py_type}] = mapped_column({sa_type})"
        
        return definition
    
    def generate_database_file(self) -> str:
        """
        Generate database.py with Base class
        
        Returns:
            Complete Python code for database.py
        """
        code = [
            '"""',
            'Database configuration for LegacyLink AI generated models',
            '"""',
            '',
            'from sqlalchemy.orm import DeclarativeBase',
            '',
            '',
            'class Base(DeclarativeBase):',
            '    """Base class for all ORM models"""',
            '    pass'
        ]
        
        return '\n'.join(code)

# Made with Bob
