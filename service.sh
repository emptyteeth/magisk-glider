#!/system/bin/sh

#MODDIR=${0%/*}

precheck(){
  #check ipset kernel module
  for k in ip_set ip_set_hash_net xt_set
  do
    if [ ! -d /sys/module/${k} ] ; then
      echo "${k} kernel module required" >&2
      exit 1
    fi
  done

  #check glider binary
  if ! type glider >/dev/null 2>&1 ;then
    echo "glider binary not found" >&2
    exit 1
  fi

  #check config file
  if [ -z "$dnsport" ] ;then echo "parsing dnsport failed" >&2 && exit 1 ;fi
  if [ -z "$redirport" ] ;then echo "parsing redirport failed" >&2 && exit 1 ;fi
  if [ -z "$forwarder" ] ;then echo "at least one forwarder is required" >&2 && exit 1 ;fi
}

#glider
glider_up() {
  glider_down
  su - net_admin -c nohup glider -config /data/glider/dns.conf >/dev/null 2>&1 &
  su - net_raw -c nohup glider -config /data/glider/proxy.conf >/dev/null 2>&1 &
}

glider_down() {
  killall -w glider 2>/dev/null
}

#iptable rules
rules_up() {
    rules_down
    #create GLIDER chain
    iptables -t nat -N GLIDER
    #redirect tg set
    iptables -t nat -A GLIDER -p tcp -m set --match-set tg dst -j REDIRECT --to-port ${redirport}
    #redirect glider set
    iptables -t nat -A GLIDER -p tcp -m set --match-set glider dst -j REDIRECT --to-port ${redirport}
    #dnat dns
    iptables -t nat -A GLIDER -p udp -m owner ! --uid-owner net_admin --dport 53 -j DNAT --to-destination 127.0.0.1:${dnsport}
    #apply to OUTPUT chain
    iptables -t nat -A OUTPUT -j GLIDER
    #narrow down redirport access
    iptables -A INPUT ! -i lo -p tcp --dport ${redirport} -j DROP
}

rules_down() {
    #rules deduplication
    iptables-save -t nat | uniq | iptables-restore
    #stop apply to OUTPUT chain
    iptables -t nat -D OUTPUT -j GLIDER 2>/dev/null
    #flush GLIDER chain
    iptables -t nat -F GLIDER 2>/dev/null
    #delete GLIDER chain
    iptables -t nat -X GLIDER 2>/dev/null
    #stop narrow down redirport access
    iptables -D INPUT ! -i lo -p tcp --dport ${redirport} -j DROP 2>/dev/null
}

############ main start ############
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done

gldconf="/data/glider"
dnsport=$(sed -nr 's/^\s*dns=.*:([0-9]+)$/\1/p' <${gldconf}/dns.conf | head -n1)
redirport=$(sed -nr 's/^\s*listen=redir.*:([0-9]+)$/\1/p' <${gldconf}/proxy.conf | head -n1)
forwarder=$(sed -nr 's/^\s*forward=(.+:\/\/.+)$/\1/p' <${gldconf}/proxy.conf)

if [ -z "$1" ];then
  precheck
  glider_up
  sleep 1
  rules_up
elif [ "$1" = "down" ];then
  glider_down
  rules_down
fi
