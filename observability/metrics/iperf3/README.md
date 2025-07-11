# [`nicolaka/netshoot`](https://hub.docker.com/r/nicolaka/netshoot "hub.docker.com")


## `iperf3`

### TL;DR

One of `netshoot`'s many tools. Performs __network throughput__ tests.
It performs a measure of the maximum network transfer rate between server and client.
Used in a K8s environment, we measure that maximum `Gbits/sec` (`Gbps`) for east-west traffic, 
both cross-node (__5 Gpbs__) and intra-node (__35 Gbps__), 
under Calico CNI configured for direct path (eBPF).

__Findings__:

|East-west| `Gbps`|
|--|--|
|Intra-node| __`5`__|
|Inter-node|__`35`__|

### Work

@ `Ubuntu (master) [07:42:17] [2] [#0] /s/DEV/devops/infra/kubernetes/k8s-vanilla-ha-rhel9`

```bash
img=nicolaka/netshoot
p=5555
name=nbox1
k run $name --image=$img -- iperf3 -s -p $p
```

@ __Same node__

```bash
name=nbox1
node=$(kubectl get pod $name -o jsonpath='{.spec.nodeName}')
ip=$(k get pod $name -o wide -o jsonpath='{.status.podIPs[].ip}')
img=nicolaka/netshoot
p=5555
name=nbox2
k run $name -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$node'"}}' \
    --restart=Never  -- \
    iperf3 -c $ip -p $p

```
```plaintext
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec  4.24 GBytes  36.4 Gbits/sec  317   1.18 MBytes
[  5]   1.00-2.00   sec  4.27 GBytes  36.7 Gbits/sec  426   1.31 MBytes
[  5]   2.00-3.00   sec  4.16 GBytes  35.8 Gbits/sec  277   1.27 MBytes
[  5]   3.00-4.00   sec  4.13 GBytes  35.5 Gbits/sec    0   1.61 MBytes
[  5]   4.00-5.00   sec  4.10 GBytes  35.2 Gbits/sec  394   1.83 MBytes
[  5]   5.00-6.00   sec  4.03 GBytes  34.6 Gbits/sec    0   1.84 MBytes
[  5]   6.00-7.00   sec  4.10 GBytes  35.2 Gbits/sec  751   1.84 MBytes
[  5]   7.00-8.00   sec  3.75 GBytes  32.2 Gbits/sec    1   1.93 MBytes
[  5]   8.00-9.00   sec  3.94 GBytes  33.8 Gbits/sec  259   2.08 MBytes
[  5]   9.00-10.00  sec  4.03 GBytes  34.6 Gbits/sec    0   2.09 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  40.8 GBytes  35.0 Gbits/sec  2425             sender
[  5]   0.00-10.00  sec  40.8 GBytes  35.0 Gbits/sec                  receiver
```


@ __Other node__

```bash
name=nbox1
node=$(kubectl get pod $name -o jsonpath='{.spec.nodeName}')
node=$(kubectl get node -oname -o yaml |yq '.[][].metadata |select (.name != "'$node'") |.name' |head -n1)
k run nbox2 -it --rm \
    --image=$img \
    --overrides='{"spec": {"nodeName": "'$node'"}}' \
    --restart=Never  -- \
    iperf3 -c $ip -p $p
```
```plaintext
...
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   700 MBytes  5.87 Gbits/sec   66   1.06 MBytes
[  5]   1.00-2.00   sec   625 MBytes  5.24 Gbits/sec    0   1.37 MBytes
[  5]   2.00-3.00   sec   618 MBytes  5.19 Gbits/sec    0   1.46 MBytes
[  5]   3.00-4.00   sec   618 MBytes  5.18 Gbits/sec  319   1.50 MBytes
[  5]   4.00-5.00   sec   614 MBytes  5.15 Gbits/sec   77   1.52 MBytes
[  5]   5.00-6.00   sec   598 MBytes  5.02 Gbits/sec   62   1.53 MBytes
[  5]   6.00-7.00   sec   599 MBytes  5.02 Gbits/sec  421   1.55 MBytes
[  5]   7.00-8.00   sec   579 MBytes  4.86 Gbits/sec    0   1.56 MBytes
[  5]   8.00-9.00   sec   584 MBytes  4.90 Gbits/sec    0   1.57 MBytes
[  5]   9.00-10.00  sec   601 MBytes  5.04 Gbits/sec    0   1.58 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  5.99 GBytes  5.15 Gbits/sec  945             sender
[  5]   0.00-10.00  sec  5.99 GBytes  5.14 Gbits/sec                  receiver
```

Note these metrics are also at iperf3 server __log__:

```bash
☩ k logs nbox1
-----------------------------------------------------------
Server listening on 5555 (test #1)
-----------------------------------------------------------
Accepted connection from 10.244.182.130, port 33168
[  5] local 10.244.182.128 port 5555 connected to 10.244.182.130 port 33172
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  4.38 GBytes  37.6 Gbits/sec
[  5]   1.00-2.00   sec  4.72 GBytes  40.5 Gbits/sec
[  5]   2.00-3.00   sec  4.64 GBytes  39.8 Gbits/sec
[  5]   3.00-4.00   sec  4.75 GBytes  40.8 Gbits/sec
[  5]   4.00-5.00   sec  4.57 GBytes  39.2 Gbits/sec
[  5]   5.00-6.00   sec  4.39 GBytes  37.8 Gbits/sec
[  5]   6.00-7.00   sec  4.46 GBytes  38.3 Gbits/sec
[  5]   7.00-8.00   sec  4.38 GBytes  37.7 Gbits/sec
[  5]   8.00-9.00   sec  4.31 GBytes  37.0 Gbits/sec
[  5]   9.00-10.00  sec  4.35 GBytes  37.4 Gbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-10.00  sec  45.0 GBytes  38.6 Gbits/sec                  receiver
```




## Box for Debugging

```bash
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

__All tools__

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