# CLI-Native SAML Bug Bounty Workflow

## Purpose

Apply the SAML testing methodology from the project sources with terminal-first execution. The goal is to prove whether the service provider (SP) rejects malformed, unsigned, wrongly signed, replayed, misdirected, or parser-abusive SAML messages.

## Scope and Safety

Test only authorized SAML deployments. Treat the identity provider as out of scope unless the program explicitly includes it. Use your own test accounts. Do not attack third-party IdPs, scrape user data, brute force accounts, or keep sessions beyond proof requirements.

## SAML Flow to Capture

A standard web SSO flow has three parties:

- User agent: browser submitting redirects and forms.
- Service provider: target application.
- Identity provider: system authenticating the user.

Typical flow:

1. User requests SP login.
2. SP redirects to IdP with `SAMLRequest` and often `RelayState`.
3. IdP authenticates the user.
4. IdP returns an auto-submitting form containing `SAMLResponse`.
5. Browser posts `SAMLResponse` to the SP Assertion Consumer Service (ACS).
6. SP validates the message and creates a session.

Security testing mostly targets the SP's ACS endpoint and how it parses, validates, and consumes `SAMLResponse`.

## Capture Values

Capture:

- `SAMLRequest` from Redirect binding query string.
- `SAMLResponse` from POST body.
- `RelayState`, if present.
- Destination/POST URL used for the ACS.
- Cookies before and after ACS submission.
- Final redirect and authenticated identity.

Practical capture options:

```bash
# Save URL-decoded form/query values from an exported request.
printf '%s' "$SAML_RESPONSE_VALUE" > samlresponse.txt
printf '%s' "$SAML_REQUEST_VALUE" > samlrequest.txt
printf '%s' "$RELAY_STATE_VALUE" > relaystate.txt
```

## Decode SAML

SAMLResponse is normally base64 XML:

```bash
python3 scripts/saml_cli.py decode --kind response --input-file samlresponse.txt --out response.xml
python3 scripts/saml_cli.py inspect --xml response.xml
```

SAMLRequest in Redirect binding is normally URL-encoded, base64-encoded, raw-DEFLATE XML:

```bash
python3 scripts/saml_cli.py decode --kind request --input-file samlrequest.txt --out request.xml
python3 scripts/saml_cli.py inspect --xml request.xml
```

Manual equivalent:

```bash
python3 -c 'import sys,urllib.parse,base64,zlib; v=urllib.parse.unquote_plus(sys.stdin.read().strip()); print(zlib.decompress(base64.b64decode(v), -15).decode())' < samlrequest.txt
python3 -c 'import sys,urllib.parse,base64; v=urllib.parse.unquote_plus(sys.stdin.read().strip()); print(base64.b64decode(v).decode())' < samlresponse.txt
```

## Discover ACS Endpoint

Prefer deterministic sources:

1. POST destination observed when submitting `SAMLResponse`.
2. `AssertionConsumerServiceURL` in decoded `AuthnRequest`.
3. SP metadata if exposed.
4. Common framework routes, fuzzed only within scope.

Extract from an AuthnRequest:

```bash
python3 scripts/saml_cli.py inspect --xml request.xml
```

Common paths for scoped fallback discovery:

```bash
printf '%s\n' \
  saml/acs sso/saml/acs auth/saml/callback users/auth/saml/callback \
  SAML2/POST saml/consume saml/callback > saml-acs-routes.txt
ffuf -u https://target.example/FUZZ -w saml-acs-routes.txt -mc all -fs 0
```

## Establish Baseline Replay

Replay the original response once with a controlled account. Preserve cookies and compare mutated results to this baseline.

```bash
python3 scripts/saml_cli.py curl-form \
  --url https://target.example/saml/acs \
  --samlresponse-file samlresponse.txt \
  --relay-state-file relaystate.txt > replay.sh
bash replay.sh > baseline.http
```

Record:

- HTTP status and redirect chain.
- `Set-Cookie` behavior.
- Whether an authenticated session is created.
- Which identity/account is shown after login.
- Any SAML validation error text.

## Response Comparison

Use content-aware judgment. Dynamic apps change tokens and timestamps, so compare security outcome more than raw byte equality.

Useful CLI patterns:

```bash
curl -i -s -k -c jar -b jar -o mutated.body -D mutated.headers --data-urlencode "SAMLResponse@mutated.b64" --data-urlencode "RelayState@relaystate.txt" https://target.example/saml/acs
diff -u baseline.headers mutated.headers | sed -n '1,120p'
diff -u baseline.body mutated.body | sed -n '1,160p'
grep -Ei 'saml|signature|digest|invalid|error|issuer|audience|recipient|assertion' mutated.body
```

A finding usually requires that a mutated response creates the same authenticated state as the valid baseline or creates a different unauthorized state.

## Test Order

Run lower-risk validation checks first:

1. Tamper digest: change `DigestValue`; secure SP rejects.
2. Remove signature: delete `Signature`; secure SP rejects unless unsigned assertions are explicitly required and safe.
3. Change identity attributes without valid re-signing; secure SP rejects.
4. Replay original assertion; secure SP should limit replay according to `InResponseTo`, `NotOnOrAfter`, and session policy.
5. Destination/Recipient/Audience mismatch; secure SP rejects.
6. XML parser payloads: XXE, XSLT, KeyInfo URL dereference, only with benign callback infrastructure you control.
7. XSW and certificate faking variants, with manual care.
8. Token recipient confusion across two SPs using the same IdP, only if both SPs and the account are in scope.
9. RelayState redirect and state-handling tests.

## Reporting

Include:

- Program scope statement and target.
- ACS endpoint.
- Baseline authenticated behavior.
- Mutated SAML snippet or generated mutation command.
- HTTP evidence showing acceptance/rejection.
- Account transition or impact.
- Recommended fix: strict XMLDSig verification, trusted IdP certificate pinning, exact reference resolution, one assertion, audience/recipient/destination checks, replay prevention, safe XML parser configuration, no external dereferencing, output encoding.
