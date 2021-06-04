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
  if [ -z "$dnsport" ] ;then abort "parsing dns port failed" ;fi
  if [ -z "$redirport" ] ;then abort "parsing redir port failed" ;fi
  if [ -z "$forwarder" ] ;then abort "at least one forwarder is required" ;fi
}

#glider
glider_up() {
  glider_down
  su net_admin -c "nohup $gldhome/bin/glider -config $gldhome/glider.conf >/dev/null 2>&1 &"
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
    if ! pidof glider >/dev/null ;then abort "glider is not running, stop loading rules";fi

    #glider chain
    iptables -t nat -N glider
    iptables -t nat -A glider -p tcp -m set --match-set glider dst -j REDIRECT --to-port ${redirport}

    #gliderdns chain
    iptables -t nat -N gliderdns
    iptables -t nat -A gliderdns -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:${dnsport}

    #apply to OUTPUT chain
    iptables -t nat -A OUTPUT -j glider
    iptables -t nat -A OUTPUT -j gliderdns
    #apply to PREROUTING chain
    iptables -t nat -A PREROUTING -j glider

    echo "iptable rules loaded"
}

rules_down() {
    #rules deduplication
    iptables-save -t nat | uniq | iptables-restore

    #clean OUTPUT chain
    iptables -t nat -D OUTPUT -j gliderdns 2>/dev/null
    iptables -t nat -D OUTPUT -j glider 2>/dev/null

    #clean PREROUTING chain
    iptables -t nat -D PREROUTING -j glider 2>/dev/null

    #delete glider chain
    iptables -t nat -F glider 2>/dev/null
    iptables -t nat -X glider 2>/dev/null

    #delete gliderdns chain
    iptables -t nat -F gliderdns 2>/dev/null
    iptables -t nat -X gliderdns 2>/dev/null

    echo "iptable rules unloaded"
}

############ main start ############
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done

gldhome="/data/glider"
dnsport=$(sed -nr 's/^\s*dns=.*:([0-9]+)$/\1/p' <${gldhome}/glider.conf | head -n1)
redirport=$(sed -nr 's/^\s*listen=redir.*:([0-9]+)$/\1/p' <${gldhome}/glider.conf | head -n1)
forwarder=$(sed -nr 's/^\s*forward=(.+:\/\/.+)$/\1/p' <${gldhome}/rules.d/proxy.rule)

if [ -z "$1" ];then
  precheck
  glider_up
  sleep 3
  rules_up
elif [ "$1" = "down" ];then
  glider_down
  rules_down
fi
