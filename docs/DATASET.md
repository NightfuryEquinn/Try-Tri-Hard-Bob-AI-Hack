For **LegacyLink AI**, you should use **open-source SQL sample databases**, because your app needs `.sql` schema files, not ML datasets.

My recommendation:

# **Use Chinook as your main demo dataset**

Chinook is the best choice for your 48-hour MVP because it is made for **demo and ORM testing**, supports many database engines, and has normal business tables like artists, albums, tracks, invoices, and customers. The official repo says Chinook is available for SQL Server, Oracle, MySQL, PostgreSQL, SQLite, DB2, and is ideal for demos and testing ORM tools. ([GitHub](https://github.com/lerocha/chinook-database))

Use this as your **primary dataset**:

Chinook Database  
Use case: digital media store  
Best for: main hackathon demo  
Why: clean, medium-size, easy to explain, ORM-friendly

Your demo story can be:

“We upload the Chinook SQL schema. LegacyLink AI parses the tables, cleans table and column names, generates SQLAlchemy models, creates pytest files, and produces a modernization report.”

---

# **Best datasets to use**

| Priority | Dataset | Best Use | Why |
| ----- | ----- | ----- | ----- |
| **1** | **Chinook** | Main demo | Best for ORM/code generation demo |
| **2** | **Sakila** | More complex demo | Has tables, views, stored procedures, triggers |
| **3** | **Pagila** | PostgreSQL demo | PostgreSQL version of Sakila, includes foreign keys and PostgreSQL features |
| **4** | **Employee Sample Database** | HR/enterprise demo | Looks more like enterprise employee records |
| **5** | **Northwind** | Classic business demo | Customers, orders, products, suppliers |
| **6** | **AdventureWorks** | Future/advanced demo | More enterprise, but too large for 48-hour MVP |

---

# **1\. Chinook Database, best for MVP**

Use this first.

It represents a digital media store with tables such as artists, albums, tracks, invoices, and customers. It is available across multiple database servers and is described as suitable for demos and ORM tool testing. ([GitHub](https://github.com/lerocha/chinook-database))

### **Why it is good for your project**

✅ Not too small  
✅ Not too complex  
✅ Easy to explain in video  
✅ Good table relationships  
✅ Supports many SQL dialects  
✅ Good for ORM generation demo

### **Example transformation**

Artist table → Artist model  
Album table → Album model  
Customer table → Customer model  
Invoice table → Invoice model  
InvoiceLine table → InvoiceLine model

This is very suitable for showing:

SQL schema → SQLAlchemy models → pytest tests → README/report

---

# **2\. Sakila Database, good for complex demo**

Sakila is MySQL’s official sample database. The documentation says it includes structure, tables, views, stored procedures, functions, triggers, and usage examples. ([dev.mysql.com](https://dev.mysql.com/doc/sakila/en/))

The `sakila-schema.sql` and `sakila-data.sql` files are licensed under the New BSD license. ([dev.mysql.com](https://dev.mysql.com/doc/sakila/en/sakila-license.html))

### **Why it is useful**

✅ More realistic than Chinook  
✅ Has many relationships  
✅ Good for “advanced schema” demo  
✅ Open license for schema/data files

### **But for 48 hours**

Use Sakila only as your **second test case**, not your main demo, because stored procedures and triggers may make parsing harder.

---

# **3\. Pagila, good for PostgreSQL demo**

Pagila is a PostgreSQL sample database based on Sakila. The repo says it is available under the PostgreSQL license and includes PostgreSQL-style features such as foreign keys, triggers, full-text search, JSONB, and partitioned tables. ([GitHub](https://github.com/devrimgunduz/pagila))

### **Why it is useful**

✅ Good PostgreSQL test case  
✅ Has foreign keys  
✅ Looks more technical  
✅ Good for future enhancement section

### **But for 48 hours**

Do not fully support all Pagila features. Use it to show:

“Our MVP supports the core CREATE TABLE structure. Advanced objects like triggers, JSONB, and partitioned tables are future work.”

That sounds honest and professional.

---

# **4\. Employee Sample Database, good enterprise-style demo**

The Bytebase Employee Sample Database supports MySQL, PostgreSQL, and SQLite, and the GitHub page shows it is MIT licensed. ([GitHub](https://github.com/bytebase/employee-sample-database))

### **Why it is useful**

✅ Looks like enterprise HR data  
✅ Easy to explain  
✅ Good for business-style modernization  
✅ MIT license

This is good if you want the project to sound more like:

Enterprise HR legacy database modernization

---

# **5\. Northwind, classic business schema**

Northwind is a classic SQL Server sample database. Microsoft’s SQL Server samples repo says the folder contains scripts to create and load the Northwind and pubs sample databases, originally created for SQL Server 2000\. ([GitHub](https://github.com/microsoft/sql-server-samples/blob/master/samples/databases/northwind-pubs/readme.md))

The wider Microsoft SQL Server samples repository is MIT licensed. ([GitHub](https://github.com/microsoft/sql-server-samples))

### **Why it is useful**

✅ Classic business database  
✅ Customers, orders, products, suppliers  
✅ Easy to explain to judges

### **But**

Some old Northwind scripts contain older SQL Server syntax, so it may be slightly harder to parse than Chinook.

---

# **6\. AdventureWorks, only for future work**

AdventureWorks is a Microsoft sample database originally created to show SQL Server database design, with OLTP and data warehouse versions. ([GitHub](https://github.com/microsoft/sql-server-samples/blob/master/samples/databases/adventure-works/README.md))

The Microsoft SQL Server samples repo is MIT licensed. ([GitHub](https://github.com/microsoft/sql-server-samples))

### **My advice**

Do **not** use AdventureWorks for your 48-hour MVP.

It is too large and may waste time.

Use it only in your proposal as:

Future benchmark dataset for larger enterprise schema modernization.

---

# **My final recommendation**

Use **3 sample SQL files** in your GitHub repo:

examples/  
├── chinook\_sample.sql  
├── employee\_sample.sql  
└── legacy\_messy\_custom\_sample.sql

## **Main demo**

Use:

Chinook

## **Enterprise demo**

Use:

Employee Sample Database

## **Most important custom demo**

Create your own messy legacy SQL file:

CREATE TABLE tbl\_CUST\_MSTR\_2012\_v2 (  
    c\_id INT PRIMARY KEY,  
    vch\_fname VARCHAR(50),  
    vch\_lname VARCHAR(50),  
    fk\_str\_id INT,  
    dt\_upd\_dt TIMESTAMP  
);

CREATE TABLE tbl\_ORD\_HDR\_OLD (  
    ord\_id INT PRIMARY KEY,  
    fk\_c\_id INT,  
    dt\_ord\_dt TIMESTAMP,  
    dec\_total\_amt DECIMAL(10,2)  
);

This custom file is important because open-source datasets are usually already clean. Your project needs to show the **legacy cleaning function**, so you need a purposely messy sample.

---

# **Best setup for your hackathon**

Use this in your README:

Datasets used for testing and demonstration:

1\. Chinook Database  
   Purpose: Main ORM generation demo.

2\. Employee Sample Database  
   Purpose: Enterprise-style HR schema demo.

3\. Custom Legacy SQL Schema  
   Purpose: Demonstrates messy enterprise naming cleanup.

This is the most feasible combination for 48 hours.