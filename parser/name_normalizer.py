"""
Name Normalizer Module for LegacyLink AI
Cleans legacy table and column names into modern Python conventions
"""

import re
from typing import Dict, List, Tuple


class NameNormalizer:
    """Normalize legacy database names to clean Python conventions"""
    
    def __init__(self):
        # Abbreviation dictionary for common legacy patterns
        self.abbreviations = {
            # Table prefixes
            'tbl_': '',
            'tb_': '',
            't_': '',
            
            # Common abbreviations
            'CUST': 'Customer',
            'MSTR': 'Master',
            'STR': 'Store',
            'ORD': 'Order',
            'DTL': 'Detail',
            'ADDR': 'Address',
            'AMT': 'Amount',
            'QTY': 'Quantity',
            'NUM': 'Number',
            'DESC': 'Description',
            'PROD': 'Product',
            'CAT': 'Category',
            'DEPT': 'Department',
            'EMP': 'Employee',
            'MGR': 'Manager',
            
            # Column prefixes
            'vch_': '',
            'int_': '',
            'dec_': '',
            'dt_': '',
            'fk_': '',
            'c_': '',
            'str_': '',
            
            # Common column abbreviations
            'fname': 'first_name',
            'lname': 'last_name',
            'addr': 'address',
            'amt': 'amount',
            'qty': 'quantity',
            'num': 'number',
            'desc': 'description',
            'upd': 'updated',
            'crt': 'created',
            'cust': 'customer',
            'ord': 'order',
            'prod': 'product',
        }
        
        self.transformation_log = []
    
    def normalize_table_name(self, table_name: str) -> str:
        """
        Convert legacy table name to clean Python class name
        
        Args:
            table_name: Original table name (e.g., 'tbl_CUST_MSTR_2012_v2')
            
        Returns:
            Clean class name (e.g., 'Customer')
        """
        original = table_name
        cleaned = table_name
        
        # Remove common prefixes
        for prefix in ['tbl_', 'tb_', 't_']:
            if cleaned.lower().startswith(prefix):
                cleaned = cleaned[len(prefix):]
                self._log_transformation(original, f"Removed prefix: {prefix}")
        
        # Remove version suffixes (e.g., _2012_v2, _v1, _2015)
        cleaned = re.sub(r'_\d{4}(_v\d+)?$', '', cleaned)
        cleaned = re.sub(r'_v\d+$', '', cleaned)
        if cleaned != table_name:
            self._log_transformation(original, "Removed version suffix")
        
        # Split by underscore and expand abbreviations
        parts = cleaned.split('_')
        expanded_parts = []
        
        for part in parts:
            part_upper = part.upper()
            if part_upper in self.abbreviations:
                expanded = self.abbreviations[part_upper]
                if expanded:  # Only add if not empty string
                    expanded_parts.append(expanded)
                    self._log_transformation(original, f"Expanded: {part} → {expanded}")
            else:
                # Capitalize first letter
                expanded_parts.append(part.capitalize())
        
        # Join parts and remove 'Master' if it's redundant
        result = ''.join(expanded_parts)
        if result.endswith('Master'):
            result = result[:-6]  # Remove 'Master'
            self._log_transformation(original, "Removed redundant 'Master'")
        
        # Ensure result is not empty
        if not result:
            result = table_name.capitalize()
        
        self._log_transformation(original, f"Final table name: {result}")
        return result
    
    def normalize_column_name(self, column_name: str) -> str:
        """
        Convert legacy column name to clean Python attribute name
        
        Args:
            column_name: Original column name (e.g., 'vch_fname', 'dt_upd_dt')
            
        Returns:
            Clean attribute name (e.g., 'first_name', 'updated_at')
        """
        original = column_name
        cleaned = column_name.lower()
        
        # Remove common prefixes
        for prefix in ['vch_', 'int_', 'dec_', 'dt_', 'fk_', 'c_', 'str_']:
            if cleaned.startswith(prefix):
                cleaned = cleaned[len(prefix):]
                self._log_transformation(original, f"Removed prefix: {prefix}", is_column=True)
        
        # Handle special cases for timestamps
        if cleaned.endswith('_dt'):
            cleaned = cleaned[:-3]  # Remove '_dt' suffix
            if cleaned.endswith('_upd'):
                cleaned = 'updated_at'
            elif cleaned.endswith('_crt'):
                cleaned = 'created_at'
            elif cleaned.endswith('_ord'):
                cleaned = 'ordered_at'
            else:
                cleaned = cleaned + '_at'
            self._log_transformation(original, f"Converted to timestamp: {cleaned}", is_column=True)
            return cleaned
        
        # Handle ID columns
        if cleaned == 'id' or cleaned.endswith('_id'):
            self._log_transformation(original, f"Kept as: {cleaned}", is_column=True)
            return cleaned
        
        # Split by underscore and expand abbreviations
        parts = cleaned.split('_')
        expanded_parts = []
        
        for part in parts:
            if part in self.abbreviations:
                expanded = self.abbreviations[part]
                if expanded:  # Only add if not empty string
                    expanded_parts.append(expanded)
                    self._log_transformation(original, f"Expanded: {part} → {expanded}", is_column=True)
            else:
                expanded_parts.append(part)
        
        result = '_'.join(expanded_parts)
        
        # Ensure result is not empty
        if not result:
            result = column_name.lower()
        
        self._log_transformation(original, f"Final column name: {result}", is_column=True)
        return result
    
    def normalize_table_name_to_tablename(self, class_name: str) -> str:
        """
        Convert class name to database table name (lowercase, pluralized)
        
        Args:
            class_name: Python class name (e.g., 'Customer')
            
        Returns:
            Database table name (e.g., 'customers')
        """
        # Convert to lowercase
        table_name = class_name.lower()
        
        # Simple pluralization
        if table_name.endswith('y'):
            table_name = table_name[:-1] + 'ies'
        elif table_name.endswith('s'):
            table_name = table_name + 'es'
        else:
            table_name = table_name + 's'
        
        return table_name
    
    def _log_transformation(self, original: str, change: str, is_column: bool = False):
        """Log a transformation for the modernization report"""
        item_type = "Column" if is_column else "Table"
        self.transformation_log.append({
            'type': item_type,
            'original': original,
            'change': change
        })
    
    def get_transformation_log(self) -> List[Dict]:
        """Get all logged transformations"""
        return self.transformation_log
    
    def clear_log(self):
        """Clear transformation log"""
        self.transformation_log = []

# Made with Bob
