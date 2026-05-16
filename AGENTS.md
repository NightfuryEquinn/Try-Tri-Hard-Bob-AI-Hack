# LegacyLink AI - IBM Bob Project Context

## Project Name

LegacyLink AI

## Hackathon

IBM Bob Hackathon by lablab.ai

## Current Project Status

This repository already contains a Streamlit dashboard and basic backend modules.

Current important files:

```text
app.py
parser/sql_parser.py
parser/name_normalizer.py
generator/model_generator.py
generator/test_generator.py
generator/report_generator.py
generator/zip_packager.py
examples/legacy_customer_schema.sql
README.md
DATASET.md
PROJECT.md
IMPLEMENTATION_PLAN.md
requirements.txt
```

Do not restart the whole project.

The full-stack developer has already created the UI and basic app flow. AI Engineer 1 should focus on backend correctness.

---

## Project Goal

LegacyLink AI is a 48-hour hackathon proof-of-concept that converts messy legacy SQL schema files into clean Python ORM project scaffolds.

The user uploads a `.sql`, `.ddl`, or `.txt` file containing SQL `CREATE TABLE` statements.

The system should:

1. Parse SQL schema.
2. Extract tables, columns, data types, primary keys, and basic foreign key patterns.
3. Clean legacy table and column names.
4. Generate SQLAlchemy 2.0 ORM models.
5. Generate starter pytest tests.
6. Generate README documentation.
7. Generate a modernization report.
8. Package everything into a downloadable ZIP file.

---

## Important Clarification About IBM Bob

IBM Bob is used as the AI development partner.

Bob helps with:

- Understanding repository context
- Planning implementation
- Refactoring code
- Improving parser and generator modules
- Generating tests
- Reviewing code quality
- Improving documentation
- Creating useful commit messages
- Exporting Bob session reports for judging

IBM Bob should not be described as a hidden backend runtime model unless official runtime integration is actually implemented.

Use this wording:

```text
IBM Bob-assisted development workflow
```

Avoid this wording:

```text
IBM Bob model loaded
IBM Bob runtime engine
Bob backend model
```

---

## Data Used

This project uses SQL schema files as input data.

The project does not use:

- Company confidential data
- Client data
- Personal information
- Social media data
- Real production database records

Demo data:

```text
examples/legacy_customer_schema.sql
```

This is a synthetic legacy-style SQL schema created for demonstration.

Optional public datasets for future testing:

- Chinook database schema
- Employee sample database schema
- Sakila or Pagila schema

For the 48-hour MVP, schema-only files are enough. Do not use row-level personal data.

---

## Model and AI Approach

This project does not train a machine learning model.

The word "model" in this project mainly means:

```text
SQLAlchemy ORM model
```

The MVP uses deterministic software engineering methods:

1. Regex-based SQL parser
2. Rule-based name normalizer
3. SQL type mapper
4. Python template-based SQLAlchemy generator
5. Python template-based pytest generator
6. Markdown report generator
7. ZIP packager

watsonx.ai is optional and not required for this MVP.

PostgreSQL is not required for this MVP.

SQLite or no live database is enough for testing generated SQLAlchemy models.

---

## AI Engineer 1 Task Focus

AI Engineer 1 should focus on these files:

```text
parser/sql_parser.py
parser/name_normalizer.py
generator/model_generator.py
generator/test_generator.py
generator/report_generator.py
requirements.txt
```

Do not redesign the Streamlit UI unless a backend change requires it.

---

## Implementation Status - ✅ ALL FIXES COMPLETED

### 1. ✅ Fix Base import in generated models.py - COMPLETED

**Status:** Fixed in `generator/model_generator.py`

Generated `models.py` now correctly includes:

```python
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, Text, DateTime, Date, Boolean, Numeric, Float
from database import Base
```

The generated model classes properly use:

```python
class Customer(Base):
```

No duplicate `Base` definition in `models.py`.

---

### 2. ✅ Fix foreign key column normalization - COMPLETED

**Status:** Fixed in `parser/name_normalizer.py`

Correct behavior now implemented:

```text
fk_str_id -> store_id ✓
fk_cust_id -> customer_id ✓
```

The normalizer removes the `fk_` prefix first, then expands abbreviations:

```text
fk_str_id -> str_id -> store_id ✓
fk_cust_id -> cust_id -> customer_id ✓
```

---

### 3. ✅ Fix timestamp normalization - COMPLETED

**Status:** Fixed in `parser/name_normalizer.py`

Explicit special-case mappings now implemented:

```text
dt_upd_dt -> updated_at ✓
dt_crt_dt -> created_at ✓
dt_ord_dt -> ordered_at ✓
```

Special cases are handled before generic prefix removal.

---

### 4. ✅ Prevent duplicate column names - COMPLETED

**Status:** Fixed in `parser/name_normalizer.py` and `app.py`

- Added `used_column_names` set to track names per table
- Added `reset_column_context()` method
- Updated `app.py` to call `reset_column_context()` before processing each table's columns

Result: Each table can have its own `id` column without conflicts:

```text
Customer.c_id -> id ✓
Store.str_id -> id ✓
OrderDetail.ord_id -> id ✓
```

No duplicate column names within the same table.

---

### 5. ✅ Update requirements.txt - COMPLETED

**Status:** Updated

Root `requirements.txt` now includes:

```text
streamlit>=1.28.0
pandas>=2.0.0
sqlalchemy>=2.0.0
pytest>=7.0.0
```

---

### 6. ✅ Update IBM Bob Wording - COMPLETED

**Status:** Updated in `app.py`

Changed from:
- `IBM_BOB_MODEL_LOADED` → `IBM_BOB_ASSISTED_WORKFLOW_READY`
- `IBM_BOB_MODEL: ONLINE` → `IBM_BOB_ASSISTED_DEVELOPMENT: ENABLED`

