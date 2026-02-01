sudo sed -i 's/#Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
sudo sed -i 's/#SystemMaxUse=.*/SystemMaxUse=100M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo bash -c 'echo "CONF_SWAPSIZE=1024" > /etc/dphys-swapfile'
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
sudo systemctl enable dphys-swapfile

sudo apt update && sudo apt install zram-tools -y
sudo bash -c 'cat << EOF > /etc/default/zramswap
ALGO=lz4
SIZE=400
PRIORITY=100
EOF'
sudo service zramswap restart

sudo sysctl -w vm.swappiness=10
sudo sed -i 's/vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf
