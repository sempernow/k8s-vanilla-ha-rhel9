# [`nicolaka/netshoot`](https://github.com/nicolaka/netshoot "GitHub") | [@ hub.docker.com](https://hub.docker.com/r/nicolaka/netshoot/tags)

Box for Debugging

>a Docker Networking Trouble-shooting Swiss-Army Container


```bash
img=nicolaka/netshoot
k run nbox -it --rm \
    --env TARGET_HOST=$ip \
    --env TARGET_PORT=$p  \
    --image=$img  -- \
    bash
```
```bash
nbox:~# nmap -p 5500-5559 -dd $TARGET_HOST 2>/dev/null |grep open
Discovered open port 5555/tcp on 10.244.182.128
5555/tcp open   freeciv         syn-ack ttl 63
```

```bash
netstat -tulpn
tcpdump -i eth0 port $TARGET_PORT -c 1 -Xvv
...
```

__List of tools__

```bash
apache2-utils
bash
bind-tools
bird
bridge-utils
busybox-extras
calicoctl
conntrack-tools
ctop
curl
dhcping
drill
ethtool
file
fping
httpie
iftop
iperf
iproute2
ipset
iptables
iptraf-ng
iputils
ipvsadm
jq
libc6-compat
liboping
mtr
net-snmp-tools
netcat-openbsd
netgen
nftables
ngrep
nmap
nmap-nping
openssl
py-crypto
py2-virtualenv
python2
scapy
socat
strace
tcpdump
tcptraceroute
termshark
tshark
util-linux
vim
websocat

```

### &nbsp;

## [`k8s-iperf`](https://github.com/sempernow/k8s-iperf "GitHub.com")

```bash
git clone git@github.com:sempernow/k8s-iperf.git
cd k8s-iperf
bash k8s-iperf.sh
```
- [__`k8s-iperf.sh`__](k8s-iperf.sh)