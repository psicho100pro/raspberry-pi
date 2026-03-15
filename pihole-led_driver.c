nano pihole_led_monitor.c
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            pihole_led_monitor.c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>

#define LOG_PATH "/var/log/pihole/pihole.log"
#define MAX_BLINKS 5

volatile sig_atomic_t stop = 0;
volatile int queue_pwr = 0;
volatile int queue_act = 0;

int fd_pwr = -1;
int fd_act = -1;

void handle_signal(int sig) { stop = 1; }

void* led_worker(void* arg) {
    volatile int* queue = (volatile int*)arg;
    int fd = (arg == (void*)&queue_pwr) ? fd_pwr : fd_act;

    while (!stop) {
        if (__atomic_load_n(queue, __ATOMIC_SEQ_CST) > 0) {
            __atomic_sub_fetch(queue, 1, __ATOMIC_SEQ_CST);
            if (fd >= 0) {
                pwrite(fd, "1", 1, 0);
                usleep(40000);
                pwrite(fd, "0", 1, 0);
                usleep(80000);
            }
        } else {
            usleep(20000);
        }
    }
    return NULL;
}

void init_leds() {
    system("echo none > /sys/class/leds/PWR/trigger 2>/dev/null");
    system("echo none > /sys/class/leds/ACT/trigger 2>/dev/null");
    fd_pwr = open("/sys/class/leds/PWR/brightness", O_WRONLY);
    fd_act = open("/sys/class/leds/ACT/brightness", O_WRONLY);
}

int main() {
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    init_leds();

    pthread_t t1, t2;
    pthread_create(&t1, NULL, led_worker, (void*)&queue_pwr);
    pthread_create(&t2, NULL, led_worker, (void*)&queue_act);

    char line_buffer[4096];
    int line_ptr = 0;
    off_t current_offset = 0;
    ino_t current_inode = 0;
    int log_fd = -1;

    while (!stop) {
        if (log_fd < 0) {
            log_fd = open(LOG_PATH, O_RDONLY);
            if (log_fd >= 0) {
                struct stat st;
                fstat(log_fd, &st);
                current_inode = st.st_ino;
                current_offset = st.st_size;
                lseek(log_fd, current_offset, SEEK_SET);
            } else {
                sleep(1);
                continue;
            }
        }

        struct stat st_file, st_fd;
        if (stat(LOG_PATH, &st_file) == 0 && fstat(log_fd, &st_fd) == 0) {
            if (st_file.st_ino != current_inode) {
                close(log_fd);
                log_fd = -1;
                continue;
            }
            if (st_fd.st_size < current_offset) {
                current_offset = 0;
                lseek(log_fd, 0, SEEK_SET);
            }
        } else {
            close(log_fd);
            log_fd = -1;
            continue;
        }

        char read_chunk[8192];
        ssize_t bytes;
        while ((bytes = read(log_fd, read_chunk, sizeof(read_chunk))) > 0) {
            current_offset += bytes;
            for (ssize_t j = 0; j < bytes; j++) {
                if (read_chunk[j] == '\n') {
                    line_buffer[line_ptr] = '\0';
                    if (strstr(line_buffer, " blocked") || strstr(line_buffer, " gravity")) {
                        if (__atomic_load_n(&queue_pwr, __ATOMIC_SEQ_CST) < MAX_BLINKS)
                            __atomic_add_fetch(&queue_pwr, 1, __ATOMIC_SEQ_CST);
                    } else if (strstr(line_buffer, " reply") || strstr(line_buffer, " cached")) {
                        if (__atomic_load_n(&queue_act, __ATOMIC_SEQ_CST) < MAX_BLINKS)
                            __atomic_add_fetch(&queue_act, 1, __ATOMIC_SEQ_CST);
                    }
                    line_ptr = 0;
                } else if (line_ptr < sizeof(line_buffer) - 1) {
                    line_buffer[line_ptr++] = read_chunk[j];
                } else {
                    line_ptr = 0;
                }
            }
        }
        usleep(100000);
    }

    if (log_fd >= 0) close(log_fd);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
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

