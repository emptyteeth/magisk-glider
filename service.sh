#!/system/bin/sh

#MODDIR=${0%/*}

abort() {
  echo "$1" >&2
  exit 1
}

precheck(){
  #check ipset kernel module
  for k in ip_set ip_set_hash_net xt_set
  do
    if [ ! -d /sys/module/${k} ] ; then
      abort "${k} kernel module required"
    fi
  done

  #check glider binary
  if [ ! -x $gldhome/bin/glider ] ;then
    abort "executable glider binary not found"
  fi

  #check config file
  if [ -z "$dnsport" ] ;then abort "parsing dnsport failed" ;fi
  if [ -z "$redirport" ] ;then abort "parsing redirport failed" ;fi
  if [ -z "$forwarder" ] ;then abort "at least one forwarder is required" ;fi
}

#glider
glider_up() {
  glider_down
  su net_admin -c "nohup $gldhome/bin/glider -config $gldhome/dns.conf >/dev/null 2>&1 &"
  su net_raw -c "nohup $gldhome/bin/glider -config $gldhome/proxy.conf >/dev/null 2>&1 &"
  echo "glider started"
}

glider_down() {
  if pidof glider >/dev/null ;then
    killall -w glider
    echo "glider stopped"
  fi
}

#iptable rules
rules_up() {
    rules_down
    #create GLIDER chain
    iptables -t nat -N GLIDER
    #dnat tg set
    iptables -t nat -A GLIDER -p tcp -m set --match-set tg dst -j DNAT --to-destination 127.0.0.1:${redirport}
    #dnat glider set
    iptables -t nat -A GLIDER -p tcp -m set --match-set glider dst -j DNAT --to-destination 127.0.0.1:${redirport}
    #dnat dns
    iptables -t nat -A GLIDER -p udp -m owner ! --uid-owner net_admin --dport 53 -j DNAT --to-destination 127.0.0.1:${dnsport}
    #apply to OUTPUT chain
    iptables -t nat -A OUTPUT -j GLIDER
    echo "iptable rules loaded"
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
    echo "iptable rules unloaded"
}

############ main start ############
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done

gldhome="/data/glider"
dnsport=$(sed -nr 's/^\s*dns=.*:([0-9]+)$/\1/p' <${gldhome}/dns.conf | head -n1)
redirport=$(sed -nr 's/^\s*listen=redir.*:([0-9]+)$/\1/p' <${gldhome}/proxy.conf | head -n1)
forwarder=$(sed -nr 's/^\s*forward=(.+:\/\/.+)$/\1/p' <${gldhome}/proxy.conf)

if [ -z "$1" ];then
  precheck
  glider_up
  sleep 2
  rules_up
elif [ "$1" = "down" ];then
  glider_down
  rules_down
fi
