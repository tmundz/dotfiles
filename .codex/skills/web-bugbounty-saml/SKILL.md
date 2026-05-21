---
name: web-bugbounty-saml
description: CLI-native web hacking and bug bounty workflow for authorized SAML SSO testing. Use when Codex needs to test, audit, triage, or report SAML/SSO bugs using terminal-first tooling such as curl, bash pipelines, ffuf, nuclei, openssl, xmllint, and local scripts; includes SAMLRequest/SAMLResponse decoding, ACS discovery, signature verification checks, signature exclusion, XML Signature Wrapping, certificate faking, assertion replay, XXE, XSLT, KeyInfo SSRF, XSS in SAML fields, token recipient confusion, RelayState redirect testing, and Ruby-SAML/GitLab CVE-2024-45409-style digest smuggling analysis.
---

# Web Bug Bounty SAML

## Operating Rules

Use this skill only for authorized targets, bug bounty scopes, owned labs, or explicit pentest work. Keep testing evidence minimal, avoid persistence, avoid using third-party accounts without permission, and stop if a payload would affect users, production data, identity providers outside scope, or infrastructure that the program excludes.

Prefer CLI-native workflows. Do not assume MCP, Caido, Burp extensions, Claude Code commands, or GUI-only tooling. If a proxy is useful, describe generic HTTP capture/export steps and continue with `curl`, local files, and scripts.

## Quick Workflow

1. Confirm scope: service provider host, IdP host, ACS endpoint, allowed accounts, allowed test intensity, and whether SSO/IdP is in scope.
2. Capture the SAML flow:
   - Identify `SAMLRequest`, `SAMLResponse`, and `RelayState` parameters from browser devtools, HAR export, server logs, or a local intercepting proxy export.
   - Save each value exactly as submitted before mutation.
3. Decode and inspect:
   - Use `python3 scripts/saml_cli.py decode --kind response --input-file samlresponse.txt --out response.xml`.
   - Use `python3 scripts/saml_cli.py inspect --xml response.xml`.
   - For Redirect binding requests, use `python3 scripts/saml_cli.py decode --kind request --input-file samlrequest.txt --out request.xml`.
4. Discover the ACS endpoint:
   - Prefer `AssertionConsumerServiceURL` from decoded `AuthnRequest`.
   - Fall back to observed POST destination, metadata, predictable routes (`/saml/acs`, `/users/auth/saml/callback`, `/sso/saml/acs`), or scoped fuzzing.
5. Establish the baseline:
   - Replay the unmodified response once in a controlled test account and record status code, redirects, cookies set, and account/session outcome.
   - Compare every mutation against that baseline.
6. Run the test matrix in risk order:
   - Signature checks: tampered digest, removed signature, Ruby-SAML digest smuggling, XSW variants, certificate faking.
   - XML parser checks: XXE, XSLT transform handling, KeyInfo dereference/SSRF.
   - Logic checks: assertion replay, token recipient confusion, audience/recipient/destination mismatch, RelayState open redirect.
   - Reflection checks: SAML field XSS and error-message encoding.
7. Report only confirmed impact:
   - Include exact endpoint, decoded relevant fields, mutation performed, baseline-vs-mutated behavior, account used, timestamps, and remediation.

## References

Load only the reference needed for the task:

- `references/workflow.md`: End-to-end CLI workflow, capture, decoding, endpoint discovery, replay, comparison, and reporting.
- `references/test-matrix.md`: Detailed SAML vulnerability matrix from the source material, including what to mutate, expected secure behavior, evidence, and remediation.
- `references/ruby-saml-cve-2024-45409.md`: Ruby-SAML/OmniAuth-SAML/GitLab digest-smuggling analysis and nuclei-style testing notes.
- `references/source-coverage.md`: Coverage map of the project source files and the concepts extracted from each.

## Helper Script

Use `scripts/saml_cli.py` for deterministic local SAML operations:

```bash
python3 scripts/saml_cli.py decode --kind response --input-file samlresponse.txt --out response.xml
python3 scripts/saml_cli.py inspect --xml response.xml
python3 scripts/saml_cli.py mutate --type remove-signature --xml response.xml --out no-signature.xml
python3 scripts/saml_cli.py mutate --type tamper-digest --xml response.xml --out bad-digest.xml
python3 scripts/saml_cli.py encode --kind response --xml bad-digest.xml --out bad-digest.b64
python3 scripts/saml_cli.py curl-form --url https://target.example/saml/acs --samlresponse-file bad-digest.b64 --relay-state-file relaystate.txt
```

The script uses Python standard library behavior and is intentionally transparent. For exact XML canonicalization, signature validation, or library-specific reproduction, inspect and adapt the generated XML manually with `xmllint`, `openssl`, application logs, or the target application's SAML library.

## CLI Tooling Defaults

Use these tools when available:

- `curl` for replaying POST/Redirect binding requests and preserving cookies with `-c jar -b jar`.
- `xmllint --format`, `xmlstarlet`, or `python3 scripts/saml_cli.py inspect` for XML inspection.
- `openssl x509 -noout -subject -issuer -dates -fingerprint -sha256` for IdP certificate review.
- `ffuf` for scoped ACS route discovery only when endpoint discovery from `SAMLRequest` fails.
- `nuclei` for single-purpose, scope-approved checks where the template is reviewed before execution.
- `jq`, `sed`, `awk`, `grep`, and `diff -u` for response comparison and evidence reduction.

## Evidence Discipline

Keep raw assertions, cookies, and account identifiers out of final public reports unless required by the program. Redact secrets but preserve enough structure to prove the issue: endpoint, SAML element names, mutation type, status/redirect differences, and account identity transition.
