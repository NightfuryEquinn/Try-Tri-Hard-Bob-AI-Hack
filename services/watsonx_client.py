"""
IBM watsonx.ai Client for LegacyLink AI
Handles communication with IBM watsonx.ai foundation models
"""

import streamlit as st
from typing import Optional, Dict


def get_watsonx_credentials() -> Optional[Dict[str, str]]:
    """
    Get watsonx.ai credentials from Streamlit secrets.
    
    Returns:
        Dictionary with credentials or None if missing
    """
    try:
        api_key = st.secrets.get("WATSONX_API_KEY")
        project_id = st.secrets.get("WATSONX_PROJECT_ID")
        url = st.secrets.get("WATSONX_URL", "https://us-south.ml.cloud.ibm.com")
        model_id = st.secrets.get("WATSONX_MODEL_ID", "ibm/granite-4-h-small")
        
        if not api_key or not project_id:
            return None
            
        return {
            "api_key": api_key,
            "project_id": project_id,
            "url": url,
            "model_id": model_id
        }
    except Exception:
        return None


def ask_watsonx(prompt: str, context: str = "") -> str:
    """
    Send a prompt to IBM watsonx.ai and get a response.
    
    Args:
        prompt: User's question
        context: Additional context to include in the prompt
        
    Returns:
        Model response or error message
    """
    # Check credentials
    credentials = get_watsonx_credentials()
    if not credentials:
        return "⚠️ **IBM watsonx.ai credentials not configured.**\n\nTo use the AI Assistant, add the following to `.streamlit/secrets.toml`:\n```toml\nWATSONX_API_KEY = \"your-api-key\"\nWATSONX_PROJECT_ID = \"your-project-id\"\nWATSONX_URL = \"https://us-south.ml.cloud.ibm.com\"\nWATSONX_MODEL_ID = \"ibm/granite-4-h-small\"\n```"
    
    # Try to import IBM SDK
    try:
        from ibm_watsonx_ai import Credentials
        from ibm_watsonx_ai.foundation_models import ModelInference
    except ImportError:
        return "⚠️ **IBM watsonx.ai SDK not installed.**\n\nPlease install it:\n```bash\npip install ibm-watsonx-ai>=1.1.0\n```"
    
    try:
        # Initialize credentials
        creds = Credentials(
            api_key=credentials["api_key"],
            url=credentials["url"]
        )
        
        # Initialize model with Chat API parameters
        model = ModelInference(
            model_id=credentials["model_id"],
            credentials=creds,
            project_id=credentials["project_id"],
            params={
                "max_tokens": 500,
                "temperature": 0.2,
                "top_p": 0.9
            }
        )
        
        # Build system message with context
        system_message = """You are a helpful assistant for legacy SQL modernization. Use only the provided context to answer questions. Do not invent tables or columns.

Answer in simple English using 5-8 bullet points maximum unless the user specifically asks for detailed explanation. Be concise and direct."""
        
        if context:
            system_message += f"\n\nContext:\n{context}"
        
        # Build messages for Chat API
        messages = [
            {"role": "system", "content": system_message},
            {"role": "user", "content": prompt}
        ]
        
        # Use Chat API instead of deprecated text generation
        response = model.chat(messages=messages)
        
        # Extract the response content
        if response and "choices" in response and len(response["choices"]) > 0:
            message_content = response["choices"][0]["message"]["content"]
            return message_content
        else:
            return "⚠️ **Unexpected response format from IBM watsonx.ai.**\n\nPlease try again or check your configuration."
        
    except Exception as e:
        error_msg = str(e)
        return f"⚠️ **Error calling IBM watsonx.ai:**\n\n{error_msg}\n\nPlease check your credentials and try again."


def build_schema_context(tables: list) -> str:
    """
    Build context from parsed schema tables.
    
    Args:
        tables: List of parsed table dictionaries
        
    Returns:
        Formatted context string
    """
    if not tables:
        return ""
    
    context = "## Parsed Schema\n\n"
    
    for table in tables:
        context += f"### Table: {table['clean_name']}\n"
        context += f"- **Original Name:** `{table['original_name']}`\n"
        context += f"- **Database Table:** `{table['table_name']}`\n"
        context += f"- **Columns:** {len(table['columns'])}\n\n"
        
        context += "**Columns:**\n"
        for col in table['columns']:
            pk_marker = " (PRIMARY KEY)" if col.get('primary_key') else ""
            fk_marker = " (likely FK)" if col['clean_name'].endswith('_id') and not col.get('primary_key') else ""
            context += f"- `{col['clean_name']}` ({col['type']}){pk_marker}{fk_marker}\n"
            context += f"  - Original: `{col['original_name']}`\n"
        
        context += "\n"
    
    return context


def build_transformation_context(transformation_log: list) -> str:
    """
    Build context from transformation log.
    
    Args:
        transformation_log: List of transformation records
        
    Returns:
        Formatted context string
    """
    if not transformation_log:
        return ""
    
    context = "## Naming Transformations Applied\n\n"
    
    # Group by type
    table_transforms = [t for t in transformation_log if t['type'] == 'Table']
    column_transforms = [t for t in transformation_log if t['type'] == 'Column']
    
    if table_transforms:
        context += "**Table Name Transformations:**\n"
        for t in table_transforms[:5]:  # Show first 5
            context += f"- `{t['original']}` → `{t['normalized']}`: {t['change']}\n"
        if len(table_transforms) > 5:
            context += f"- ... and {len(table_transforms) - 5} more\n"
        context += "\n"
    
    if column_transforms:
        context += "**Column Name Transformations:**\n"
        for t in column_transforms[:10]:  # Show first 10
            context += f"- `{t['original']}` → `{t['normalized']}`: {t['change']}\n"
        if len(column_transforms) > 10:
            context += f"- ... and {len(column_transforms) - 10} more\n"
        context += "\n"
    
    return context


def build_models_context(models_code: str) -> str:
    """
    Build context from generated models.py.
    
    Args:
        models_code: Generated SQLAlchemy models code
        
    Returns:
        Formatted context string (truncated if too long)
    """
    if not models_code:
        return ""
    
    # Truncate if too long (keep first 2000 chars)
    if len(models_code) > 2000:
        models_code = models_code[:2000] + "\n... (truncated)"
    
    context = "## Generated SQLAlchemy Models\n\n"
    context += "```python\n"
    context += models_code
    context += "\n```\n\n"
    
    return context


def build_report_context(report_content: str) -> str:
    """
    Build context from modernization report.
    
    Args:
        report_content: Generated modernization report markdown
        
    Returns:
        Formatted context string (truncated if too long)
    """
    if not report_content:
        return ""
    
    # Truncate if too long (keep first 3000 chars)
    if len(report_content) > 3000:
        report_content = report_content[:3000] + "\n... (truncated)"
    
    context = "## Modernization Report\n\n"
    context += report_content
    context += "\n\n"
    
    return context

# Made with Bob
