"""
Index Generator for LegacyLink AI
Generates SQLAlchemy index definitions from legacy SQL indexes
"""

from typing import List, Dict


class IndexGenerator:
    """Generate SQLAlchemy index definitions from legacy SQL indexes"""
    
    def generate_indexes_file(self, indexes: List[Dict]) -> str:
        """
        Generate indexes.py file content
        
        Args:
            indexes: List of index dictionaries from parser
            
        Returns:
            Complete Python code for indexes.py
        """
        if not indexes:
            return self._generate_empty_file()
        
        code = [
            '"""',
            'Modernized Indexes',
            'Legacy SQL indexes converted to SQLAlchemy Index definitions',
            '"""',
            '',
            'from sqlalchemy import Index',
            '',
            '# Index definitions to be added to your models',
            '# Add these to the __table_args__ attribute of the corresponding model class',
            '',
            ''
        ]
        
        # Group indexes by table
        indexes_by_table = {}
        for idx in indexes:
            table = idx['table']
            if table not in indexes_by_table:
                indexes_by_table[table] = []
            indexes_by_table[table].append(idx)
        
        # Generate index definitions grouped by table
        for table, table_indexes in indexes_by_table.items():
            # Create valid Python variable name (replace dots with underscores)
            var_name = table.replace('.', '_').upper()
            code.append(f"# Indexes for {table} table")
            code.append(f"{var_name}_INDEXES = (")
            
            for idx in table_indexes:
                index_def = self._generate_index_definition(idx)
                code.append(f"    {index_def},")
            
            code.append(")")
            code.append("")
            code.append("")
        
        # Add usage instructions
        code.append(self._generate_usage_instructions(indexes_by_table))
        
        return '\n'.join(code)
    
    def _generate_index_definition(self, idx: Dict) -> str:
        """
        Generate a single SQLAlchemy Index definition
        
        Args:
            idx: Index dictionary with metadata
            
        Returns:
            Python Index definition code
        """
        index_name = idx['name']
        columns = idx['columns']
        is_unique = idx['unique']
        
        # Parse column names
        column_list = [col.strip() for col in columns.split(',')]
        columns_str = ', '.join(f"'{col}'" for col in column_list)
        
        # Build Index definition
        if is_unique:
            return f"Index('{index_name}', {columns_str}, unique=True)"
        else:
            return f"Index('{index_name}', {columns_str})"
    
    def _generate_usage_instructions(self, indexes_by_table: Dict[str, List[Dict]]) -> str:
        """Generate usage instructions for the indexes"""
        instructions = [
            '"""',
            'Usage Instructions:',
            '',
            'To add these indexes to your models, include them in the __table_args__ attribute:',
            '',
            'Example:',
            ''
        ]
        
        # Show example for first table
        if indexes_by_table:
            first_table = list(indexes_by_table.keys())[0]
            var_name = first_table.replace('.', '_').upper()
            display_name = first_table.split('.')[-1] if '.' in first_table else first_table
            instructions.append(f'class {display_name.title()}(Base):')
            instructions.append('    __tablename__ = "' + display_name.lower() + '"')
            instructions.append('    ')
            instructions.append('    # ... column definitions ...')
            instructions.append('    ')
            instructions.append(f'    __table_args__ = {var_name}_INDEXES')
            instructions.append('')
        
        instructions.append('Or combine with other table arguments:')
        instructions.append('')
        instructions.append('    __table_args__ = (')
        instructions.append('        *YOUR_TABLE_INDEXES,')
        instructions.append('        {"schema": "public"}  # other table options')
        instructions.append('    )')
        instructions.append('"""')
        
        return '\n'.join(instructions)
    
    def _generate_empty_file(self) -> str:
        """Generate empty indexes.py when no indexes found"""
        return '''"""
Modernized Indexes
No legacy SQL indexes were found in the schema
"""

# No indexes to modernize
pass
'''


# Made with Bob