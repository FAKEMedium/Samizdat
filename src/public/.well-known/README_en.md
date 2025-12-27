# .well-known

Standard directory for well-known URIs (RFC 8615).

## security.txt

A standard for defining security policies (RFC 9116). Helps security researchers report vulnerabilities.

### Required Fields

- **Contact** - Email (mailto:), URL, or phone for reporting. Multiple allowed.
- **Expires** - ISO 8601 datetime when the file should be considered stale.

### Recommended Fields

- **Encryption** - URL to PGP key for encrypted communications.
- **Preferred-Languages** - Comma-separated language codes (e.g., `en,sv`).

### Optional Fields

- **Acknowledgements** - URL to page thanking security researchers.
- **Canonical** - Canonical URL for this security.txt file.
- **Policy** - URL to vulnerability disclosure policy.
- **Hiring** - URL to security-related job positions.

### Example security.txt

```
Contact: mailto:security@example.com
Encryption: https://example.com/security/pgp/security@example.com.asc
Expires: 2026-12-31T23:59:59.000Z
Policy: https://example.com/security
Acknowledgements: https://example.com/security/thanks
Preferred-Languages: en,sv
Canonical: https://example.com/.well-known/security.txt
```

### PGP Key Generation

Generate a key for security@example.com:

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, 2y expiration
# Enter: security@example.com

# Export public key
mkdir -p src/public/security/pgp
gpg --armor --export security@example.com > src/public/security/pgp/security@example.com.asc
```

### Signing security.txt

Digital signatures are recommended. Use the Makefile target:

```bash
make signsecurity
```

Or manually:

```bash
gpg --clearsign -u security@example.com src/public/.well-known/security.txt
mv src/public/.well-known/security.txt.asc src/public/.well-known/security.txt
```

### Validation

Test your security.txt at: https://internet.nl/

### References

- RFC 9116: https://www.rfc-editor.org/rfc/rfc9116
- securitytxt.org: https://securitytxt.org/