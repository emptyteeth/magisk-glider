#!/system/bin/sh

gldhome="/data/glider"

#remove binary
[ ! -d "$gldhome/bin" ] || rm -rf "$gldhome/bin"

#empty proxy.list
[ ! -f "$gldhome/rules.d/proxy.list" ] || echo "#" >$gldhome/rules.d/proxy.list

#remove tmp dir
[ ! -d "$gldhome/tmp" ] || rm -rf "$gldhome/tmp"

#keep everything else
