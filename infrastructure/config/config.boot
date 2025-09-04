firewall {
    all-ping enable
    broadcast-ping disable
    ipv6-name WANv6_IN {
        default-action drop
        description "WAN inbound traffic forwarded to LAN"
        enable-default-log
        rule 10 {
            action accept
            description "Allow established/related sessions"
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
    }
    ipv6-name WANv6_LOCAL {
        default-action drop
        description "WAN inbound traffic to the router"
        enable-default-log
        rule 10 {
            action accept
            description "Allow established/related sessions"
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
        rule 30 {
            action accept
            description "Allow IPv6 icmp"
            protocol ipv6-icmp
        }
        rule 40 {
            action accept
            description "allow dhcpv6"
            destination {
                port 546
            }
            protocol udp
            source {
                port 547
            }
        }
    }
    ipv6-receive-redirects disable
    ipv6-src-route disable
    ip-src-route disable
    log-martians enable
    name WAN_IN {
        default-action drop
        description "WAN to internal"
        rule 10 {
            action accept
            description "Allow established/related"
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
    }
    name WAN_LOCAL {
        default-action drop
        description "WAN to router"
        rule 10 {
            action accept
            description "Allow established/related"
            state {
                established enable
                related enable
            }
        }
        rule 20 {
            action drop
            description "Drop invalid state"
            state {
                invalid enable
            }
        }
    }
    options {
        mss-clamp {
            mss 1412
        }
    }
    receive-redirects disable
    send-redirects enable
    source-validation disable
    syn-cookies enable
}
interfaces {
    bridge br0 {
        address 192.168.8.1/24
        aging 300
        bridged-conntrack disable
        description "Local Bridge"
        hello-time 2
        max-age 20
        priority 32768
        promiscuous enable
        stp false
    }
    ethernet eth0 {
        duplex auto
        speed auto
        vif 35 {
            description "Internet (PPPoE)"
            pppoe 0 {
                default-route auto
                firewall {
                    in {
                        ipv6-name WANv6_IN
                        name WAN_IN
                    }
                    local {
                        ipv6-name WANv6_LOCAL
                        name WAN_LOCAL
                    }
                }
                mtu 1492
                name-server auto
                password PDAC5S
                user-id t008_gftth_ngantvk0
            }
        }
    }
    ethernet eth1 {
        bridge-group {
            bridge br0
        }
        description "Local Bridge GF"
        duplex auto
        speed auto
    }
    ethernet eth2 {
        bridge-group {
            bridge br0
        }
        description "Local Bridge 4F"
        duplex auto
        speed auto
    }
    ethernet eth3 {
        bridge-group {
            bridge br0
        }
        description "Local Bridge 6F"
        duplex auto
        speed auto
    }
    ethernet eth4 {
        bridge-group {
            bridge br0
        }
        duplex auto
        speed auto
    }
    ethernet eth5 {
        bridge-group {
            bridge br0
        }
        duplex auto
        speed auto
    }
    ethernet eth6 {
        bridge-group {
            bridge br0
        }
        duplex auto
        speed auto
    }
    ethernet eth7 {
        bridge-group {
            bridge br0
        }
        duplex auto
        speed auto
    }
    loopback lo {
    }
}
protocols {
    bgp 65008 {
        neighbor 192.168.8.21 {
            description k3s-control-1-metallb
            remote-as 65009
            soft-reconfiguration {
                inbound
            }
        }
        neighbor 192.168.8.22 {
            description k3s-control-2-metallb
            remote-as 65009
            soft-reconfiguration {
                inbound
            }
        }
        parameters {
            router-id 192.168.8.1
        }
        redistribute {
            connected {
            }
            static {
            }
        }
    }
    static {
        route 10.42.0.0/16 {
            next-hop 192.168.8.21 {
                distance 120
            }
            next-hop 192.168.8.22 {
            }
            next-hop 192.168.8.23 {
            }
        }
        route 10.42.2.0/24 {
            next-hop 192.168.8.11 {
                distance 110
            }
        }
        route 10.42.3.0/24 {
            next-hop 192.168.8.12 {
                distance 110
            }
        }
        route 10.42.4.0/24 {
            next-hop 192.168.8.13 {
                distance 110
            }
        }
        route 192.168.80.0/24 {
            next-hop 192.168.8.21 {
                distance 250
            }
            next-hop 192.168.8.22 {
                distance 251
            }
        }
    }
}
service {
    dhcp-server {
        disabled false
        hostfile-update disable
        shared-network-name LAN_BR {
            authoritative enable
            subnet 192.168.8.0/24 {
                default-router 192.168.8.1
                dns-server 192.168.8.1
                lease 86400
                start 192.168.8.38 {
                    stop 192.168.8.243
                }
                static-mapping k3s-control-1 {
                    ip-address 192.168.8.21
                    mac-address 52:54:00:08:6d:21
                }
                static-mapping k3s-control-2 {
                    ip-address 192.168.8.22
                    mac-address 52:54:00:08:6d:22
                }
                static-mapping k3s-control-3 {
                    ip-address 192.168.8.23
                    mac-address 52:54:00:08:6d:23
                }
                static-mapping k3s-control-4 {
                    ip-address 192.168.8.24
                    mac-address 52:54:00:08:6d:24
                }
                static-mapping k3s-control-5 {
                    ip-address 192.168.8.25
                    mac-address 52:54:00:08:6d:25
                }
                static-mapping k3s-worker-1 {
                    ip-address 192.168.8.11
                    mac-address 52:54:00:08:6d:11
                }
                static-mapping k3s-worker-2 {
                    ip-address 192.168.8.12
                    mac-address 52:54:00:08:6d:12
                }
                static-mapping k3s-worker-3 {
                    ip-address 192.168.8.13
                    mac-address 52:54:00:08:6d:13
                }
                static-mapping k3s-worker-4 {
                    ip-address 192.168.8.14
                    mac-address 52:54:00:08:6d:14
                }
                static-mapping k3s-worker-5 {
                    ip-address 192.168.8.15
                    mac-address 52:54:00:08:6d:15
                }
                static-mapping k3s-worker-6 {
                    ip-address 192.168.8.16
                    mac-address 52:54:00:08:6d:16
                }
                static-mapping k3s-worker-7 {
                    ip-address 192.168.8.17
                    mac-address 52:54:00:08:6d:17
                }
                static-mapping k3s-worker-8 {
                    ip-address 192.168.8.18
                    mac-address 52:54:00:08:6d:18
                }
                static-mapping k3s-worker-9 {
                    ip-address 192.168.8.19
                    mac-address 52:54:00:08:6d:19
                }
                static-mapping mp700-lan {
                    ip-address 192.168.8.27
                    mac-address 74:56:3c:1c:01:56
                }
                static-mapping mp700-wlan {
                    ip-address 192.168.8.28
                    mac-address b8:09:8a:91:b4:24
                }
                static-mapping s200-lan {
                    ip-address 192.168.8.26
                    mac-address 00:e0:4c:98:3a:a3
                }
                static-mapping s200-wlan {
                    ip-address 192.168.8.29
                    mac-address 18:4f:32:f4:95:87
                }
            }
        }
        static-arp disable
        use-dnsmasq disable
    }
    dns {
        forwarding {
            cache-size 10000
            force-public-dns-boost
            listen-on br0
        }
    }
    gui {
        http-port 80
        https-port 443
        older-ciphers enable
    }
    nat {
        rule 5010 {
            description "masquerade for WAN"
            outbound-interface pppoe0
            type masquerade
        }
    }
    ssh {
        port 22
        protocol-version v2
    }
    unms {
    }
}
system {
    analytics-handler {
        send-analytics-report false
    }
    crash-handler {
        send-crash-report false
    }
    host-name EdgeRouter-Pro-8-Port
    login {
        user ubnt {
            authentication {
                encrypted-password $5$ATnQWn.rQMp6O2cn$FcehZQAPhU2zCb/XC42Sb8XFOAJAmDVHPhfguLms9Q2
            }
            level admin
        }
    }
    ntp {
        server 0.ubnt.pool.ntp.org {
        }
        server 1.ubnt.pool.ntp.org {
        }
        server 2.ubnt.pool.ntp.org {
        }
        server 3.ubnt.pool.ntp.org {
        }
    }
    offload {
        hwnat disable
        ipv4 {
            forwarding enable
            pppoe enable
        }
    }
    package {
        repository tailscale {
            components main
            distribution stretch
            password ""
            url "[signed-by=/usr/share/keyrings/tailscale-stretch-stable.gpg] https://pkgs.tailscale.com/stable/debian"
            username ""
        }
    }
    syslog {
        global {
            facility all {
                level notice
            }
            facility protocols {
                level debug
            }
        }
    }
    time-zone UTC
}


/* Warning: Do not remove the following line. */
/* === vyatta-config-version: "config-management@1:conntrack@1:cron@1:dhcp-relay@1:dhcp-server@4:firewall@5:ipsec@5:nat@3:qos@1:quagga@2:suspend@1:system@5:ubnt-l2tp@1:ubnt-pptp@1:ubnt-udapi-server@1:ubnt-unms@2:ubnt-util@1:vrrp@1:vyatta-netflow@1:webgui@1:webproxy@1:zone-policy@1" === */
/* Release version: v2.0.9-hotfix.7.5622762.230615.1131 */
