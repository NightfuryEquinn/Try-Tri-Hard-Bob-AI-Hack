# LegacyLink AI

**IBM Bob-assisted legacy SQL schema modernization into clean Python ORM codebases**

Built for the IBM Bob Hackathon by lablab.ai.

## Overview

LegacyLink AI is a lightweight modernization tool that converts messy legacy SQL schema files into clean, modern Python ORM project scaffolds. It helps developers understand old database systems faster, reduces repetitive ORM coding, and improves documentation and test readiness.

## Features

- **SQL File Upload**: Upload `.sql` or `.txt` files containing `CREATE TABLE` statements.
- **Schema Parsing**: Automatically extract tables, columns, and constraints.
- **Name Cleaning**: Convert cryptic legacy names to clean, modern conventions.
- **ORM Generation**: Generate SQLAlchemy 2.0 models with proper type hints.
- **Test Generation**: Create starter pytest test files.
- **Modernization Report**: Generate a detailed explanation of all transformations.
- **ZIP Download**: Download the complete project scaffold.
- **AI Assistant**: Use an optional IBM watsonx.ai-powered assistant to answer questions about the schema.
- **PostgreSQL Audit Logging**: Optionally log AI Assistant Q&A interactions for traceability.
- **MCP Audit Access**: Optionally expose PostgreSQL audit logs to IBM Bob through a local Model Context Protocol server.

## Quick Start

### Prerequisites

- Python 3.8 or higher
- pip package manager

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/legacylink-ai.git
cd legacylink-ai
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Run the Streamlit dashboard:

```bash
streamlit run app.py
```

4. Open your browser to `http://localhost:8501`.

## Usage

1. **Upload SQL File**: Select a legacy SQL schema file.
2. **Review Parsed Schema**: Check extracted tables and columns.
3. **Preview Generated Code**: Review generated SQLAlchemy models.
4. **Read Modernization Report**: Understand what was transformed.
5. **Ask AI Assistant**: Get optional help from IBM watsonx.ai.
6. **Download Project**: Download the generated Python ORM scaffold as a ZIP file.

## AI Assistant

LegacyLink AI includes an optional AI Assistant powered by **IBM watsonx.ai**. It can answer questions about parsed schemas, generated SQLAlchemy ORM models, legacy naming transformations, and modernization reports.

### Setup

To enable the AI Assistant, create `.streamlit/secrets.toml` with your IBM watsonx.ai credentials:

```toml
WATSONX_API_KEY = "your-api-key-here"
WATSONX_PROJECT_ID = "your-project-id-here"
WATSONX_URL = "https://us-south.ml.cloud.ibm.com"
WATSONX_MODEL_ID = "ibm/granite-4-h-small"
```

### Getting IBM watsonx.ai Credentials

