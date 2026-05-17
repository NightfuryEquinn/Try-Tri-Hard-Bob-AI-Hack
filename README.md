# 🔗 LegacyLink AI

**IBM Bob-assisted legacy SQL schema modernization into clean Python ORM codebases**

Built for the IBM Bob Hackathon by lablab.ai

## 🎯 Overview

LegacyLink AI is a lightweight modernization tool that converts messy legacy SQL schema files into clean, modern Python ORM project scaffolds. It helps developers understand old database systems faster, reduces repetitive ORM coding, and improves documentation and test readiness.

## ✨ Features

- 📤 **SQL File Upload**: Upload `.sql` or `.txt` files containing CREATE TABLE statements
- 🔍 **Schema Parsing**: Automatically extract tables, columns, and constraints
- 🧹 **Name Cleaning**: Convert cryptic legacy names to clean, modern conventions
- 🐍 **ORM Generation**: Generate SQLAlchemy 2.0 models with proper type hints
- 🧪 **Test Generation**: Create starter pytest test files
- 📊 **Modernization Report**: Detailed explanation of all transformations
- 📦 **ZIP Download**: Complete project scaffold ready to use

## 🚀 Quick Start

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

4. Open your browser to `http://localhost:8501`

## 🗄️ Optional: Enable History Tracking with IBM Cloudant

LegacyLink AI can save your modernization history to IBM Cloudant NoSQL database for tracking and analytics.

> **Note**: This feature is **completely optional**. The application works perfectly without Cloudant configured.

### Quick Setup

1. **Create IBM Cloud Account** - Visit [cloud.ibm.com](https://cloud.ibm.com)
2. **Create Cloudant Service** - Use the free Lite plan
3. **Configure Environment Variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your Cloudant credentials
   ```
4. **Restart Application**:
   ```bash
   streamlit run app.py
   ```

### Features with History Tracking Enabled

When Cloudant is configured, you get:

- ✅ **Automatic Session Saving** - Every SQL modernization is saved
- ✅ **Processing History** - View all your past sessions
- ✅ **Transformation Tracking** - Detailed logs of all changes
- ✅ **Usage Analytics** - Statistics across all sessions
- ✅ **Session Replay** - Retrieve and review previous work

### Detailed Documentation

📖 **[Complete Setup Guide](docs/CLOUDANT_SETUP.md)** - Step-by-step instructions with screenshots

🔧 **[Technical Integration Guide](docs/CLOUDANT_INTEGRATION.md)** - Architecture, API reference, and development details

### Verification

Run tests to verify your Cloudant integration:
```bash
pytest tests/test_cloudant_integration.py -v
```

Expected output: `12 passed` ✅

### Privacy & Security

- User IDs are anonymous session identifiers
- No personal information is stored
- Credentials stored in `.env` (not committed to git)
- All connections use HTTPS and IAM authentication

### Cost Estimation

**IBM Cloudant Lite Plan (Free):**
- 1 GB storage
- 20 lookups/sec, 10 writes/sec
- Perfect for development and demos
- **Recommended for hackathon**

**Typical Usage:**
- Each session: ~5-50 KB
- 100 sessions/day: ~75 MB/month
- **Free tier is sufficient for most use cases**

### Troubleshooting

If you see "Could not save to history" warnings:
1. Verify credentials in `.env` file
2. Check Cloudant service status in IBM Cloud
3. Run `pytest tests/test_cloudant_integration.py` to diagnose
4. See [CLOUDANT_SETUP.md](docs/CLOUDANT_SETUP.md#troubleshooting) for detailed help

## 📖 Usage

1. **Upload SQL File**: Click the file uploader and select your legacy SQL schema file
2. **Review Parsed Schema**: Check the extracted tables and columns
3. **Preview Generated Code**: See the clean SQLAlchemy models
4. **Read Modernization Report**: Understand what was transformed
5. **Download Project**: Get your complete Python ORM scaffold as a ZIP file

## 🎨 Design System

- **Font**: IBM Plex Sans & IBM Plex Mono
- **Primary Color**: `#3df2e0` (Cyan/Teal)
- **Background**: `#0b0f14` (Dark Blue-Black)

## 📁 Project Structure

```
legacylink-ai/
├── app.py                          # Main Streamlit dashboard
├── requirements.txt                # Python dependencies
├── .env.example                    # Environment variables template
├── examples/                       # Example SQL files
│   └── legacy_customer_schema.sql
├── config/                         # Configuration modules
│   ├── __init__.py
│   └── cloudant_config.py         # Cloudant configuration
├── storage/                        # Storage modules
│   ├── __init__.py
│   └── cloudant_client.py         # Cloudant NoSQL client
├── parser/                         # SQL parsing modules
│   ├── __init__.py
│   ├── sql_parser.py
│   └── name_normalizer.py
├── generator/                      # Code generation modules
│   ├── __init__.py
│   ├── model_generator.py
│   ├── test_generator.py
│   ├── report_generator.py
│   ├── function_generator.py
│   ├── index_generator.py
│   └── zip_packager.py
├── templates/                      # Code templates
└── tests/                          # Test files
    ├── test_normalization.py
    └── test_cloudant_integration.py
```

## 🔧 Supported SQL Features (MVP)

### Data Types
- INT, INTEGER → Integer
- VARCHAR(n) → String(n)
- TEXT → Text
- TIMESTAMP, DATETIME → DateTime
- DATE → Date
- BOOLEAN, BOOL → Boolean
- DECIMAL, NUMERIC → Numeric
- FLOAT, DOUBLE → Float

### Constraints
- PRIMARY KEY detection
- FOREIGN KEY detection (basic)
- NOT NULL detection

## 🎯 Example Transformation

### Input (Legacy SQL)
```sql
CREATE TABLE tbl_CUST_MSTR_2012_v2 (
    c_id INT PRIMARY KEY,
    vch_fname VARCHAR(50),
    vch_lname VARCHAR(50),
    fk_str_id INT,
    dt_upd_dt TIMESTAMP
);
```

### Output (Modern Python)
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

## 🤖 IBM Bob Integration

This project uses IBM Bob as the AI development partner throughout the build process:

- Understanding project structure
- Improving parsing logic
- Refactoring code generation
- Creating and improving tests
- Enhancing documentation
- Preparing final repository

## 🏆 Hackathon Alignment

LegacyLink AI addresses the IBM Bob Hackathon goals:

✅ **Improve software development workflow** - Automates legacy schema modernization  
✅ **Help developers understand existing systems** - Generates clear reports and documentation  
✅ **Generate documentation** - Creates README and modernization reports  
✅ **Generate tests** - Produces starter pytest files  
✅ **Reduce repetitive work** - Automates ORM model generation  
✅ **Use IBM Bob meaningfully** - Bob assists throughout development

## 🚧 Future Enhancements

- Support for PostgreSQL, MySQL, Oracle, SQL Server dialects
- ERD diagram generation
- Alembic migration file generation
- FastAPI CRUD endpoint generation
- Pydantic schema generation
- Dockerfile generation
- GitHub repository import
- Pull request generation for modernization changes
- Relationship inference from naming patterns
- LLM-assisted business meaning explanation

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Built for IBM Bob Hackathon by lablab.ai
- Powered by Streamlit and SQLAlchemy
- Font: IBM Plex by IBM

## 📞 Contact

For questions or feedback, please open an issue on GitHub.

---

**LegacyLink AI** - Making legacy database modernization faster and easier 🚀
