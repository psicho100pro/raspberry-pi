sudo nano /usr/local/bin/update_pi.sh

sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean
#sudo apt install --only-upgrade unbound
sudo systemctl restart unbound
sudo pihole -up
sudo /opt/AdGuardHome/AdGuardHome --update
systemctl reload rspamd

sleep 30
systemctl is-active --quiet unbound && \
systemctl is-active --quiet AdGuardHome && \
systemctl is-active --quiet pihole-FTL && \
systemctl is-active --quiet redis-server && \
systemctl is-active --quiet rspamd && \
systemctl is-active --quiet rspamd-iscan && \
mountpoint -q /zaloha && \
sudo rsync -aAX --delete \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/zaloha/*"} \
    / /zaloha/ > /dev/null 2>&1

sudo chmod +x /usr/local/bin/update_pi.sh

(sudo crontab -l 2>/dev/null; echo "30 2 * * 6 /usr/local/bin/update_pi.sh") | sudo crontab -
