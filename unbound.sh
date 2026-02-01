sudo apt update
sudo apt install -y unbound unbound-anchor

sudo mkdir -p /var/lib/unbound
sudo wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache

sudo -u unbound unbound-anchor -a "/var/lib/unbound/root.key"

sudo bash -c 'cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes

    access-control: 127.0.0.0/8 allow

    root-hints: "/var/lib/unbound/root.hints"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    num-threads: 2
    msg-cache-size: 128m
    rrset-cache-size: 256m
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2

    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes
    serve-expired: yes
    serve-expired-ttl: 3600

    statistics-interval: 0
    statistics-cumulative: no
    extended-statistics: yes

    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    qname-minimisation: yes
    use-caps-for-id: yes
    edns-buffer-size: 1232

remote-control:
    control-enable: yes
    control-interface: 127.0.0.1
    control-port: 8953
    server-key-file: "/etc/unbound/unbound_server.key"
    server-cert-file: "/etc/unbound/unbound_server.pem"
    control-key-file: "/etc/unbound/unbound_control.key"
    control-cert-file: "/etc/unbound/unbound_control.pem"
EOF'

sudo rm -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf

sudo chown -R unbound:unbound /var/lib/unbound
sudo chmod 644 /var/lib/unbound/root.key /var/lib/unbound/root.hints

sudo unbound-checkconf
sudo systemctl restart unbound

(crontab -l 2>/dev/null; echo "0 0 1 * * wget https://www.internic.net/domain/named.root -qO /var/lib/unbound/root.hints && chown unbound:unbound /var/lib/unbound/root.hints && systemctl restart unbound") | crontab -

