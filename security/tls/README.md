## TLS : AD CS

By default, 
the AD CS role of Windows Server 2019 provides 
only RSA type TLS certificates.

We successfully obtained a TLS certificate for web server usage 
from AD CS web form of its Certificate Server at `https://dc1.lime.lan/certsrv/`

The server responds with two (end-entity and full-chain) certificates, 
both __in PKCS#7 format__ (`.p7b`), 
and so must be converted to PEM for use in most servers.
Their odd format is useful only at Microsoft IIS and other legacy 
or non-standard servers such as Apache Tomcat.

- `certnew.p7b`

```bash
# Convert certificate from PKCS#7 (.p7b) to PEM format
cn=kube.lime.lan
openssl pkcs7 -print_certs -in certnew.p7b -out $cn.crt

# Parse the certificate
openssl x509 -noout -issuer -subject -startdate -enddate -ext subjectAltName -in $cn.crt
```

```plaintext
issuer=DC = lan, DC = lime, CN = lime-DC1-CA
subject=C = US, ST = MD, L = AAC, O = DisselTree, OU = ops, CN = kube.lime.lan, emailAddress = admin@lime.lan
notBefore=Jan 25 14:32:36 2025 GMT
notAfter=Jan 25 14:32:36 2027 GMT
X509v3 Subject Alternative Name:
    DNS:kube.lime.lan, DNS:*.kube.lime.lan
```

### CSR

AD CS requires CSR in PKCS#10/#7 (New/Renew) format.
OpenSSL generates the request (`*.csr`) in that format by default.

Regarding Windows Server 2019 and prior, 
AD CS offers __only RSA-based certificates__ 
unless that role is configured otherwise, 
which is a non-trivial task that nearly no organization performs.

```bash
root=lime.lan
cn=kube.$root
TLS_ST=MD
TLS_L=AAC
TLS_O=DisselTree
TLS_OU=ops
## Create the configuration file (CNF) : See man config
## See: man openssl-req : CONFIGURATION FILE FORMAT section
## https://www.openssl.org/docs/man1.0.2/man1/openssl-req.html
cat <<EOH |tee $cn.cnf
[ req ]
prompt              = no        # Disable interactive prompts.
default_bits        = 2048      # Key size for RSA keys. Ignored for Ed25519.
default_md          = sha256    # Hashing algorithm.
distinguished_name  = req_distinguished_name 
req_extensions      = v3_req    # Extensions to include in the request.
[ req_distinguished_name ] 
CN              = $cn                   # Common Name
C               = ${TLS_C:-US}          # Country
ST              = ${TLS_ST:-NY}         # State or Province
L               = ${TLS_L:-Gotham}      # Locality name
O               = ${TLS_O:-Foobar Inc}  # Organization name
OU              = ${TLS_OU:-GitOps}     # Organizational Unit name
emailAddress    = admin@$root
[ v3_req ]
subjectAltName      = @alt_names
keyUsage            = digitalSignature
extendedKeyUsage    = serverAuth
[ alt_names ]
DNS.1 = $cn
DNS.2 = *.$cn   # Wildcard. CA must allow, else declare each subdomain.
EOH

# RSA (Use only this if the certificate server is AD CS)
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey rsa:2048 -keyout $cn.key -out $cn.csr 
# ED25519
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey ed25519 -keyout $cn.key -out $cn.csr
# ECDSA (NIST P-256 curve)
openssl req -new -noenc -config $cn.cnf -extensions v3_req -newkey ec:<(openssl ecparam -name prime256v1 -genkey) -keyout $cn.key -out $cn.csr

```

