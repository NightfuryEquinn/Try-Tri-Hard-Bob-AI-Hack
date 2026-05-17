"""
IBM Cloudant NoSQL client for LegacyLink AI
Handles saving and retrieving modernization history
"""
from typing import Dict, List, Optional
from datetime import datetime, timezone
import uuid
from ibmcloudant.cloudant_v1 import CloudantV1, Document
from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
from config.cloudant_config import CloudantConfig


class CloudantClient:
    """Client for IBM Cloudant NoSQL database operations"""
    
    def __init__(self, config: CloudantConfig):
        """
        Initialize Cloudant client
        
        Args:
            config: CloudantConfig instance with connection details
        """
        self.config = config
        self.client = None
        self.database_name = config.database_name
        
        if config.is_configured():
            self._initialize_client()
    
    def _initialize_client(self):
        """Initialize the Cloudant client with authentication"""
        try:
            authenticator = IAMAuthenticator(self.config.apikey)
            self.client = CloudantV1(authenticator=authenticator)
            self.client.set_service_url(self.config.url)
            
            # Ensure database exists
            self._ensure_database_exists()
            
        except Exception as e:
            print(f"Warning: Failed to initialize Cloudant client: {e}")
            self.client = None
    
    def _ensure_database_exists(self):
        """Create database if it doesn't exist"""
        try:
            self.client.get_database_information(db=self.database_name).get_result()
        except Exception:
            # Database doesn't exist, create it
            try:
                self.client.put_database(db=self.database_name).get_result()
                print(f"Created Cloudant database: {self.database_name}")
            except Exception as e:
                print(f"Warning: Failed to create database: {e}")
    
    def save_modernization_session(
        self,
        user_id: str,
        filename: str,
        file_size: int,
        tables: List[Dict],
        transformation_log: List[Dict],
        processing_stats: Dict,
        generated_files: Optional[Dict[str, str]] = None,
        original_sql: Optional[str] = None
    ) -> Optional[str]:
        """
        Save a modernization session to Cloudant

        Args:
            user_id: Unique identifier for the user
            filename: Name of uploaded SQL file
            file_size: Size of uploaded file in bytes
            tables: List of parsed and normalized tables
            transformation_log: List of transformations applied
            processing_stats: Statistics about processing
            generated_files: Dictionary of generated file contents
            original_sql: Original SQL content uploaded by user

        Returns:
            Document ID if successful, None otherwise
        """
        if not self.client:
            return None
        
        try:
            session_id = str(uuid.uuid4())[:8]
            timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f') + 'Z'
            
            document = {
                '_id': f"session_{timestamp}_{session_id}",
                'type': 'modernization_session',
                'user_id': user_id,
                'session_id': session_id,
                'timestamp': timestamp,
                'input': {
                    'filename': filename,
                    'file_size': file_size,
                    'upload_timestamp': timestamp
                },
                'processing': {
                    'table_count': processing_stats.get('table_count', 0),
                    'column_count': processing_stats.get('column_count', 0),
                    'transformation_count': processing_stats.get('transformation_count', 0),
                    'processing_time_ms': processing_stats.get('processing_time_ms', 0)
                },
                'output': {
                    'tables': [
                        {
                            'original_name': table.get('original_name'),
                            'clean_name': table.get('clean_name'),
                            'table_name': table.get('table_name'),
                            'column_count': len(table.get('columns', []))
                        }
                        for table in tables
                    ],
                    'generated_files': [
                        'models.py',
                        'database.py',
                        'test_models.py',
                        'README.md',
                        'modernization_report.md',
                        'requirements.txt',
                        'functions.py',
                        'indexes.py'
                    ]
                },
                'transformations': transformation_log,
                'generated_file_contents': generated_files or {},
                'original_sql': original_sql or '',
                'metadata': {
                    'app_version': '2.0.0',
                    'bob_assisted': True,
                    'success': True
                }
            }
            
            response = self.client.post_document(
                db=self.database_name,
                document=Document.from_dict(document)
            ).get_result()
            
            return response.get('id')
            
        except Exception as e:
            print(f"Warning: Failed to save session to Cloudant: {e}")
            return None
    
    def get_user_history(
        self,
        user_id: str,
        limit: int = 10
    ) -> List[Dict]:
        """
        Retrieve modernization history for a user
        
        Args:
            user_id: Unique identifier for the user
            limit: Maximum number of sessions to retrieve
            
        Returns:
            List of session documents
        """
        if not self.client:
            return []
        
        try:
            # Query using Cloudant Query (Mango)
            selector = {
                'type': 'modernization_session',
                'user_id': user_id
            }
            
            response = self.client.post_find(
                db=self.database_name,
                selector=selector,
                sort=[{'timestamp': 'desc'}],
                limit=limit
            ).get_result()
            
            return response.get('docs', [])
            
        except Exception as e:
            print(f"Warning: Failed to retrieve history from Cloudant: {e}")
            return []
    
    def get_session_by_id(self, session_id: str) -> Optional[Dict]:
        """
        Retrieve a specific session by ID
        
        Args:
            session_id: Session identifier
            
        Returns:
            Session document if found, None otherwise
        """
        if not self.client:
            return None
        
        try:
            selector = {
                'type': 'modernization_session',
                'session_id': session_id
            }
            
            response = self.client.post_find(
                db=self.database_name,
                selector=selector,
                limit=1
            ).get_result()
            
            docs = response.get('docs', [])
            return docs[0] if docs else None
            
        except Exception as e:
            print(f"Warning: Failed to retrieve session from Cloudant: {e}")
            return None
    
    def get_statistics(self) -> Dict:
        """
        Get overall statistics from all sessions
        
        Returns:
            Dictionary with aggregate statistics
        """
        if not self.client:
            return {}
        
        try:
            # Get all modernization sessions
            selector = {
                'type': 'modernization_session'
            }
            
            response = self.client.post_find(
                db=self.database_name,
                selector=selector,
                limit=1000  # Adjust based on expected volume
            ).get_result()
            
            docs = response.get('docs', [])
            
            total_sessions = len(docs)
            total_tables = sum(doc.get('processing', {}).get('table_count', 0) for doc in docs)
            total_columns = sum(doc.get('processing', {}).get('column_count', 0) for doc in docs)
            total_transformations = sum(doc.get('processing', {}).get('transformation_count', 0) for doc in docs)
            
            return {
                'total_sessions': total_sessions,
                'total_tables_processed': total_tables,
                'total_columns_normalized': total_columns,
                'total_transformations': total_transformations,
                'unique_users': len(set(doc.get('user_id') for doc in docs))
            }
            
        except Exception as e:
            print(f"Warning: Failed to retrieve statistics from Cloudant: {e}")
            return {}

# Made with Bob
