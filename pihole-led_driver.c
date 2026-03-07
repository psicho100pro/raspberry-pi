nano pihole_led_monitor.c

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/inotify.h>
#include <pthread.h>
#include <signal.h>

#define LOG_PATH "/var/log/pihole/pihole.log"
#define EVENT_SIZE (sizeof(struct inotify_event))
#define BUF_LEN (16384 * (EVENT_SIZE + 16))
#define MAX_BLINKS 5 

volatile sig_atomic_t stop = 0;
volatile int queue_pwr = 0;
volatile int queue_act = 0;

int fd_pwr = -1;
int fd_act = -1;

void handle_signal(int sig) {
    stop = 1;
}

void* pwr_led_thread(void* arg) {
    while (!stop) {
        if (queue_pwr > 0) {
            queue_pwr--;
            if (fd_pwr >= 0) pwrite(fd_pwr, "1", 1, 0);
            usleep(40000); // Delší svit: 40ms
            if (fd_pwr >= 0) pwrite(fd_pwr, "0", 1, 0);
            usleep(80000); // Výraznější mezera: 80ms
        } else {
            usleep(10000); 
        }
    }
    return NULL;
}

void* act_led_thread(void* arg) {
    while (!stop) {
        if (queue_act > 0) {
            queue_act--;
            if (fd_act >= 0) pwrite(fd_act, "1", 1, 0);
            usleep(40000); // Delší svit: 40ms
            if (fd_act >= 0) pwrite(fd_act, "0", 1, 0);
            usleep(80000); // Výraznější mezera: 80ms
        } else {
            usleep(10000); 
        }
    }
    return NULL;
}

void init_leds() {
    system("echo none > /sys/class/leds/PWR/trigger");
    system("echo none > /sys/class/leds/ACT/trigger");
    fd_pwr = open("/sys/class/leds/PWR/brightness", O_WRONLY);
    fd_act = open("/sys/class/leds/ACT/brightness", O_WRONLY);
    if (fd_pwr >= 0) pwrite(fd_pwr, "0", 1, 0);
    if (fd_act >= 0) pwrite(fd_act, "0", 1, 0);
}

int main() {
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    init_leds();

    pthread_t thread_pwr, thread_act;
    pthread_create(&thread_pwr, NULL, pwr_led_thread, NULL);
    pthread_create(&thread_act, NULL, act_led_thread, NULL);

    int inotify_fd = inotify_init();
    if (inotify_fd < 0) return 1;

    char buffer[BUF_LEN];
    char line_buffer[4096];
    int line_ptr = 0;

    while (!stop) {
        int log_fd = open(LOG_PATH, O_RDONLY);
        if (log_fd < 0) {
            sleep(1);
            continue;
        }

        lseek(log_fd, 0, SEEK_END);
        int wd = inotify_add_watch(inotify_fd, LOG_PATH, IN_MODIFY | IN_MOVE_SELF);

        while (!stop) {
            int length = read(inotify_fd, buffer, BUF_LEN);
            if (length < 0) break;

            for (int i = 0; i < length; ) {
                struct inotify_event *ev = (struct inotify_event *)&buffer[i];
                if (ev->mask & IN_MODIFY) {
                    char read_chunk[8192];
                    ssize_t bytes_read;
                    while ((bytes_read = read(log_fd, read_chunk, sizeof(read_chunk))) > 0) {
                        for (ssize_t j = 0; j < bytes_read; j++) {
                            if (read_chunk[j] == '\n') {
                                line_buffer[line_ptr] = '\0';
                                
                                if (strstr(line_buffer, " blocked ") || 
                                    strstr(line_buffer, " gravity ") || 
                                    strstr(line_buffer, " regex ") || 
                                    strstr(line_buffer, "is 0.0.0.0")) {
                                    if (queue_pwr < MAX_BLINKS) queue_pwr++;
                                } 
                                else if (strstr(line_buffer, " reply ") || strstr(line_buffer, " cached ")) {
                                    if (!strstr(line_buffer, " 127.0.0.1") && !strstr(line_buffer, " localhost")) {
                                        if (queue_act < MAX_BLINKS) queue_act++;
                                    }
                                }
                                line_ptr = 0;
                            } else if (line_ptr < sizeof(line_buffer) - 1) {
                                line_buffer[line_ptr++] = read_chunk[j];
                            }
                        }
                    }
                }
                if (ev->mask & (IN_MOVE_SELF | IN_IGNORED)) goto reopen;
                i += EVENT_SIZE + ev->len;
            }
        }
reopen:
        inotify_rm_watch(inotify_fd, wd);
        close(log_fd);
        line_ptr = 0;
    }

    pthread_join(thread_pwr, NULL);
    pthread_join(thread_act, NULL);
    close(inotify_fd);
    if (fd_pwr >= 0) { pwrite(fd_pwr, "0", 1, 0); close(fd_pwr); }
    if (fd_act >= 0) { pwrite(fd_act, "0", 1, 0); close(fd_act); }
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

