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
  icurl="curl --retry 2 --connect-timeout 5"
  if ! type curl >/dev/null 2>&1 ; then
    unzip -j -o "${ZIPFILE}" 'binary/curl' -d ${TMPDIR} >&2
    chmod 755 ${TMPDIR}/curl
    icurl="${TMPDIR}/curl --retry 2 --connect-timeout 5"
  fi
}

glider_install(){
  # get remote version
  ui_print "checking glider release version"
  gldurl="https://github.com/nadoo/glider/releases"
  gldver=$($icurl -Is $gldurl/latest | sed -nr 's/^location.*\/tag\/v(.*)\r$/\1/pi')
  if [ -z $gldver ] ;then abort "get remote glider version failed" ;fi
  ui_print "glider release version: $gldver"

  # get local version
  if [ -x $gldhome/bin/glider ] ; then
    gldver_local=$($gldhome/bin/glider -h | sed '2!d' | cut -d' ' -f2)
    ui_print "glider local version: $gldver_local"
    if [ $gldver_local = $gldver ] ;then return ;fi
  fi

  ui_print "downloading glider v${gldver}"
  mkdir -p "$gldhome/tmp"
  mkdir -p "$gldhome/bin"

  # assemble download url
  dlprefix="${gldurl}/download/v${gldver}"
  gldfilename="glider_${gldver}_linux_${ARCH}.tar.gz"
  gldchksumfilename="glider_${gldver}_checksums.txt"

  # download glider
  $icurl -Ls "$dlprefix/$gldfilename" -o "$gldhome/tmp/$gldfilename"
  iferr "download glider failed."

  # match checksum
  ui_print "verifing sha256 checksum"
  $icurl -Ls "$dlprefix/$gldchksumfilename" | grep "$(cd $gldhome/tmp && sha256sum $gldfilename)" >&2
  iferr "checksum mismatched."
  ui_print "checksum matched"

  # extract and move glider binary
  ui_print "extracting binary"
  tar -xf "$gldhome/tmp/$gldfilename" -C "$gldhome/tmp" --strip 1
  iferr "extract glider failed."
  mv "$gldhome/tmp/glider" "$gldhome/bin/glider"
  rm -rf "$gldhome/tmp"
}

config_install(){
  # install config file
  mkdir -p $gldhome/rules.d
  ui_print "installing configuration files(not overwriting)"
  unzip -j -n "${ZIPFILE}" 'conf/*.conf' -d $gldhome >&2
  unzip -j -n "${ZIPFILE}" 'conf/rules.d/*' -d $gldhome/rules.d >&2
}

uplist(){
  # update proxy-list
  ui_print "updating proxy-list"
  listurl="https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt"
  $icurl -Ls $listurl -o $gldhome/rules.d/proxy.list
  iferr "update proxy-list failed"
  sed -i '/^regexp:/d;s/^full://g;s/^/domain=&/g' $gldhome/rules.d/proxy.list
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
  set_perm_recursive $gldhome net_admin root 0770 0660
  set_perm $gldhome/bin/glider root root 0755
  # some notes
  ui_print "installation succeeded"
  ui_print "before reboot:"
  ui_print "1. turn off android private dns"
  ui_print "2. turn off ipv6 in APN setting"
  ui_print "3. drop your forwarder into /data/glider/rules.d/proxy.rule"
}

############ main start ############
gldhome="/data/glider"
precheck
glider_install
config_install
uplist
paperwork
