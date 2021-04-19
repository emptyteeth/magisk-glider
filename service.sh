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

  #check ipt2socks binary
  if [ ! -x $gldhome/bin/ipt2socks ] ;then
    abort "executable ipt2socks binary not found"
  fi

  #check config file
  if [ -z "$dnsport" ] ;then abort "parsing dns port failed" ;fi
  if [ -z "$forwarder" ] ;then abort "at least one forwarder is required" ;fi
  if [ -z "$s5port" ] ;then abort "parsing socks5 port failed" ;fi
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

#ipt2socks
ipt2socks_up() {
  ipt2socks_down
  su net_admin -c "nohup $gldhome/bin/ipt2socks -s 127.0.0.1 -p ${s5port} -4 -R -l ${redirport} >/dev/null 2>&1 &"
  echo "ipt2socks started"
}

ipt2socks_down() {
  if pidof ipt2socks >/dev/null ;then
    killall -w ipt2socks
    echo "ipt2socks stopped"
  fi
}

#iptable rules
rules_up() {
    rules_down

    #ipt2socks chain
    iptables -t nat -N ipt2socks
    iptables -t nat -A ipt2socks -p tcp -m set --match-set glider dst -j REDIRECT --to-port ${redirport}

    #gliderdns chain
    iptables -t nat -N gliderdns
    iptables -t nat -A gliderdns -p udp -m owner ! --uid-owner net_admin --dport 53 -j DNAT --to-destination 127.0.0.1:${dnsport}

    #apply to OUTPUT chain
    iptables -t nat -A OUTPUT -j ipt2socks
    iptables -t nat -A OUTPUT -j gliderdns
    #apply to PREROUTING chain
    iptables -t nat -A PREROUTING -j ipt2socks

    #udp
    ip route add local default dev lo table 200
    ip rule add fwmark 598334 table 200

    #ipt2socks chain
    iptables -t mangle -N ipt2socks
    iptables -t mangle -A ipt2socks -m mark --mark 598334 -j RETURN
    iptables -t mangle -A ipt2socks -p udp -m set --match-set glider dst -j MARK --set-mark 598334

    #ipt2socks_prerouting chain
    iptables -t mangle -N ipt2socks_prerouting
    iptables -t mangle -A ipt2socks_prerouting -p udp -m mark --mark 598334 -j TPROXY --on-ip 127.0.0.1 --on-port ${redirport}

    #apply to OUTPUT chain
    iptables -t mangle -A OUTPUT -j ipt2socks
    #apply to PREROUTING chain
    iptables -t mangle -A PREROUTING -j ipt2socks
    iptables -t mangle -A PREROUTING -j ipt2socks_prerouting

    echo "iptable rules loaded"
}

rules_down() {
    #rules deduplication
    iptables-save -t nat | uniq | iptables-restore

    #clean OUTPUT chain
    iptables -t nat -D OUTPUT -j gliderdns 2>/dev/null
    iptables -t nat -D OUTPUT -j ipt2socks 2>/dev/null

    #clean PREROUTING chain
    iptables -t nat -D PREROUTING -j ipt2socks 2>/dev/null

    #delete ipt2socks chain
    iptables -t nat -F ipt2socks 2>/dev/null
    iptables -t nat -X ipt2socks 2>/dev/null

    #delete gliderdns chain
    iptables -t nat -F gliderdns 2>/dev/null
    iptables -t nat -X gliderdns 2>/dev/null
    
    #udp
    ip rule del fwmark 598334 table 200 2>/dev/null
    ip route del local default dev lo table 200 2>/dev/null

    #rules deduplication
    iptables-save -t mangle | uniq | iptables-restore

    #clean PREROUTING chain
    iptables -t mangle -D PREROUTING -j ipt2socks_prerouting 2>/dev/null
    iptables -t mangle -D PREROUTING -j ipt2socks 2>/dev/null
    #clean OUTPUT chain
    iptables -t mangle -D OUTPUT -j ipt2socks 2>/dev/null

    #delete ipt2socks_prerouting chain
    iptables -t mangle -F ipt2socks_prerouting 2>/dev/null
    iptables -t mangle -X ipt2socks_prerouting 2>/dev/null

    #delete ipt2socks chain
    iptables -t mangle -F ipt2socks 2>/dev/null
    iptables -t mangle -X ipt2socks 2>/dev/null

    echo "iptable rules unloaded"
}

############ main start ############
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done

gldhome="/data/glider"
dnsport=$(sed -nr 's/^\s*dns=.*:([0-9]+)$/\1/p' <${gldhome}/glider.conf | head -n1)
redirport="52052"
forwarder=$(sed -nr 's/^\s*forward=(.+:\/\/.+)$/\1/p' <${gldhome}/rules.d/proxy.rule)
s5port=$(sed -nr 's/^\s*listen=socks5.*:([0-9]+)$/\1/p' <${gldhome}/glider.conf | head -n1)

if [ -z "$1" ];then
  precheck
  glider_up
  ipt2socks_up
  sleep 3
  rules_up
elif [ "$1" = "down" ];then
  glider_down
  ipt2socks_down
  rules_down
fi
