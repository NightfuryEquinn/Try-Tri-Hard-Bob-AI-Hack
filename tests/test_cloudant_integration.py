"""
Tests for Cloudant integration
"""
import pytest
from unittest.mock import Mock, patch, MagicMock
from storage.cloudant_client import CloudantClient
from config.cloudant_config import CloudantConfig


def test_cloudant_config_validation():
    """Test Cloudant configuration validation"""
    config = CloudantConfig()
    
    # Should handle missing credentials gracefully
    assert isinstance(config.is_configured(), bool)


def test_cloudant_config_disabled():
    """Test Cloudant configuration when disabled"""
    with patch.dict('os.environ', {'ENABLE_HISTORY_TRACKING': 'false'}):
        config = CloudantConfig()
        assert config.enabled is False
        assert config.is_configured() is False


def test_cloudant_client_initialization_without_config():
    """Test Cloudant client initialization without configuration"""
    config = Mock()
    config.is_configured.return_value = False
    
    client = CloudantClient(config)
    assert client.client is None


@patch('storage.cloudant_client.CloudantV1')
@patch('storage.cloudant_client.IAMAuthenticator')
def test_cloudant_client_initialization_with_config(mock_auth, mock_cloudant):
    """Test Cloudant client initialization with valid configuration"""
    config = Mock()
    config.is_configured.return_value = True
    config.url = "https://test.cloudant.com"
    config.apikey = "test-key"
    config.database_name = "test-db"
    
    # Mock the Cloudant client
    mock_client_instance = MagicMock()
    mock_cloudant.return_value = mock_client_instance
    
    # Mock database check
    mock_client_instance.get_database_information.return_value.get_result.return_value = {}
    
    client = CloudantClient(config)
    
    # Verify authenticator was created
    mock_auth.assert_called_once_with("test-key")
    
    # Verify client was initialized
    mock_cloudant.assert_called_once()


@patch('storage.cloudant_client.CloudantV1')
@patch('storage.cloudant_client.IAMAuthenticator')
def test_save_modernization_session(mock_auth, mock_cloudant):
    """Test saving a modernization session"""
    config = Mock()
    config.is_configured.return_value = True
    config.url = "https://test.cloudant.com"
    config.apikey = "test-key"
    config.database_name = "test-db"
    
    # Mock the Cloudant client
    mock_client_instance = MagicMock()
    mock_cloudant.return_value = mock_client_instance
    
    # Mock database check
    mock_client_instance.get_database_information.return_value.get_result.return_value = {}
    
    # Mock successful save
    mock_client_instance.post_document.return_value.get_result.return_value = {
        'id': 'test-doc-id',
        'rev': '1-abc'
    }
    
    client = CloudantClient(config)
    
    doc_id = client.save_modernization_session(
        user_id="test-user",
        filename="test.sql",
        file_size=1024,
        tables=[{
            'original_name': 'tbl_TEST',
            'clean_name': 'Test',
            'table_name': 'tests',
            'columns': []
        }],
        transformation_log=[],
        processing_stats={
            'table_count': 1,
            'column_count': 5,
            'transformation_count': 10,
            'processing_time_ms': 500
        }
    )
    
    assert doc_id == 'test-doc-id'
    mock_client_instance.post_document.assert_called_once()


def test_save_modernization_session_without_client():
    """Test saving session without Cloudant client"""
    config = Mock()
    config.is_configured.return_value = False
    
    client = CloudantClient(config)
    
    doc_id = client.save_modernization_session(
        user_id="test",
        filename="test.sql",
        file_size=100,
        tables=[],
        transformation_log=[],
        processing_stats={}
    )
    
    assert doc_id is None


