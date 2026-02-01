sudo bash -c 'cat <<EOF >> /boot/firmware/config.txt
dtoverlay=disable-wifi
dtoverlay=disable-bt
hdmi_ignore_hotplug=1
hdmi_blanking=2
dtparam=watchdog=on
EOF'