Correctly reflects IBM Bob as an assisted development tool, not a runtime model.

---

## Expected Input Example

```sql
CREATE TABLE tbl_CUST_MSTR_2012_v2 (
    c_id INT PRIMARY KEY,
    vch_fname VARCHAR(50),
    vch_lname VARCHAR(50),
    vch_email VARCHAR(100),
    fk_str_id INT,
    dt_upd_dt TIMESTAMP,
    dt_crt_dt TIMESTAMP,
    int_status INT
);

CREATE TABLE tbl_STR_MSTR (
    str_id INT PRIMARY KEY,
    vch_str_name VARCHAR(100),
    vch_addr VARCHAR(200),
    vch_city VARCHAR(50),
    vch_state VARCHAR(2),
    vch_zip VARCHAR(10)
);

CREATE TABLE tbl_ORD_DTL_2015 (
    ord_id INT PRIMARY KEY,
    fk_cust_id INT,
    fk_str_id INT,
    dec_amt DECIMAL(10,2),
    int_qty INT,
    dt_ord_dt TIMESTAMP
);
```

---

## Expected Clean Names

### Table names

```text
tbl_CUST_MSTR_2012_v2 -> Customer
tbl_STR_MSTR -> Store
tbl_ORD_DTL_2015 -> OrderDetail
```

### Column names

```text
c_id -> id
vch_fname -> first_name
vch_lname -> last_name
vch_email -> email
fk_str_id -> store_id
fk_cust_id -> customer_id
dt_upd_dt -> updated_at
dt_crt_dt -> created_at
dt_ord_dt -> ordered_at
int_status -> status
dec_amt -> amount
int_qty -> quantity
```

---

## Generated ZIP Content

The app should generate a ZIP containing:

```text
generated_project/
├── models.py
├── database.py
├── test_models.py
├── README.md
├── modernization_report.md
└── requirements.txt
```

---

## Expected Generated models.py Pattern

```python
from datetime import datetime
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import Integer, String, Text, DateTime, Date, Boolean, Numeric, Float
from database import Base

class Customer(Base):
    """
    Represents customer records.
    Migrated from legacy table: tbl_CUST_MSTR_2012_v2
    """

    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    first_name: Mapped[str] = mapped_column(String(50))
    last_name: Mapped[str] = mapped_column(String(50))
    email: Mapped[str] = mapped_column(String(100))
    store_id: Mapped[int] = mapped_column(Integer, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    status: Mapped[int] = mapped_column(Integer)
```

---

## Do Not Build Now

Do not add:

- PostgreSQL
- PostgreSQL MCP
- watsonx.ai runtime
- Live database connection
- Docker
- Authentication
- Full SQL dialect support
- Stored procedure migration
- Trigger migration
- View migration
- Full ERD diagram generation

Keep the MVP simple and demo-ready.

---

## Coding Rules

- Keep code simple.
- Keep functions small.
- Do not overengineer.
- Do not rewrite the whole UI.
- Add docstrings for important functions.
- Add tests for parser and normalizer.
- Make generated code importable.
- Make generated pytest tests runnable.

---

## Final Demo Checklist

Before submission, confirm:

```text
[x] Streamlit app runs
[x] SQL file upload works
[x] Example SQL parses correctly
[x] Clean table names look correct
[x] Clean column names look correct
[x] Generated models.py imports Base correctly
[x] No duplicate column names
[x] Generated test_models.py runs with pytest
[x] ZIP download works
[x] README is updated
[x] modernization_report.md is generated
[ ] bob_sessions folder exists
[ ] Bob session markdown exports are added
[ ] Bob session screenshots are added
[x] No API keys or credentials are committed
```

**Implementation Status:** ✅ All core functionality completed and tested.

**Remaining Tasks for Submission:**
- Export Bob session reports to `bob_sessions/` folder
- Add screenshots of Bob task consumption summaries

---

## Submission Reminder

Before final submission:

- Use Bob IDE for project work.
- Export relevant Bob task session reports.
- Take screenshots of Bob task session consumption summaries.
- Put exported markdown files and screenshots into `bob_sessions/`.
- Do not commit credentials, API keys, or private data.

## IBM watsonx.ai AI Assistant

Add these instructions:

LegacyLink AI may include an optional AI Assistant powered by IBM watsonx.ai.

The assistant is not a trained custom model. It uses the selected watsonx.ai foundation model at runtime to answer user questions using the current generated project context.

The assistant should be able to:
- answer questions about parsed schema tables and columns
- explain generated SQLAlchemy ORM models
- explain legacy naming changes
- summarize the generated modernization report when the user asks

Important:
- Do not call this an IBM Bob runtime chatbot.
- IBM Bob is the development partner inside Bob IDE.
- IBM watsonx.ai is the optional runtime inference provider.
- Do not train or fine-tune any model.
- Do not create a separate summarization model.
- Use ibm/granite-4-h-small as the default model because it is marked Ready to use.
- Do not use models marked Not yet deployed.
- Do not hardcode API keys.
- Use Streamlit st.secrets only.
- Do not use .env or python-dotenv unless really necessary.
- The app must still work if watsonx.ai credentials are missing.

Required local secrets:

WATSONX_API_KEY
WATSONX_PROJECT_ID
WATSONX_URL
WATSONX_MODEL_ID

Do not commit:
- .streamlit/secrets.toml
- .env
- API keys
- IBM Cloud credentials

Do not rewrite the Streamlit UI.
Do not change assets or DESIGN.md.
Do not break the existing upload → generated ZIP → pytest flow.

After updating AGENTS.md, summarize the exact section added.