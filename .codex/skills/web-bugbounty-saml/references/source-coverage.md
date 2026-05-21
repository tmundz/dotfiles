# Source Coverage Map

This skill was derived from every source file present in the project directory.

## `How to Hunt Bugs in SAML; a Methodology - Part III _ epi's notes-to-self.html`

Covered concepts:

- Methodology is a flexible testing guide, not a rigid checklist.
- Creativity matters; apply general web vulnerability knowledge to SAML flows.
- RelayState can hide an open redirect because it carries SP state through the IdP and back to the SP.
- Core checks:
  - Assertion without signature / signature exclusion.
  - XML Signature Wrapping.
  - Trusted IdP verification / certificate faking.
  - Assertion replay.
  - XXE via SAML.
  - XSLT via SAML.
  - Token recipient confusion across SPs using the same IdP.
- Additional permutations:
  - More XSW variants.
  - XML canonicalization of comments.
- Resource categories preserved in the matrix:
  - General SAML/XMLDSig learning.
  - White papers.
  - XML Signature Wrapping write-ups.
  - Signature exclusion write-ups.
  - XXE write-ups.
  - XSLT write-ups and payloads.
  - Certificate faking write-ups.
  - Token recipient confusion write-ups.
  - Disclosed HackerOne vulnerability reports.

## `testing-sam-security-with-dast.txt`

Covered concepts:

- SAML SSO parties: user agent, SP, IdP.
- `SAMLRequest`, `SAMLResponse`, and SAML consumer/ACS endpoints.
- Automated checks are possible for common SP-side issues, but logic bugs still require manual testing.
- Need a valid authenticated SAMLResponse for signature-related checks.
- Missing signature verification can be tested by modifying `DigestValue`.
- Signature exclusion can be tested by removing the `Signature` branch.
- ACS endpoint can often be discovered from Redirect binding `SAMLRequest` by decoding the AuthnRequest and reading `AssertionConsumerServiceURL`.
- AuthnRequest data also helps infer issuer, IdP destination, expected attributes, and metadata locations.
- Anonymous ACS testing can identify pre-signature parser issues:
  - XXE.
  - XSLT injection in signature transforms.
  - SSRF via `KeyInfo` dereferencing.
  - XSS from reflected `SAMLResponse` fields or validation errors.
- XML-escaped XSS payloads are required to keep XML parseable.
- Destination-based XSS payloads should remain syntactically valid URLs.
- Response comparison must account for dynamic web content and focus on acceptance/rejection behavior.

## `ruby-gitlab-saml.txt`

Covered concepts:

- CVE-2024-45409 affected Ruby-SAML and OmniAuth-SAML usage, including GitLab.
- SAML signature model:
  - Assertion digest is calculated over canonicalized assertion after removing enveloped signature.
  - `SignedInfo/Reference` stores digest and is signed.
  - SP verifies both digest and signature.
- XPath refresher:
  - `/` selects from document root.
  - `./` selects relative child nodes.
  - `//` selects any matching node anywhere below the context/document.
- Vulnerability:
  - Broad `//ds:DigestValue` lookup can select attacker-controlled digest outside the intended `Reference`.
  - `samlp:Extensions` can carry a namespaced attacker-controlled `DigestValue`.
  - `SignedInfo` remains unchanged and its signature can still verify while digest comparison uses the smuggled value.
- Important variables:
  - `canon_hashed_element`: assertion block without the signature.
  - `encoded_digest_value`: attacker-controlled value when broad XPath selects it.
  - `canon_string`: `SignedInfo` block.
- GitLab-style callback and nuclei proof pattern:
  - `/users/auth/saml/callback`.
  - `nuclei -t CVE-2024-45409.yaml -u https://target -code -var SAMLResponse=...`.
- Defensive conclusion:
  - Update libraries.
  - Use strict validation and exact XPath/reference resolution.
