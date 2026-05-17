# **Hackathon Project Proposal**

## **Event**

IBM Bob Hackathon by lablab.ai

## **Project Name**

# **LegacyLink AI**

## **Tagline**

**IBM Bob-assisted legacy SQL schema modernization into clean Python ORM codebases.**

---

# **1\. Executive Summary**

Many companies still depend on old relational databases that were created years ago. These databases often contain messy table names, unclear column names, missing documentation, weak relationship definitions, and no proper test coverage. When new developers join a project, they may spend days or weeks trying to understand what each table means before they can safely write code.

**LegacyLink AI** solves this problem by helping developers convert messy legacy SQL schema files into a clean, modern, and developer-friendly Python ORM project scaffold.

The user uploads a .sql file containing database schema definitions. The system parses the SQL, extracts tables and columns, cleans legacy names, generates SQLAlchemy ORM models, creates starter pytest test files, and produces a modernization report explaining how the old schema was transformed.

IBM Bob is used as the team’s AI development partner throughout the project. Bob helps the team understand the codebase, improve the parser, refactor the generator, create tests, improve documentation, and produce a clean developer workflow. This directly matches the hackathon goal of using IBM Bob to improve how software is built, reduce repetitive work, generate documentation and tests, and help developers work faster with real codebase context. ([LabLab](https://lablab.ai/ai-hackathons/ibm-bob-hackathon))

---

# **2\. Problem Statement**

Legacy database systems are difficult to maintain because the schema is often poorly documented and hard to understand.

Common problems include:

| Problem | Example |
| ----- | ----- |
| Cryptic table names | tbl\_CUST\_MSTR\_2012\_v2 |
| Short column names | vch\_fname, dt\_upd\_dt, fk\_str\_id |
| Missing documentation | No explanation of what each table stores |
| Inconsistent naming | Different naming styles across tables |
| Missing tests | Generated database models are not verified |
| Slow onboarding | New developers need time to understand old systems |

This creates real engineering cost. Developers waste time reading old SQL files, guessing business meaning, manually writing ORM classes, and creating basic tests.

---

# **3\. Proposed Solution**

## **LegacyLink AI**

LegacyLink AI is a lightweight modernization tool that turns raw SQL schema files into a clean Python ORM starter project.

The system takes this kind of legacy SQL input:

CREATE TABLE tbl\_CUST\_MSTR\_2012\_v2 (  
    c\_id INT PRIMARY KEY,  
    vch\_fname VARCHAR(50),  
    vch\_lname VARCHAR(50),  
    fk\_str\_id INT,  
    dt\_upd\_dt TIMESTAMP  
);

And generates a modern Python project like this:

from sqlalchemy.orm import Mapped, mapped\_column  
from sqlalchemy import Integer, String, DateTime  
from datetime import datetime  
from database import Base

class Customer(Base):  
    """  
    Represents cleaned customer master records.  
    Migrated from legacy table: tbl\_CUST\_MSTR\_2012\_v2  
    """

    \_\_tablename\_\_ \= "customers"

    id: Mapped\[int\] \= mapped\_column(Integer, primary\_key=True)  
    first\_name: Mapped\[str\] \= mapped\_column(String(50), nullable=True)  
    last\_name: Mapped\[str\] \= mapped\_column(String(50), nullable=True)  
    store\_id: Mapped\[int\] \= mapped\_column(Integer, index=True)  
    updated\_at: Mapped\[datetime\] \= mapped\_column(DateTime, default=datetime.utcnow)

The generated output is packaged into a downloadable .zip file containing:

generated\_project/  
├── models.py  
├── database.py  
├── test\_models.py  
├── README.md  
├── modernization\_report.md  
└── requirements.txt

---

# **4\. Why This Idea Fits the IBM Bob Hackathon**

The IBM Bob Hackathon challenge asks participants to build solutions that improve how software is built. The hackathon page gives examples such as helping developers get up to speed on existing code quickly, generating documentation and tests, and reducing repetitive tasks. ([LabLab](https://lablab.ai/ai-hackathons/ibm-bob-hackathon))

LegacyLink AI fits this because it:

| Hackathon Goal | How LegacyLink AI Matches |
| ----- | ----- |
| **Improve software development workflow** | Converts legacy SQL into modern Python project scaffolds |
| **Help developers understand existing systems** | Produces modernization reports and cleaned schema explanations |
| **Generate documentation** | Creates README and table-level explanation |
| **Generate tests** | Creates starter pytest files |
| **Reduce repetitive coding work** | Automates ORM model generation |
| **Use IBM Bob meaningfully** | Bob assists in code understanding, refactoring, documentation, and test generation |

---

# **5\. Target Users**

The target users are:

1. **Enterprise backend developers**  
   Developers who need to maintain old database-backed systems.  
2. **Software modernization teams**  
   Teams migrating legacy systems to modern Python services.  
3. **New developers joining existing projects**  
   Developers who need to understand old database schemas quickly.  
4. **Technical leads**  
   Leads who want a fast overview of database structure and modernization risk.

---

# **6\. System Input**

The system accepts uploaded .sql or .txt files.

## **Supported MVP Input**

For the 48-hour version, the system will support common SQL DDL patterns:

CREATE TABLE table\_name (  
    column\_name DATA\_TYPE PRIMARY KEY,  
    column\_name DATA\_TYPE,  
    FOREIGN KEY (column\_name) REFERENCES other\_table(id)  
);

## **Supported Data Types**

| SQL Type | Python / SQLAlchemy Type |
| ----- | ----- |
| INT, INTEGER | Integer |
| VARCHAR(n) | String(n) |
| TEXT | Text |
| TIMESTAMP, DATETIME | DateTime |
| DATE | Date |
| BOOLEAN, BOOL | Boolean |
| DECIMAL, NUMERIC | Numeric |
| FLOAT, DOUBLE | Float |

---

# **7\. System Output**

The system outputs a downloadable .zip file.

## **Generated Files**

### **1\. models.py**

Contains generated SQLAlchemy 2.0 ORM models.

### **2\. database.py**

Contains the base SQLAlchemy setup.

Example:

from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):  
    pass

### **3\. test\_models.py**

Contains starter pytest tests.

Example tests:

def test\_customer\_table\_name():  
    assert Customer.\_\_tablename\_\_ \== "customers"

def test\_customer\_has\_primary\_key():  
    assert "id" in Customer.\_\_table\_\_.columns

def test\_customer\_has\_expected\_columns():  
    expected\_columns \= \["id", "first\_name", "last\_name", "store\_id", "updated\_at"\]  
    actual\_columns \= \[column.name for column in Customer.\_\_table\_\_.columns\]  
    for column in expected\_columns:  
        assert column in actual\_columns

### **4\. README.md**

Explains how to install and run the generated project.

### **5\. modernization\_report.md**

Explains what was transformed.

Example:

Original table:  
tbl\_CUST\_MSTR\_2012\_v2

Generated model:  
Customer

Detected legacy naming patterns:  
\- Removed prefix: tbl\_  
\- Removed version suffix: 2012\_v2  
\- Expanded abbreviation: CUST → Customer  
\- Expanded abbreviation: MSTR → Master  
\- Renamed c\_id → id  
\- Renamed vch\_fname → first\_name  
\- Renamed vch\_lname → last\_name  
\- Renamed dt\_upd\_dt → updated\_at

Generated files:  
\- models.py  
\- database.py  
\- test\_models.py  
\- README.md  
\- requirements.txt

### **6\. requirements.txt**

Contains dependencies:

sqlalchemy  
pytest

---

# **8\. Core Features for 48-Hour MVP**

## **MVP Feature 1: SQL File Upload**

The user uploads a .sql file through a Streamlit dashboard.

## **MVP Feature 2: SQL Parser**

The backend extracts:

| Extracted Item | Example |
| ----- | ----- |
| Table name | tbl\_CUST\_MSTR\_2012\_v2 |
| Column name | vch\_fname |
| SQL data type | VARCHAR(50) |
| Primary key | c\_id INT PRIMARY KEY |
| Foreign key | fk\_str\_id |
| Nullable status | Basic detection |

## **MVP Feature 3: Legacy Name Normalizer**

The system converts legacy names into clean names.

Example:

| Legacy Name | Clean Name |
| ----- | ----- |
| tbl\_CUST\_MSTR\_2012\_v2 | Customer |
| c\_id | id |
| vch\_fname | first\_name |
| vch\_lname | last\_name |
| dt\_upd\_dt | updated\_at |
| fk\_str\_id | store\_id |

## **MVP Feature 4: SQLAlchemy Model Generator**

The system generates modern SQLAlchemy model classes.

## **MVP Feature 5: Pytest Generator**

The system creates basic tests to check that the generated models are valid.

## **MVP Feature 6: Modernization Report Generator**

The system explains what was changed and why.

## **MVP Feature 7: Downloadable ZIP**

The user downloads the generated Python project as a .zip file.

---

# **9\. Role of IBM Bob**

IBM Bob will be used as the AI development partner, not falsely claimed as a hidden backend model unless official runtime API access is available.

## **How IBM Bob Supports the Project**

IBM Bob will be used to:

1. Understand the project repository structure.  
2. Refactor the SQL parser into clean modules.  
3. Improve the SQLAlchemy code generation templates.  
4. Generate and improve pytest test cases.  
5. Improve README documentation.  
6. Review the modernization report format.  
7. Help debug edge cases in SQL parsing.  
8. Suggest cleaner naming rules for legacy schemas.  
9. Help prepare final repository documentation.  
10. Export the IBM Bob report for hackathon submission.

This is important because the hackathon requires submissions to clearly demonstrate meaningful use of IBM Bob, and the GitHub repository should include the exported IBM Bob report. ([LabLab](https://lablab.ai/ai-hackathons/ibm-bob-hackathon))

---

# **10\. System Architecture**

User uploads .sql file  
        ↓  
Streamlit frontend reads file  
        ↓  
SQL parsing layer extracts schema metadata  
        ↓  
Name normalizer cleans table and column names  
        ↓  
Code generator creates SQLAlchemy models  
        ↓  
Test generator creates pytest files  
        ↓  
Report generator creates modernization report  
        ↓  
ZIP builder packages generated project  
        ↓  
User downloads modern Python ORM scaffold

---

# **11\. Technical Stack**

| Component | Technology |
| ----- | ----- |
| Frontend | Streamlit |
| Backend | Python |
| SQL parsing | Regex-based parser for MVP, optional sqlglot |
| ORM generation | SQLAlchemy 2.0 templates |
| Test generation | pytest templates |
| File packaging | Python zipfile |
| Deployment | Streamlit Cloud |
| Version control | GitHub |
| AI development partner | IBM Bob |

## **Why Streamlit?**

Streamlit is chosen because it is fast to build, easy to deploy, and suitable for a 48-hour hackathon. It allows the team to focus on the core AI/software engineering workflow instead of spending too much time on frontend complexity.

---

# **12\. Feasibility Within 48 Hours**

This project is feasible because the MVP is controlled and does not require live enterprise database access.

## **What We Will Build**

We will build:

✅ SQL file upload  
✅ Basic SQL CREATE TABLE parser  
✅ Legacy table and column name cleaner  
✅ SQLAlchemy model generator  
✅ pytest file generator  
✅ README generator  
✅ modernization report generator  
✅ downloadable ZIP output  
✅ deployed Streamlit demo  
✅ public GitHub repo  
✅ IBM Bob usage report

## **What We Will Not Build in 48 Hours**

To keep the scope realistic, we will not build:

❌ Live database connection  
❌ Full support for every SQL dialect  
❌ Complex stored procedure migration  
❌ Full production migration engine  
❌ Automatic data migration  
❌ Enterprise authentication  
❌ Full ERD visualizer

These can be described as future work.

---

# **13\. 48-Hour Development Plan**

## **Hour 0 to 4: Project Setup**

| Task | Owner |
| ----- | ----- |
| Create GitHub repo | Full-stack developer |
| Set up Streamlit app | Full-stack developer |
| Create folder structure | Full-stack developer |
| Use IBM Bob to review project structure | All team members |

Expected output:

legacylink-ai/  
├── app.py  
├── parser/  
├── generator/  
├── templates/  
├── examples/  
├── tests/  
└── README.md

---

## **Hour 4 to 12: SQL Parser MVP**

| Task | Owner |
| ----- | ----- |
| Parse CREATE TABLE blocks | AI Engineer 1 |
| Extract table names | AI Engineer 1 |
| Extract column names and SQL types | AI Engineer 1 |
| Detect primary keys | AI Engineer 1 |
| Test parser with sample SQL files | AI Engineer 2 |

Expected output:

{  
  "tables": \[  
    {  
      "original\_name": "tbl\_CUST\_MSTR\_2012\_v2",  
      "columns": \[  
        {  
          "original\_name": "c\_id",  
          "type": "INT",  
          "primary\_key": true  
        }  
      \]  
    }  
  \]  
}

---

## **Hour 12 to 20: Name Normalizer and Code Generator**

| Task | Owner |
| ----- | ----- |
| Build abbreviation dictionary | AI Engineer 2 |
| Convert table names to class names | AI Engineer 2 |
| Convert column names to clean names | AI Engineer 2 |
| Map SQL types to SQLAlchemy types | AI Engineer 1 |
| Generate models.py | AI Engineer 1 |

Example abbreviation rules:

| Abbreviation | Meaning |
| ----- | ----- |
| cust | customer |
| mstr | master |
| fname | first\_name |
| lname | last\_name |
| dt | date |
| upd | updated |
| str | store |
| addr | address |
| amt | amount |
| qty | quantity |

---

## **Hour 20 to 28: Test and Report Generator**

| Task | Owner |
| ----- | ----- |
| Generate test\_models.py | AI Engineer 1 |
| Generate README.md | AI Engineer 2 |
| Generate modernization\_report.md | AI Engineer 2 |
| Use IBM Bob to improve tests and documentation | All team members |

Expected output:

Generated files:  
\- models.py  
\- database.py  
\- test\_models.py  
\- README.md  
\- modernization\_report.md  
\- requirements.txt

---

## **Hour 28 to 36: Streamlit UI and ZIP Download**

| Task | Owner |
| ----- | ----- |
| Build upload interface | Full-stack developer |
| Show parsed schema preview | Full-stack developer |
| Show generated model preview | Full-stack developer |
| Create ZIP download button | Full-stack developer |
| Add example SQL files | Full-stack developer |

UI sections:

1\. Upload SQL File  
2\. Parsed Schema Preview  
3\. Generated ORM Preview  
4\. Modernization Report Preview  
5\. Download ZIP

---

## **Hour 36 to 42: Testing and Deployment**

| Task | Owner |
| ----- | ----- |
| Test with 3 sample SQL files | All team members |
| Fix parsing bugs | AI Engineers |
| Deploy to Streamlit Cloud | Full-stack developer |
| Finalize GitHub README | Full-stack developer |
| Export IBM Bob report | All team members |

---

## **Hour 42 to 48: Submission Materials**

| Task | Owner |
| ----- | ----- |
| Record demo video | Full-stack developer |
| Prepare slide deck | AI Engineer 1 |
| Write final project description | AI Engineer 2 |
| Check GitHub repo is public | Full-stack developer |
| Add IBM Bob exported report | Full-stack developer |
| Submit application URL | Team lead |

---

# **14\. Team Responsibilities**

## **Full-Stack Developer**

Responsible for:

\- Streamlit dashboard  
\- File upload  
\- Code preview UI  
\- ZIP download  
\- GitHub repo setup  
\- Deployment  
\- Demo video recording

## **AI Engineer / Data Scientist 1**

Responsible for:

\- SQL parser  
\- Schema metadata extraction  
\- SQL type mapping  
\- SQLAlchemy model generation  
\- Parser testing

## **AI Engineer / Data Scientist 2**

Responsible for:

\- Legacy name normalization  
\- Abbreviation dictionary  
\- Pytest generation  
\- README generation  
\- Modernization report generation  
\- Slide content and project explanation

---

# **15\. Example User Journey**

## **Step 1: Upload SQL File**

The user uploads:

CREATE TABLE tbl\_CUST\_MSTR\_2012\_v2 (  
    c\_id INT PRIMARY KEY,  
    vch\_fname VARCHAR(50),  
    vch\_lname VARCHAR(50),  
    fk\_str\_id INT,  
    dt\_upd\_dt TIMESTAMP  
);

## **Step 2: System Parses Schema**

The system detects:

Table: tbl\_CUST\_MSTR\_2012\_v2  
Columns:  
\- c\_id: INT, primary key  
\- vch\_fname: VARCHAR(50)  
\- vch\_lname: VARCHAR(50)  
\- fk\_str\_id: INT  
\- dt\_upd\_dt: TIMESTAMP

## **Step 3: System Cleans Names**

tbl\_CUST\_MSTR\_2012\_v2 → Customer  
c\_id → id  
vch\_fname → first\_name  
vch\_lname → last\_name  
fk\_str\_id → store\_id  
dt\_upd\_dt → updated\_at

## **Step 4: System Generates ORM Code**

The system generates models.py.

## **Step 5: System Generates Tests**

The system generates test\_models.py.

## **Step 6: User Downloads ZIP**

The user downloads a complete starter repository.

---

# **16\. Business Value**

LegacyLink AI provides value because it reduces repetitive engineering work in legacy system modernization.

## **Main Benefits**

| Benefit | Explanation |
| ----- | ----- |
| Faster onboarding | New developers understand database schemas faster |
| Less repetitive coding | ORM classes are generated automatically |
| Better documentation | Each transformation is explained |
| Better testing culture | Starter tests are generated immediately |
| Safer modernization | Developers can review generated code before using it |
| Lower migration friction | Old schema becomes easier to connect with modern apps |

---

# **17\. Originality**

Many tools generate code from databases, but LegacyLink AI focuses on **developer understanding**, not only code generation.

The unique parts are:

1\. It cleans messy legacy enterprise names.  
2\. It explains the transformation in a modernization report.  
3\. It generates both ORM code and starter tests.  
4\. It uses IBM Bob as a development partner to improve the repository, tests, and documentation.  
5\. It targets old SQL schema modernization, which is a real enterprise pain point.

---

# **18\. Judging Criteria Alignment**

| Judging Criteria | How LegacyLink AI Addresses It |
| ----- | ----- |
| **Application of Technology** | Uses IBM Bob to support repository understanding, code generation, refactoring, testing, and documentation |
| **Presentation** | Clear before-and-after demo from messy SQL to clean Python project |
| **Business Value** | Helps enterprises reduce time spent understanding and modernizing legacy databases |
| **Originality** | Combines SQL schema modernization, name cleaning, ORM generation, test generation, and modernization reporting |

The official judging criteria include application of technology, presentation, business value, and originality. ([LabLab](https://lablab.ai/ai-hackathons/ibm-bob-hackathon))

---

# **19\. Risks and Mitigation**

| Risk | Mitigation |
| ----- | ----- |
| SQL parsing becomes too complex | Support only common CREATE TABLE syntax for MVP |
| Generated code has bugs | Generate simple pytest tests and test with sample schemas |
| IBM Bob is not available as runtime API | Use Bob as development partner and include exported Bob report |
| Project scope becomes too large | Focus only on SQL schema to SQLAlchemy scaffold |
| Deployment issues | Use Streamlit Cloud for simple deployment |

---

# **20\. Future Improvements**

After the hackathon, LegacyLink AI can be improved with:

1\. Support for PostgreSQL, MySQL, Oracle, and SQL Server dialects.  
2\. ERD diagram generation.  
3\. Alembic migration file generation.  
4\. FastAPI CRUD endpoint generation.  
5\. Pydantic schema generation.  
6\. Dockerfile generation.  
7\. GitHub repository import.  
8\. Pull request generation for modernization changes.  
9\. Relationship inference from naming patterns.  
10\. LLM-assisted business meaning explanation.

---

# **21\. Final Short Description for Submission**

**LegacyLink AI is an IBM Bob-assisted legacy database modernization tool that converts messy SQL schema files into clean Python ORM project scaffolds. Users upload a .sql file, and the system parses table structures, cleans legacy names, generates SQLAlchemy 2.0 models, creates starter pytest files, and produces a modernization report explaining every transformation. The project helps developers understand old database systems faster, reduce repetitive ORM coding, and improve documentation and test readiness. IBM Bob is used throughout the development workflow to understand the repository, refactor code, generate tests, improve documentation, and support faster software delivery.**

---

# **22\. Final Long Description for Submission**

Legacy systems are difficult to maintain because old database schemas often contain unclear table names, abbreviated column names, missing documentation, and limited test coverage. Developers who join these projects need to spend a long time understanding what each table and column means before they can safely build new features.

LegacyLink AI addresses this problem by converting raw SQL DDL schema files into clean, modern Python ORM project scaffolds. The user uploads a .sql file containing CREATE TABLE statements. The system extracts schema metadata, detects legacy naming patterns, normalizes table and column names, maps SQL types into SQLAlchemy types, generates SQLAlchemy 2.0 ORM models, creates starter pytest test files, and produces a modernization report.

The output is a downloadable .zip file containing a ready-to-review Python project with models.py, database.py, test\_models.py, README.md, requirements.txt, and modernization\_report.md.

IBM Bob is used as the team’s AI development partner throughout the build process. Bob helps the team understand the project structure, improve parsing logic, refactor code generation modules, create tests, improve documentation, and prepare the final repository. This makes LegacyLink AI strongly aligned with the IBM Bob Hackathon goal of using AI to improve real software development workflows.

The 48-hour MVP focuses on a realistic and achievable scope: SQL schema upload, basic DDL parsing, legacy name cleaning, SQLAlchemy model generation, pytest generation, modernization reporting, and ZIP download. Future versions can support more SQL dialects, ERD diagrams, Alembic migrations, FastAPI CRUD generation, and GitHub pull request automation.

---

# **23\. Recommended Final Project Scope**

For the hackathon, build this exact MVP:

Input:  
\- One .sql file containing CREATE TABLE statements

Processing:  
\- Parse table names  
\- Parse column names  
\- Parse SQL data types  
\- Detect primary keys  
\- Clean legacy names  
\- Generate SQLAlchemy models  
\- Generate pytest tests  
\- Generate README  
\- Generate modernization report

Output:  
\- Downloadable ZIP project

This is **workable within 48 hours**.

Do **not** build live database connection, full SQL dialect support, authentication, or complex migration engine. Those are future work.