"""
Cloudant configuration management for LegacyLink AI
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class CloudantConfig:
    """Configuration for IBM Cloudant connection"""
    
    def __init__(self):
        self.url = os.getenv('CLOUDANT_URL')
        self.apikey = os.getenv('CLOUDANT_APIKEY')
        self.database_name = os.getenv('CLOUDANT_DATABASE_NAME', 'legacylink_history')
        self.enabled = os.getenv('ENABLE_HISTORY_TRACKING', 'true').lower() == 'true'
    
    def is_configured(self) -> bool:
        """Check if Cloudant is properly configured"""
        return bool(self.url and self.apikey and self.enabled)
    
    def get_connection_params(self) -> dict:
        """Get connection parameters for Cloudant client"""
        return {
            'url': self.url,
            'apikey': self.apikey
        }

# Made with Bob
