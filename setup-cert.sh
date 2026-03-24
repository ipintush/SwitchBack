#!/usr/bin/env bash
set -e

CERT_NAME="SwitchBack Dev"

# Check if certificate already exists
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "Certificate '$CERT_NAME' already exists."
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create private key
openssl genrsa -out "$TMPDIR/key.pem" 2048 2>/dev/null

# Create self-signed cert with Code Signing EKU
openssl req -new -x509 \
    -key "$TMPDIR/key.pem" \
    -out "$TMPDIR/cert.pem" \
    -days 36500 \
    -subj "/CN=$CERT_NAME/O=SwitchBack" \
    -extensions v3_req \
    -config <(printf '[req]\ndistinguished_name=dn\n[dn]\n[v3_req]\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n') \
    2>/dev/null

# Export to p12 and import into Keychain
openssl pkcs12 -export \
    -out "$TMPDIR/cert.p12" \
    -inkey "$TMPDIR/key.pem" \
    -in "$TMPDIR/cert.pem" \
    -passout pass: 2>/dev/null

security import "$TMPDIR/cert.p12" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# Trust for code signing
security add-trusted-cert \
    -d \
    -r trustRoot \
    -p codeSign \
    -k ~/Library/Keychains/login.keychain-db \
    "$TMPDIR/cert.pem"

echo "Certificate '$CERT_NAME' created and trusted for code signing."
