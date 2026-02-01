sudo apt update && sudo apt install watchdog -y
sudo bash -c 'cat <<EOF > /etc/watchdog.conf
watchdog-device = /dev/watchdog
watchdog-timeout = 15
max-load-1 = 24
realtime = yes
priority = 1
EOF'
sudo systemctl enable --now watchdog
