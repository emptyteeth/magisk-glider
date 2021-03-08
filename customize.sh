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
  # get remote version
  gldurl="https://github.com/nadoo/glider/releases"
  gldver=$($icurl -Is $gldurl/latest | sed -nr 's/^location.*\/tag\/v(.*)\r$/\1/pi')
  if [ -z $gldver ] ;then abort "get remote glider version failed" ;fi
  ui_print "glider remote version: $gldver"

  # get local version
  if [ -x $gldhome/bin/glider ] ; then
    gldver_local=$($gldhome/bin/glider --help | sed '2!d' | cut -d' ' -f2)
    ui_print "glider local version: $gldver_local"
    if [ $gldver_local = $gldver ] ;then return ;fi
  fi

  ui_print "downloading glider v${gldver}"
  gldlink="${gldurl}/download/v${gldver}/glider_${gldver}_linux_${ARCH}.tar.gz"
  mkdir -p $gldhome/tmp
  mkdir -p $gldhome/bin

  $icurl -Ls $gldlink -o $gldhome/tmp/dl.tar.gz
  iferr "download glider failed."

  tar -xf $gldhome/tmp/dl.tar.gz -C $gldhome/tmp --strip 1
  iferr "extract glider failed."

  mv $gldhome/tmp/glider $gldhome/bin/glider
  iferr "extracted glider not found."
  rm -rf $gldhome/tmp
}

ipt2socks_install(){
if [ ! -e $gldhome/bin/ipt2socks ] ; then
  unzip -j -o "${ZIPFILE}" 'binary/ipt2socks' -d $gldhome/bin >&2
fi
}

config_install(){
  # install config file
  mkdir -p $gldhome/rules.d
  ui_print "copy config files(not overwriting)"
  unzip -j -n "${ZIPFILE}" 'conf/*.conf' -d $gldhome >&2
  unzip -j -n "${ZIPFILE}" 'conf/rules.d/*' -d $gldhome/rules.d >&2
}

uplist(){
  # update proxy-list
  ui_print "updating proxy-list"
  listurl="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt"
  $icurl -Ls $listurl -o $gldhome/rules.d/proxy.list
  iferr "update proxy-list failed"
  sed -i '/^regexp:/d;s/^/domain=&/g' $gldhome/rules.d/proxy.list
}

paperwork(){
  # install scripts
  unzip -j -o "${ZIPFILE}" 'service.sh' -d $MODPATH >&2
  unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d $MODPATH >&2
  unzip -j -o "${ZIPFILE}" 'module.prop' -d $MODPATH >&2
  # set permissions
  ui_print "setting permissions"
  set_perm_recursive $MODPATH root root 0750 0750
  set_perm $MODPATH/module.prop root root 0640
  set_perm_recursive $gldhome net_admin net_raw 0770 0660
  set_perm $gldhome/bin/glider root root 0755
  set_perm $gldhome/bin/ipt2socks root root 0755
  # some notes
  ui_print "installation succeeded"
  ui_print "before reboot:"
  ui_print "1. turn off android private dns"
  ui_print "2. turn off ipv6 in APN setting"
  ui_print "3. drop your forwarder into /data/glider/proxy.conf"
}

############ main start ############
gldhome="/data/glider"
precheck
glider_install
ipt2socks_install
config_install
uplist
paperwork
