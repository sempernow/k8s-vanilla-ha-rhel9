#!/usr/bin/env bash
#########################################################
# keepalived : vrrp_script 
# - Must run as root
# - /etc/keepalived/check_apiserver.sh
# - Executed unless vIP is set externally (static).
#   - See : man keepalived.conf
#########################################################
errorExit(){ 
    echo "* * * $*" 1>&2
    exit 1
}

[[ $VIP ]]  || errorExit 'VIP is not set'
[[ $PORT ]] || errorExit 'PORT is not set'

url="https://$VIP:$PORT/"

# Test for a running haproxy process.
/usr/bin/killall -0 haproxy || errorExit 'haproxy process is not running'

# Test for HTTPS connection at entrypoint *only if this host has the vIP*.
ip -4 addr |grep "$VIP" && {
    systemctl is-active --quiet kubelet.service && {
        curl --silent --max-time 3 --insecure -o /dev/null "$url" ||
            errorExit "cURL reports error $? on GET $url"
    }
}

exit 0 
