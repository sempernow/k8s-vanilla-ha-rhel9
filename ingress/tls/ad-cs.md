
# How to Use cert-manager with AD CS

**cert-manager can work with Windows Server 2019 AD Certificate Services (AD CS)** — but **not directly** out-of-the-box. You need a **cert-manager external issuer plugin** to act as a bridge between cert-manager and Microsoft’s AD CS.


Use the external plugin:

### 🔗 [`cert-manager-issuer/adcs-issuer`](https://github.com/cert-manager/adcs-issuer)

This is an official project from the cert-manager team (Jetstack), designed specifically to allow cert-manager to:

* Request certificates from a Microsoft AD CS server over DCOM or HTTPS (MS-WCCE)
* Manage and renew those certs as normal Kubernetes secrets

---

## 🛠️ High-Level Setup Steps

### 1. **Install cert-manager** (as usual)

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
```

---

### 2. **Install the ADCS Issuer plugin**

```bash
kubectl apply -f https://github.com/cert-manager/adcs-issuer/releases/latest/download/adcs-issuer.yaml
```

This deploys the ADCS-specific controller alongside cert-manager.

---

### 3. **Create a Secret for ADCS Credentials**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: adcs-creds
  namespace: cert-manager
type: Opaque
stringData:
  username: adcs-user@yourdomain.com
  password: your-password
```

---

### 4. **Create an ADCS Issuer**

```yaml
apiVersion: adcs.certmanager.csf.nokia.com/v1
kind: ADCSIssuer
metadata:
  name: adcs-issuer
  namespace: cert-manager
spec:
  url: https://dc1.yourdomain.com/certsrv/  # MS Web Enrollment endpoint
  credentials:
    name: adcs-creds
  template: WebServer
```

Or use `ClusterADCSIssuer` if cluster-wide access is needed.

---

### 5. **Request a Certificate**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-cert
  namespace: your-namespace
spec:
  secretName: my-service-cert-tls
  issuerRef:
    name: adcs-issuer
    kind: ADCSIssuer
    group: adcs.certmanager.csf.nokia.com
  commonName: service.yourdomain.com
  dnsNames:
    - service.yourdomain.com
```

cert-manager will:

* Call the AD CS Web Enrollment service
* Request a cert using the WebServer template (or custom template)
* Store the resulting cert + key in `my-service-cert-tls`

---

## 🧩 Compatibility Notes

| Requirement                   | Supported?                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| Windows Server 2019 AD CS     | ✅ Yes                                                                              |
| Uses MS Web Enrollment (WCCE) | ✅ Yes                                                                              |
| Uses Kerberos or NTLM         | ✅ No (requires Basic Auth over HTTPS)                                              |
| Supports custom templates     | ✅ Yes, if exposed by AD CS                                                         |
| Can be used in air-gap        | ⚠️️️️️️ Possible, but requires internal networking + HTTPS from cluster to AD CS server |

---

## 🔒 Security Considerations

* AD CS must have **Web Enrollment** role installed (`certsrv`)
* Basic Auth over HTTPS is required; **no support for GSSAPI/Kerberos**
* Ensure ADCS Web Enrollment server has a valid TLS cert

---

## Offline Root CA : Use Intermediate CA

    [Offline Root CA] ───signs───▶ [Intermediate CA]
                                    |
                                cert-manager
                                    |
                                Issues TLS certs to:
                                - Ingress
                                - Internal apps
                                - mTLS between services
