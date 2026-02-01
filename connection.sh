sudo nmcli connection modify "Wired connection 1" \
    ipv4.addresses 192.168.50.50/24 \
    ipv4.gateway 192.168.50.1 \
    ipv4.method manual \
    ipv4.route-metric 100
sudo nmcli connection up "Wired connection 1"

sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon
