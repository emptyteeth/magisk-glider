#!/sbin/sh

SKIPUNZIP=1

iferr() {
  if [ $? != 0 ]; then
  abort "$1"
  fi
}

precheck(){
  # detect arch
  if [ "$ARCH" != "arm64" ] ; then abort "arm64 only." ;fi
  # detect ipset
  for k in ip_set ip_set_hash_net xt_set
  do
    if [ ! -d /sys/module/${k} ] ;then abort "${k} kernel module required." ;fi
  done
  # detect curl
  icurl="curl"
  if ! type curl >/dev/null 2>&1 ; then
    unzip -j -o "${ZIPFILE}" 'binary/curl' -d ${TMPDIR} >&2
    chmod 755 ${TMPDIR}/curl
    icurl="${TMPDIR}/curl"
  fi
}

glider_install(){
  # install glider binary
  mkdir -p $MODPATH/system/bin
  gldurl="https://github.com/nadoo/glider/releases"
  gldver=$($icurl -Is $gldurl/latest | sed -nr 's/^location.*\/tag\/v(.*)\r$/\1/p')
  if [ -z $gldver ] ;then abort "get remote glider version failed" ;fi
  ui_print "downloading glider binary"
  gldlink="${gldurl}/download/v${gldver}/glider_${gldver}_linux_${ARCH}.tar.gz"
  # no clue why $TMPDIR not working
  mkdir -p $MODPATH/tmp
  $icurl -Ls $gldlink | tar -xz -C $MODPATH/tmp --strip 1
  iferr "download glider failed."
  mv $MODPATH/tmp/glider $MODPATH/system/bin/glider
  iferr "extracted glider not found."
  rm -rf $MODPATH/tmp
  set_perm $MODPATH/system/bin/glider root root 0755
}

config_install(){
  # install config file
  mkdir -p $gldconf/rules.d
  ui_print "copy config files(not overwriting)"
  unzip -j -n "${ZIPFILE}" 'conf/*.conf' -d $gldconf >&2
  unzip -j -n "${ZIPFILE}" 'conf/rules.d/*' -d $gldconf/rules.d >&2
  set_perm_recursive $gldconf net_admin net_raw 0750 0640
}

uplist(){
  # update proxy-list
  ui_print "updating proxy-list"
  listurl="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt"
  $icurl -Ls $listurl >$gldconf/rules.d/proxy.list
  iferr "update proxy-list failed"
  sed -i '/^regexp:/d;s/^/domain=&/g' $gldconf/rules.d/proxy.list
}

paperwork(){
  # install scripts
  unzip -j -o "${ZIPFILE}" 'service.sh' -d $MODPATH >&2
  unzip -j -o "${ZIPFILE}" 'module.prop' -d $MODPATH >&2
  # set permissions
  ui_print "set permissions"
  set_perm $MODPATH root root 0750
  set_perm $MODPATH/service.sh root root 0750
  set_perm $MODPATH/module.prop root root 0640
  # some notes
  ui_print "before reboot:"
  ui_print "1. turn off android private dns"
  ui_print "2. turn off ipv6 in APN setting"
  ui_print "3. drop your forwarder into /data/glider/proxy.conf"
}

############ main start ############
gldconf="/data/glider"
precheck
glider_install
config_install
uplist
paperwork
