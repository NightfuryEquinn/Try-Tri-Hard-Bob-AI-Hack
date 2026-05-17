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

            # Common abbreviations (used for table name expansion)
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
            'HDR': 'Header',
            'LN': 'Line',
            'ITM': 'Item',
            'WH': 'Warehouse',
            'INV': 'Invoice',
            'PMT': 'Payment',
            'TXN': 'Transaction',
            'LVL': 'Level',
            'LOC': 'Location',
            'TERR': 'Territory',
            'CFG': 'Config',
            'SYS': 'System',
            'USR': 'User',
            'LKP': 'Lookup',
            'REF': 'Reference',
            'HIST': 'History',
            'PRD': 'Product',
            'SALES': 'Sales',
            'HR': 'Hr',
            'FINAL': '',
            'STATUS': 'Status',
            'PRICE': 'Price',
            'STOCK': 'Stock',
            'ACTIVITY': 'Activity',
            'LOG': 'Log',
            'PARAMS': 'Params',
            'COUNTRY': 'Country',
            'CD': 'Code',

            # Common column abbreviations
            'fname': 'first_name',
            'lname': 'last_name',
            'f': 'first',
            'l': 'last',
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
            'str': 'store',
            'prd': 'product',
            'cat': 'category',
            'subcat': 'subcategory',
            'mgr': 'manager',
            'emp': 'employee',
            'dept': 'department',
            'terr': 'territory',
            'inv': 'invoice',
            'pmt': 'payment',
            'txn': 'transaction',
            'wh': 'warehouse',
            'lvl': 'level',
            'cfg': 'config',
            'usr': 'user',
            'nm': 'name',
            'cd': 'code',
            'ref': 'reference',
            'lmt': 'limit',
            'pct': 'percent',
            'eff': 'effective',
            'ln': 'line',
            'ph': 'phone',
            'mid': 'middle',
            'init': 'initial',
            'uom': 'unit_of_measure',
        }

        self.transformation_log = []
        self.used_column_names = set()
    
    def normalize_table_name(self, table_name: str) -> str:
        """
        Convert legacy table name to clean Python class name

        Args:
            table_name: Original table name (e.g., 'tbl_CUST_MSTR_2012_v2')
                        May include schema prefix (e.g., 'raw_layer.z_customer_master_legacy')

        Returns:
            Clean class name (e.g., 'Customer')
        """
        original = table_name
        cleaned = table_name

        # Strip schema prefix if present (e.g., raw_layer.table_name -> table_name)
        if '.' in cleaned:
            cleaned = cleaned.split('.')[-1]
            self._log_transformation(original, f"Stripped schema prefix, using: {cleaned}")

        # Remove common table prefixes (case-insensitive)
        for prefix in ['tbl_', 'tb_', 't_']:
            if cleaned.lower().startswith(prefix):
                cleaned = cleaned[len(prefix):]
                self._log_transformation(original, f"Removed prefix: {prefix}")

        # Remove version suffixes (e.g., _2012_v2, _v1, _2015, _FINAL_v3)
        cleaned = re.sub(r'_FINAL', '', cleaned, flags=re.IGNORECASE)
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
        
        # Step 1: Handle explicit special cases FIRST (before prefix removal)
        # Timestamp patterns with dt_ prefix
        if cleaned == 'dt_upd_dt':
            result = 'updated_at'
            self._log_transformation(original, f"Special case: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        elif cleaned == 'dt_crt_dt':
            result = 'created_at'
            self._log_transformation(original, f"Special case: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        elif cleaned == 'dt_ord_dt':
            result = 'ordered_at'
            self._log_transformation(original, f"Special case: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        
        # Step 2: Remove type prefixes but keep the semantic part
        prefix_removed = None
        for prefix in ['vch_', 'int_', 'dec_', 'dt_', 'bit_', 'txt_']:
            if cleaned.startswith(prefix):
                cleaned = cleaned[len(prefix):]
                prefix_removed = prefix
                self._log_transformation(original, f"Removed type prefix: {prefix}", is_column=True)
                break
        
        # Step 3: Handle foreign key prefix specially - remove fk_ but keep the rest
        if cleaned.startswith('fk_'):
            cleaned = cleaned[3:]  # Remove 'fk_' prefix
            self._log_transformation(original, f"Removed FK prefix, keeping: {cleaned}", is_column=True)
            # Now expand the remaining part
            # e.g., 'str_id' -> 'store_id', 'cust_id' -> 'customer_id'
        
        # Step 4: Handle primary key column prefix (c_, str_, ord_)
        # These should become just 'id'
        if cleaned in ['c_id', 'id']:
            result = 'id'
            self._log_transformation(original, f"Primary key: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        
        # For table-specific IDs like str_id, ord_id - these are primary keys, make them 'id'
        if cleaned in ['str_id', 'ord_id', 'cust_id'] and not original.lower().startswith('fk_'):
            result = 'id'
            self._log_transformation(original, f"Primary key: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        
        # Step 5: Handle remaining timestamp patterns
        if cleaned.endswith('_dt'):
            cleaned = cleaned[:-3]  # Remove '_dt' suffix
            if cleaned in ['upd', 'update']:
                result = 'updated_at'
            elif cleaned in ['crt', 'create']:
                result = 'created_at'
            elif cleaned in ['ord', 'order']:
                result = 'ordered_at'
            else:
                result = cleaned + '_at'
            self._log_transformation(original, f"Converted to timestamp: {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        
        # Step 6: Handle ID columns (including foreign keys)
        if cleaned.endswith('_id'):
            # Split and expand the part before '_id'
            base = cleaned[:-3]  # Remove '_id'
            parts = base.split('_')
            expanded_parts = []
            
            for part in parts:
                if part in self.abbreviations:
                    expanded = self.abbreviations[part]
                    if expanded:
                        expanded_parts.append(expanded)
                        self._log_transformation(original, f"Expanded: {part} → {expanded}", is_column=True)
                else:
                    expanded_parts.append(part)
            
            if expanded_parts:
                result = '_'.join(expanded_parts) + '_id'
            else:
                result = 'id'
            
            self._log_transformation(original, f"ID column: {cleaned} → {result}", is_column=True)
            return self._ensure_unique_column_name(result, original)
        
        # Step 7: Split by underscore and expand abbreviations for regular columns
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
        return self._ensure_unique_column_name(result, original)
    
    def _ensure_unique_column_name(self, name: str, original: str) -> str:
        """
        Ensure column name is unique within the current table context.
        If duplicate, append a numeric suffix.
        
        Args:
            name: Proposed column name
            original: Original column name for logging
            
        Returns:
            Unique column name
        """
        if name not in self.used_column_names:
            self.used_column_names.add(name)
            return name
        
        # Name is duplicate, find a unique suffix
        counter = 2
        while f"{name}_{counter}" in self.used_column_names:
            counter += 1
        
        unique_name = f"{name}_{counter}"
        self.used_column_names.add(unique_name)
        self._log_transformation(original, f"Duplicate detected, renamed to: {unique_name}", is_column=True)
        return unique_name
    
    def reset_column_context(self):
        """Reset the used column names tracker for a new table"""
        self.used_column_names.clear()
    
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