@patch('storage.cloudant_client.CloudantV1')
@patch('storage.cloudant_client.IAMAuthenticator')
def test_get_user_history(mock_auth, mock_cloudant):
    """Test retrieving user history"""
    config = Mock()
    config.is_configured.return_value = True
    config.url = "https://test.cloudant.com"
    config.apikey = "test-key"
    config.database_name = "test-db"
    
    # Mock the Cloudant client
    mock_client_instance = MagicMock()
    mock_cloudant.return_value = mock_client_instance
    
    # Mock database check
    mock_client_instance.get_database_information.return_value.get_result.return_value = {}
    
    # Mock history query
    mock_client_instance.post_find.return_value.get_result.return_value = {
        'docs': [
            {
                'user_id': 'test-user',
                'timestamp': '2026-05-17T00:00:00Z',
                'input': {'filename': 'test.sql'}
            }
        ]
    }
    
    client = CloudantClient(config)
    history = client.get_user_history("test-user", limit=10)
    
    assert len(history) == 1
    assert history[0]['user_id'] == 'test-user'


def test_get_user_history_without_client():
    """Test retrieving history without Cloudant client"""
    config = Mock()
    config.is_configured.return_value = False
    
    client = CloudantClient(config)
    history = client.get_user_history("test")
    
    assert history == []


@patch('storage.cloudant_client.CloudantV1')
@patch('storage.cloudant_client.IAMAuthenticator')
def test_get_statistics(mock_auth, mock_cloudant):
    """Test retrieving global statistics"""
    config = Mock()
    config.is_configured.return_value = True
    config.url = "https://test.cloudant.com"
    config.apikey = "test-key"
    config.database_name = "test-db"
    
    # Mock the Cloudant client
    mock_client_instance = MagicMock()
    mock_cloudant.return_value = mock_client_instance
    
    # Mock database check
    mock_client_instance.get_database_information.return_value.get_result.return_value = {}
    
    # Mock statistics query
    mock_client_instance.post_find.return_value.get_result.return_value = {
        'docs': [
            {
                'user_id': 'user1',
                'processing': {
                    'table_count': 3,
                    'column_count': 15,
                    'transformation_count': 30
                }
            },
            {
                'user_id': 'user2',
                'processing': {
                    'table_count': 2,
                    'column_count': 10,
                    'transformation_count': 20
                }
            }
        ]
    }
    
    client = CloudantClient(config)
    stats = client.get_statistics()
    
    assert stats['total_sessions'] == 2
    assert stats['total_tables_processed'] == 5
    assert stats['total_columns_normalized'] == 25
    assert stats['total_transformations'] == 50
    assert stats['unique_users'] == 2


@patch('storage.cloudant_client.CloudantV1')
@patch('storage.cloudant_client.IAMAuthenticator')
def test_get_session_by_id(mock_auth, mock_cloudant):
    """Test retrieving a specific session by ID"""
    config = Mock()
    config.is_configured.return_value = True
    config.url = "https://test.cloudant.com"
    config.apikey = "test-key"
    config.database_name = "test-db"

    mock_client_instance = MagicMock()
    mock_cloudant.return_value = mock_client_instance
    mock_client_instance.get_database_information.return_value.get_result.return_value = {}

    mock_client_instance.post_find.return_value.get_result.return_value = {
        'docs': [
            {
                'user_id': 'test-user',
                'session_id': 'abc12345',
                'timestamp': '2026-05-17T00:00:00.000000Z'
            }
        ]
    }

    client = CloudantClient(config)
    session = client.get_session_by_id("abc12345")

    assert session is not None
    assert session['session_id'] == 'abc12345'
    mock_client_instance.post_find.assert_called_once()


def test_get_session_by_id_not_found():
    """Test retrieving a session that doesn't exist returns None"""
    config = Mock()
    config.is_configured.return_value = False

    client = CloudantClient(config)
    session = client.get_session_by_id("nonexistent")

    assert session is None


def test_graceful_degradation_without_cloudant():
    """Test that app works without Cloudant configured"""
    config = CloudantConfig()
    config.enabled = False
    
    client = CloudantClient(config)
    
    # Should return None/empty without errors
    assert client.save_modernization_session(
        user_id="test",
        filename="test.sql",
        file_size=100,
        tables=[],
        transformation_log=[],
        processing_stats={}
    ) is None
    
    assert client.get_user_history("test") == []
    assert client.get_statistics() == {}

# Made with Bob
