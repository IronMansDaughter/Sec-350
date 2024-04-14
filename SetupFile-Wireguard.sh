#!/bin/sh
# Updates and installs wireguard
sudo apt update
sudo apt install wireguard -y

# Setup the keys
sudo bash -c "
# Generate the required keypairs
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
wg genkey | tee /etc/wireguard/client_private_key | wg pubkey > /etc/wireguard/client_public_key
"

# Sudo into root shell and executes the following commands
sudo bash -c "
# Configures the servers config (the host you are running the script on)
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(sudo cat /etc/wireguard/server_private_key)
Address = 192.168.0.1/24
ListenPort = 51820
SaveConfig = true
PreUp = sysctl -w net.ipv4.ip_forward=1
PreUp = iptables -t nat -A PREROUTING -p tcp -d 192.168.0.1 --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PostDown = iptables -t nat -D PREROUTING -p tcp -d 192.168.0.1 --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PreUp = iptables -t nat -A POSTROUTING -o ens160 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ens160 -j MASQUERADE

[Peer]
PublicKey = $(sudo cat /etc/wireguard/client_public_key)
AllowedIPs = 192.168.0.2/32
EOF

# Configures the clients config 
cat > /etc/wireguard/client.conf << EOF
[Interface]
PrivateKey = $(sudo cat /etc/wireguard/client_private_key)
Address = 192.168.0.2/24
ListenPort = 51820

[Peer]
PublicKey = $(sudo cat /etc/wireguard/server_public_key)
AllowedIPs = 192.168.0.1/32
Endpoint = 10.0.17.125:51820
PersistentKeepalive = 25
EOF

# Sets the interface to be up
wg-quick up wg0
"

dcheck (){
	# https://dev.to/ifenna__/adding-colors-to-bash-scripts-48g4
	RED="\e[31m"
	GREEN="\e[32m"
	checkstatus=$(ip link show | grep wg0)
	[ -n "$checkstatus" ] && printf "\n${GREEN}SUCCESS: Wireguard interface is up! \n" || printf "\n${RED}ERROR: Wireguard interface does not exist! \n"
}

dcheck