1. Sign up for [IBM Cloud](https://cloud.ibm.com/).
2. Create a watsonx.ai project.
3. Generate an API key from your IBM Cloud account.
4. Copy your project ID from the watsonx.ai project settings.

### Example Questions

- "Explain this schema to a new developer"
- "Which columns look like foreign keys?"
- "What legacy naming patterns were fixed?"
- "Summarize the modernization report"
- "What should a developer review first?"

The AI Assistant uses the **ibm/granite-4-h-small** foundation model by default. This feature is completely optional; the core parser, generator, report, and ZIP download flow works without watsonx.ai credentials.

## PostgreSQL Audit Logging and MCP

LegacyLink AI includes optional PostgreSQL audit logging for AI Assistant Q&A interactions. When enabled, the app records each AI Assistant question, answer, source context, SQL filename, table count, model ID, status, and timestamp in a PostgreSQL table named `ai_assistant_logs`.

This audit log can also be exposed to IBM Bob through the **Model Context Protocol (MCP)**. MCP is part of the development and review workflow: it lets IBM Bob inspect local audit records while helping debug, explain, or review the project. MCP is not required for the Streamlit app, schema upload, code generation, ZIP download, or watsonx.ai runtime assistant.

### Audit Logging Setup

1. Create a PostgreSQL database, for example `legacylink_audit`.
2. Create the `ai_assistant_logs` table using the SQL in [docs/POSTGRES_AUDIT_LOGGING.md](docs/POSTGRES_AUDIT_LOGGING.md).
3. Add PostgreSQL settings to `.streamlit/secrets.toml`:

```toml
POSTGRES_AUDIT_ENABLED = true
POSTGRES_HOST = "localhost"
POSTGRES_PORT = "5432"
POSTGRES_DB = "legacylink_audit"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "your-secure-password"
```

If `POSTGRES_AUDIT_ENABLED` is missing or set to `false`, the app skips database logging and continues normally.

### IBM Bob MCP Configuration

The local Bob MCP configuration lives in `.bob/mcp.json` and uses the PostgreSQL MCP server:

```json
{
  "mcpServers": {
    "legacylink-postgres-audit": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://USER:PASSWORD@HOST:PORT/legacylink_audit"
      ],
      "disabled": false
    }
  }
}
```

Replace `USER`, `PASSWORD`, `HOST`, and `PORT` with your local PostgreSQL values. Keep `.bob/mcp.json` out of git because it can contain local credentials.

With MCP enabled, IBM Bob can inspect records such as recent AI Assistant questions, failed interactions, model IDs used, and context types used during schema modernization reviews.

For the full table schema, example SQL queries, and troubleshooting details, see [docs/POSTGRES_AUDIT_LOGGING.md](docs/POSTGRES_AUDIT_LOGGING.md).

## Design System

- **Font**: IBM Plex Sans and IBM Plex Mono
- **Primary Color**: `#3df2e0` (cyan/teal)
- **Background**: `#0b0f14` (dark blue-black)

## Project Structure

```text
legacylink-ai/
├── app.py
├── requirements.txt
├── examples/
│   └── legacy_customer_schema.sql
├── parser/
├── generator/
├── services/
│   ├── watsonx_client.py
│   └── audit_logger.py
├── templates/
├── tests/
└── docs/
    └── POSTGRES_AUDIT_LOGGING.md
```

## Supported SQL Features (MVP)

### Data Types

- `INT`, `INTEGER` -> `Integer`
- `VARCHAR(n)` -> `String(n)`
- `TEXT` -> `Text`
- `TIMESTAMP`, `DATETIME` -> `DateTime`
- `DATE` -> `Date`
- `BOOLEAN`, `BOOL` -> `Boolean`
- `DECIMAL`, `NUMERIC` -> `Numeric`
- `FLOAT`, `DOUBLE` -> `Float`

### Constraints

- Primary key detection
- Basic foreign key detection
- Not-null detection

## Example Transformation

### Input: Legacy SQL

```sql
CREATE TABLE tbl_CUST_MSTR_2012_v2 (
    c_id INT PRIMARY KEY,
    vch_fname VARCHAR(50),
    vch_lname VARCHAR(50),
    fk_str_id INT,
    dt_upd_dt TIMESTAMP
);
```

### Output: Modern Python

```python
class Customer(Base):
    """
    Represents cleaned customer master records.
    Migrated from legacy table: tbl_CUST_MSTR_2012_v2
    """

    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    first_name: Mapped[str] = mapped_column(String(50), nullable=True)
    last_name: Mapped[str] = mapped_column(String(50), nullable=True)
    store_id: Mapped[int] = mapped_column(Integer, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

## IBM Bob and IBM watsonx.ai

### IBM Bob: Development Partner

This project uses **IBM Bob** as the AI development partner throughout the build process:

- Understanding project structure
- Improving parsing logic
- Refactoring code generation
- Creating and improving tests
- Enhancing documentation
- Preparing final repository
- Inspecting optional PostgreSQL audit logs through MCP during development

### IBM watsonx.ai: Runtime Inference

The optional AI Assistant feature uses **IBM watsonx.ai** foundation models at runtime to:

- Answer user questions about parsed schemas
- Explain generated ORM models
- Summarize modernization reports
- Help developers understand legacy transformations

## Hackathon Alignment

LegacyLink AI addresses the IBM Bob Hackathon goals:

- **Improve software development workflow**: Automates legacy schema modernization.
- **Help developers understand existing systems**: Generates clear reports and documentation.
- **Generate documentation**: Creates README and modernization reports.
- **Generate tests**: Produces starter pytest files.
- **Reduce repetitive work**: Automates ORM model generation.
- **Use IBM Bob meaningfully**: Bob assists throughout development, including optional MCP-backed audit review.

## Future Enhancements

- ERD diagram generation
- Alembic migration file generation
- FastAPI CRUD endpoint generation
- Pydantic schema generation
- Dockerfile generation
- GitHub repository import
- Pull request generation for modernization changes
- Relationship inference from naming patterns
- Audit log dashboard and export tools

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for IBM Bob Hackathon by lablab.ai
- Powered by Streamlit and SQLAlchemy
- Font: IBM Plex by IBM

## Contact

For questions or feedback, please open an issue on GitHub.

---

**LegacyLink AI** - Making legacy database modernization faster and easier.
