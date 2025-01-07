# Enable bgp

Upload bgpd.conf to unifi bgp settings

# Check that it's working

`vtysh -c 'show ip bgp'` should result in something like:

```
root@:~# vtysh -c 'show ip bgp'
BGP table version is 14, local router ID is 192.168.1.1, vrf id 0
Default local pref 100, local AS 64601
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

    Network          Next Hop            Metric LocPrf Weight Path
 *  10.0.10.30/32    10.0.10.243(talos-worker-1)
                                                           0 64701 i
 *>                  10.0.10.120(talos-worker-0)
                                                           0 64701 i
 *  10.0.10.130/32   10.0.10.243(talos-worker-1)
                                                           0 64701 i
 *>                  10.0.10.120(talos-worker-0)
                                                           0 64701 i


Displayed  14 routes and 16 total paths
```

`netstat -ar` should result in something like:

```
root@:~# netstat -ar
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
10.0.10.30      talos-worker-0  255.255.255.255 UGH       0 0          0 br10
10.0.10.130     talos-worker-0  255.255.255.255 UGH       0 0          0 br10
```

Thanks to:

- https://www.map59.com/ubiquiti-udm-running-bgp/
- https://blog.v12n.io/how-to-get-bgp-working-on-a-unifi-dream-machine-pro/
