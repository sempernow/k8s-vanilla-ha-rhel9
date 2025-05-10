# [HAProxy / Keepalived](https://chatgpt.com/share/6804fcc4-45e0-8009-aaac-ccf8e9ed74de)

## __vIP__ for VRRP @ AD DNS

- Pick an available IP within the network's hosts-address range yet outside the DHCP range:
    - `192.168.11.11` (__vIP__)
- Add DHCP reservation 
    - Invent a dummy MAC using prefix "`02`", which designates it as __locally administered__.
        - __`02:00:00:00:01:01`__
- Manually create matching DNS __`A`__ (Apex) __record__:
    - __`k8s1.lime.lan`__
    - Add a __CNAME record__ that resolves to that.   
      This will be the __cluster hostname__ that is announced and otherwise __presented to external clients__:
        - __`kube.lime.lan`__

## `default-server` block:

```ini
default 
    ...
    default-server check inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
```

__Field-by-field Breakdown__:

| Directive     | Meaning                                                                                  | Suitability for K8s |
|---------------|-------------------------------------------------------------------------------------------|----------------------|
| `check`       | Enables health checks for backend servers                                                 | ✅ Required           |
| `inter 10s`   | Send health checks every 10 seconds while server is UP                                    | ✅ Conservative       |
| `downinter 5s`| Check every 5s when the server is DOWN (faster recovery)                                   | ✅ Good               |
| `rise 2`      | Mark server UP after 2 consecutive successful checks                                       | ✅ Reasonable         |
| `fall 2`      | Mark server DOWN after 2 consecutive failed checks                                         | ✅ Fast failover      |
| `slowstart 60s` | When server comes back online, ramp up traffic gradually over 60 seconds                | ✅ Recommended for API servers or ingress endpoints that need warm-up time |
| `maxconn 250` | Limit max concurrent connections to this server                                            | ⚠️ Fine if servers aren't under high pressure, but maybe raise for large clusters |
| `maxqueue 256`| If `maxconn` is reached, queue up to 256 connections                                       | ✅ Good               |
| `weight 100`  | Default load balancing weight                                                              | ✅ Standard           |

---

### 🧠 Suitability for:

#### ✅ **Kubernetes Control Plane (API servers):**
- ✅ `slowstart` helps avoid thundering herd during rejoin
- ✅ Fast failover (`fall 2`) and moderate rejoin (`rise 2`)
- ✅ Conservative check intervals to avoid flapping

#### ✅ **Kubernetes Data Plane (Ingress/Service TCPs):**
- Same logic applies
- May want lower `inter` values (e.g., `inter 5s`) if you want faster detection of failure
- May want higher `maxconn` (e.g., 1000) depending on expected load

---

## 🚀 Optional Tuning Ideas (Based on Use Case)

| Scenario                        | Suggested Change                                      |
|---------------------------------|-------------------------------------------------------|
| High traffic data plane         | `maxconn 1000` or higher                              |
| Sensitive control plane failover| `inter 5s` and `fall 1` for ultra-fast detection      |
| Faster rejoin                   | `rise 1` (only 1 good check to mark UP again)         |
| Remove queues completely        | Remove `maxqueue` (default: no queuing)              |

---

## ✅ Final Verdict

**Yes**, these settings are solid for production **Kubernetes upstreams** — both control and data plane. You can fine-tune based on:

- Server capacity
- Acceptable recovery time
- Connection pressure

If you want help customizing these for control plane vs data plane backends (e.g., `k8s-api` vs `k8s-data`), I can write those backend blocks out for you.