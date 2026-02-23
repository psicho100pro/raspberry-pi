nano pihole_led_monitor.c

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/inotify.h>

#define LOG_PATH "/var/log/pihole/pihole.log"
#define EVENT_SIZE (sizeof(struct inotify_event))
#define BUF_LEN (1024 * (EVENT_SIZE + 16))

int fd_pwr = -1;
int fd_act = -1;

void blink(int led_fd) {
    if (led_fd < 0) return;

    pwrite(led_fd, "1", 1, 0);
    usleep(15000);
    
    pwrite(led_fd, "0", 1, 0);
    usleep(25000);
}

int main() {
    int inotify_fd, wd;
    char buffer[BUF_LEN];
    FILE *fp;
    char line[1024];

    system("echo none > /sys/class/leds/PWR/trigger");
    system("echo none > /sys/class/leds/ACT/trigger");

    fd_pwr = open("/sys/class/leds/PWR/brightness", O_WRONLY);
    fd_act = open("/sys/class/leds/ACT/brightness", O_WRONLY);

    inotify_fd = inotify_init();
    if (inotify_fd < 0) {
        perror("inotify_init");
        return 1;
    }

    while (1) {
        fp = fopen(LOG_PATH, "r");
        if (!fp) {
            sleep(1);
            continue;
        }

        fseek(fp, 0, SEEK_END);

        wd = inotify_add_watch(inotify_fd, LOG_PATH, IN_MODIFY | IN_MOVE_SELF | IN_IGNORED);

        int run_watch = 1;
        while (run_watch) {
            int length = read(inotify_fd, buffer, BUF_LEN);
            if (length < 0) break;

            int i = 0;
            while (i < length) {
                struct inotify_event *event = (struct inotify_event *)&buffer[i];
                
                if (event->mask & IN_MODIFY) {
                    while (fgets(line, sizeof(line), fp)) {
                        if (strstr(line, "blocked") || strstr(line, "gravity")) {
                            blink(fd_pwr);
                        } else if (strstr(line, "query[") || strstr(line, "forwarded") || 
                                   strstr(line, "cached") || strstr(line, "reply")) {
                            blink(fd_act);
                        }
                    }
                    clearerr(fp); 
                }
                
                if ((event->mask & IN_MOVE_SELF) || (event->mask & IN_IGNORED)) {
                    run_watch = 0;
                }
                i += EVENT_SIZE + event->len;
            }
        }
        
        inotify_rm_watch(inotify_fd, wd);
        fclose(fp);
        usleep(100000); // Kratka pauza pred restartem watcheru
    }

    close(inotify_fd);
    if (fd_pwr >= 0) close(fd_pwr);
    if (fd_act >= 0) close(fd_act);
    return 0;
}

gcc -O2 pihole_led_monitor.c -o pihole-led

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

