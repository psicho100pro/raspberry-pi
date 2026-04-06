sudo apt update && sudo apt install monit -y
sudo nano /etc/monit/monitrc
set daemon  240 
set httpd port 2812 and
    use address 192.168.x.x  # only accept connection from localhost (drop if you use M/Monit)
    allow 0.0.0.0/0        # allow localhost to connect to the server and
    allow :      # require user 'admin' with password 'monit'



check process unbound with matching "unbound"
    group dns
    start program = "/usr/bin/systemctl start unbound"
    stop program = "/usr/bin/systemctl stop unbound"

check process AdGuardHome with matching "AdGuardHome"
    group dns
    start program = "/usr/bin/systemctl start AdGuardHome"
    stop program = "/usr/bin/systemctl stop AdGuardHome"
    depends on unbound
    
check process pihole-FTL with matching "pihole-FTL"
    group dns
    start program = "/usr/bin/systemctl start pihole-FTL"
    stop program = "/usr/bin/systemctl stop pihole-FTL"
    depends on AdGuardHome

check process redis-server with matching "redis-server"
    group mail
    start program = "/usr/bin/systemctl start redis-server"
    stop program = "/usr/bin/systemctl stop redis-server"

check process rspamd with matching "rspamd"
    group mail
    start program = "/usr/bin/systemctl start rspamd"
    stop program = "/usr/bin/systemctl stop rspamd"
    depends on redis-server

check process rspamd-iscan with matching "rspamd-iscan"
    group mail
    start program = "/usr/bin/systemctl start rspamd-iscan"
    stop program = "/usr/bin/systemctl stop rspamd-iscan"
    depends on rspamd

check process fan-control with matching "fan"
    group hardware
    start program = "/usr/bin/systemctl start fan"
    stop program = "/usr/bin/systemctl stop fan"

check program pihole-led with path "/usr/bin/systemctl is-active pihole-led"
    group hardware
    start program = "/usr/bin/systemctl start pihole-led"
    stop program = "/usr/bin/systemctl stop pihole-led"

check process pihole-led with matching "^/usr/local/bin/pihole-led$"
    group hardware
    start program = "/usr/bin/systemctl start pihole-led"
    stop program = "/usr/bin/systemctl stop pihole-led"

sudo systemctl restart monit
