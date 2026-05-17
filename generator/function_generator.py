"""
Function Generator for LegacyLink AI
Generates modernized Python functions from legacy SQL functions/procedures
"""

from typing import List, Dict, Optional


class FunctionGenerator:
    """Generate Python functions from legacy SQL functions/procedures"""
    
    def generate_functions_file(self, functions: List[Dict]) -> str:
        """
        Generate functions.py file content
        
        Args:
            functions: List of function dictionaries from parser
            
        Returns:
            Complete Python code for functions.py
        """
        if not functions:
            return self._generate_empty_file()
        
        code = [
            '"""',
            'Modernized Functions',
            'Legacy SQL functions/procedures converted to Python',
            '"""',
            '',
            'from sqlalchemy.orm import Session',
            'from typing import Any, Optional',
            '',
            ''
        ]
        
        for func in functions:
            func_code = self._generate_function(func)
            code.append(func_code)
            code.append('')
            code.append('')
        
        return '\n'.join(code)
    
    def _generate_function(self, func: Dict) -> str:
        """
        Generate a single Python function from SQL function metadata
        
        Args:
            func: Function dictionary with metadata
            
        Returns:
            Python function code
        """
        func_name = func['name'].lower()
        params = func.get('parameters', '')
        returns = func.get('returns', 'Any')
        
        # Parse parameters
        param_list = self._parse_parameters(params)
        
        # Generate function signature
        signature = f"def {func_name}(session: Session{', ' + param_list if param_list else ''}) -> {self._map_return_type(returns)}:"
        
        docstring = f'''    """
    Modernized from legacy {func['type']}: {func['name']}
    
    Original language: {func['language']}
    
    Args:
        session: SQLAlchemy session
{self._generate_param_docs(params)}
    
    Returns:
        {returns if returns else 'Result of the operation'}
    
    Note:
        This is a placeholder implementation. Review and implement the actual logic
        based on the original SQL function body.
    """'''
        
        body = '''    # TODO: Implement the actual logic from the legacy SQL function
    # Original function should be reviewed and business logic extracted
    raise NotImplementedError(f"Function {func_name} needs implementation")'''
        
        return f"{signature}\n{docstring}\n{body}"
    
    def _parse_parameters(self, params: str) -> str:
        """Parse SQL parameters to Python parameters"""
        if not params or params.strip() == '':
            return ''
        
        # Simple parameter parsing - can be enhanced
        param_parts = [p.strip() for p in params.split(',')]
        python_params = []
        
        for param in param_parts:
            if param:
                # Extract parameter name (simple approach)
                parts = param.split()
                if parts:
                    param_name = parts[0].lower()
                    python_params.append(f"{param_name}: Any")
        
        return ', '.join(python_params)
    
    def _generate_param_docs(self, params: str) -> str:
        """Generate parameter documentation"""
        if not params or params.strip() == '':
            return ''
        
        param_parts = [p.strip() for p in params.split(',')]
        docs = []
        
        for param in param_parts:
            if param:
                parts = param.split()
                if parts:
                    param_name = parts[0].lower()
                    docs.append(f"        {param_name}: Parameter from legacy function")
        
        return '\n'.join(docs)
    
    def _map_return_type(self, returns: Optional[str]) -> str:
        """Map SQL return type to Python type hint"""
        if not returns:
            return 'Any'
        
        returns_upper = returns.upper()
        
        if 'INT' in returns_upper:
            return 'int'
        elif 'VARCHAR' in returns_upper or 'TEXT' in returns_upper:
            return 'str'
        elif 'BOOL' in returns_upper:
            return 'bool'
        elif 'DECIMAL' in returns_upper or 'NUMERIC' in returns_upper or 'FLOAT' in returns_upper:
            return 'float'
        elif 'TABLE' in returns_upper or 'SETOF' in returns_upper:
            return 'list'
        else:
            return 'Any'
    
    def _generate_empty_file(self) -> str:
        """Generate empty functions.py when no functions found"""
        return '''"""
Modernized Functions
No legacy SQL functions/procedures were found in the schema
"""

# No functions to modernize
pass
'''


# Made with Bob