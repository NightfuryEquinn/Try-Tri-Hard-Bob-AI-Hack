"""
PostgreSQL Audit Logger for LegacyLink AI
Logs AI Assistant Q&A interactions to PostgreSQL database
"""

import streamlit as st
from typing import Tuple
from datetime import datetime


def log_ai_assistant_interaction(
    question: str,
    answer: str,
    source_context: str = "schema",
    sql_filename: str = "",
    table_count: int = 0,
    model_id: str = "",
    status: str = "success"
) -> Tuple[bool, str]:
    """
    Log AI Assistant interaction to PostgreSQL database.
    
    Args:
        question: User's question
        answer: AI Assistant's answer
        source_context: Type of context used (schema, models, report, etc.)
        sql_filename: Original SQL filename if available
        table_count: Number of tables parsed
        model_id: watsonx.ai model ID used
        status: Interaction status (success, error)
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    
    # Check if PostgreSQL audit logging is enabled
    try:
        audit_enabled = st.secrets.get("POSTGRES_AUDIT_ENABLED", False)
        if not audit_enabled:
            return (True, "PostgreSQL audit logging is disabled")
    except Exception:
        return (True, "PostgreSQL audit logging is disabled")
    
    # Get PostgreSQL credentials from secrets
    try:
        pg_host = st.secrets.get("POSTGRES_HOST")
        pg_port = st.secrets.get("POSTGRES_PORT", "5432")
        pg_db = st.secrets.get("POSTGRES_DB")
        pg_user = st.secrets.get("POSTGRES_USER")
        pg_password = st.secrets.get("POSTGRES_PASSWORD")
        
        if not all([pg_host, pg_db, pg_user, pg_password]):
            return (True, "PostgreSQL credentials not configured")
    except Exception:
        return (True, "PostgreSQL credentials not configured")
    
    # Try to import psycopg2
    try:
        import psycopg2
        from psycopg2 import sql
    except ImportError:
        return (False, "psycopg2 not installed. Run: pip install psycopg2-binary")
    
    # Attempt to log to database
    conn = None
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=pg_host,
            port=pg_port,
            database=pg_db,
            user=pg_user,
            password=pg_password,
            connect_timeout=5
        )
        
        cursor = conn.cursor()
        
        # Insert audit log
        insert_query = """
            INSERT INTO ai_assistant_logs 
            (question, answer, source_context, sql_filename, table_count, model_id, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(
            insert_query,
            (
                question,
                answer,
                source_context,
                sql_filename if sql_filename else None,
                table_count if table_count > 0 else None,
                model_id if model_id else None,
                status,
                datetime.utcnow()
            )
        )
        
        conn.commit()
        cursor.close()
        
        return (True, "Audit log saved to PostgreSQL")
        
    except psycopg2.OperationalError as e:
        return (False, f"PostgreSQL connection failed: {str(e)}")
    except psycopg2.Error as e:
        return (False, f"PostgreSQL error: {str(e)}")
    except Exception as e:
        return (False, f"Unexpected error logging to PostgreSQL: {str(e)}")
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def get_postgres_status() -> dict:
    """
    Check PostgreSQL audit logging status.
    
    Returns:
        Dictionary with status information
    """
    status = {
        "enabled": False,
        "configured": False,
        "message": ""
    }
    
    try:
        audit_enabled = st.secrets.get("POSTGRES_AUDIT_ENABLED", False)
        status["enabled"] = audit_enabled
        
        if not audit_enabled:
            status["message"] = "PostgreSQL audit logging is disabled"
            return status
        
        # Check if credentials are configured
        pg_host = st.secrets.get("POSTGRES_HOST")
        pg_db = st.secrets.get("POSTGRES_DB")
        pg_user = st.secrets.get("POSTGRES_USER")
        pg_password = st.secrets.get("POSTGRES_PASSWORD")
        
        if all([pg_host, pg_db, pg_user, pg_password]):
            status["configured"] = True
            status["message"] = "PostgreSQL audit logging is enabled and configured"
        else:
            status["message"] = "PostgreSQL credentials not fully configured"
            
    except Exception:
        status["message"] = "PostgreSQL audit logging is disabled"
    
    return status


# Made with Bob