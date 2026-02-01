sudo nano pihole-led.c

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

void blink(const char* led) {
    char path[64];
    snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", led);
    int fd = open(path, O_WRONLY);
    if (fd >= 0) {
        write(fd, "1", 1); close(fd);
        usleep(50000); 
        fd = open(path, O_WRONLY);
        if (fd >= 0) {
            write(fd, "0", 1); close(fd);
        }
    }
}

int main() {
    FILE *fp;
    char line[1024];
    struct stat st;
    long last_size = 0;

    system("echo none > /sys/class/leds/PWR/trigger");
    system("echo none > /sys/class/leds/ACT/trigger");

    while (1) {
        fp = fopen("/var/log/pihole/pihole.log", "r");
        if (!fp) { sleep(1); continue; }
        fseek(fp, 0, SEEK_END);
        last_size = ftell(fp);

        while (1) {
            if (fgets(line, sizeof(line), fp)) {
                if (strstr(line, "blocked") || strstr(line, "gravity")) {
                    blink("PWR");
                } 
                else if (strstr(line, "query[") || 
                         strstr(line, "cached") || 
                         strstr(line, "forwarded") || 
                         strstr(line, "reply")) {
                    blink("ACT");
                }
            } else {
                if (stat("/var/log/pihole/pihole.log", &st) == 0 && st.st_size < last_size) break;
                last_size = st.st_size;
                usleep(40000); 
                clearerr(fp);
            }
        }
        fclose(fp);
    }
    return 0;
}

gcc -O2 pihole-led.c -o pihole-led
sudo mv pihole-led /usr/local/bin/pihole-led
sudo chmod +x /usr/local/bin/pihole-led

sudo bash -c 'cat <<EOF > /etc/systemd/system/pihole-led.service
[Unit]
Description=Pi-hole Dual LED Monitor (PWR=Red, ACT=Green)
After=pihole-FTL.service

[Service]
ExecStart=/usr/local/bin/pihole-led
Restart=always
User=root
CPUSchedulingPolicy=idle

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl restart pihole-led.service

