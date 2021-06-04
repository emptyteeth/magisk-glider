# magisk-glider

## Credits

- [nadoo](https://github.com/nadoo) for [glider](https://github.com/nadoo/glider)
- [Loyalsoldier](https://github.com/Loyalsoldier) for [proxy-list](https://github.com/Loyalsoldier/v2ray-rules-dat)
- [topjohnwu](https://github.com/topjohnwu) for [magisk](https://github.com/topjohnwu/Magisk)

## Requirements

- kernel module
  - IP_SET
  - IP_SET_HASH_NET
  - NETFILTER_XT_SET

## What does this module do

- Running glider (`glider.conf`)
  - transparent proxy
  - dns forwarding server
  - resolving proxy-list and custom domains via forwarder (`rules.d/proxy.rule`)
  - create ipset for proxy-list and custom domains (`rules.d/proxy.rule`)

- iptable rules
  - dnat dns traffic to dns forwarding server
  - redirect ipset tcp traffic to transparent proxy

>config dir: /data/glider/

## After install (required)

- turn off android private dns
- turn off ipv6 in APN setting
- drop your forwarder into `rules.d/proxy.rule`
  - at least one forwarder is required
  - more forwarder for high availability
  - example

    ```ini
    # SS proxy as forwarder
    forward=ss://method:pass@1.2.3.4:8443
    # vmess over ws over tls
    forward=tls://server.com:443,ws://@/PATH,vmess://UUID@?alterID=123
    ```

  - [more examples](https://github.com/nadoo/glider/blob/master/config/glider.conf.example#L81-L151)

- reboot and you're all set

## Customize (optional)

- upstream dns server
  - general

    ```ini
    # default general upstream dns server(tcp mode is required)
    # glider.conf
    dnsserver=223.5.5.5:53
    dnsserver=223.6.6.6:53
    ```

  - proxied

    ```ini
    # default proxied upstream dns server(tcp mode is required)
    # rules.d/proxy.rule
    dnsserver=1.1.1.1:53
    ```

- custom proxy domain/ip/CIDR
  - add to `rules.d/proxy-custom.list`

    ```ini
    ip=22.22.22.22
    cidr=192.168.1.0/24
    domain=example.com
    ```

- intranet domain
  - make a rule file with intranet dns server and domains

    ```ini
    # rules.d/intranet-office.rule
    # intranet dns server(tcp mode is required)
    dnsserver=10.10.10.1
    # intranet domains
    # anything under these domains will forward to intranet dns server
    domain=example.com
    ```

- custom dns record / dns blocking
  - add to `glider.conf`

    ```ini
    dnsrecord=my.example.com/10.10.10.10
    dnsrecord=ad.example.com/0.0.0.0
    ```

  - OR make a conf file and include it in `glider.conf`

    ```ini
    # glider.conf
    include=mydnsrecord.conf
    include=dnsblocking.conf

    # mydnsrecord.conf
    dnsrecord=my.example.com/10.10.10.10

    # dnsblocking.conf
    dnsrecord=ad.example.com/0.0.0.0
    ```

## Control

- running `service.sh` for restart
- running `service.sh down` for shutdown

## Update

- reinstall this module for update glider binary and proxy-list
  >reinstallation will not overwrite the current configuration file
