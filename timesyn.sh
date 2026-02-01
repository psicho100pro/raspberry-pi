#!/bin/bash
sudo bash -c 'cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=0.cz.pool.ntp.org 1.cz.pool.ntp.org
FallbackNTP=time.cloudflare.com time.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF'

sudo systemctl restart systemd-timesyncd
