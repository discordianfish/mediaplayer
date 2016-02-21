#!/bin/bash
set -euo pipefail

export PASS=${PASS:=root}
echo "root:$PASS" | chpasswd

# Firewall
## Set policy
iptables -F OUTPUT
iptables -F INPUT
iptables -F FORWARD

iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

## Allow SSH
iptables -A INPUT  -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED     -j ACCEPT

## Allow DNS (for connecting to VPN endpoint)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT

## Allow traffic via VPN and loopback interfaces
for i in lo tun0 tun1; do
  iptables -A INPUT  -i $i -j ACCEPT
  iptables -A OUTPUT -o $i -j ACCEPT
done

## Allow access to VPN servers
for ip in $(grep '^remote ' /etc/openvpn/vpn.ht.conf | cut -d' ' -f2 | sort | uniq \
  | while read host; do getent ahostsv4 "$host"; done | cut -d' ' -f1 | sort | uniq); do
  iptables -A INPUT  -s "$ip" -j ACCEPT
  iptables -A OUTPUT -d "$ip" -j ACCEPT
done

umask 077
cat <<EOF > /etc/vpn.pass
$VPN_USER
$VPN_PASS
EOF

systemctl start openvpn@vpn.ht
