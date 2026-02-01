sudo apt update && sudo apt install -y gpiod
sudo apt update && sudo apt install libgpiod-dev

sudo nano fan_ctrl.c

#include <gpiod.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <math.h>

#define CHIP "gpiochip4"
#define PIN 18
#define FREQ 20
#define TEMP_MIN 50.0
#define TEMP_MAX 60.0
#define HYSTERESIS 1.0     
#define KICK_TIME 2        
#define SHM_PATH "/fan_status"

typedef struct {
    float temp;
    float duty;
} fan_state_t;

float get_temp() {
    FILE *f = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!f) return 0;
    int temp_raw;
    if (fscanf(f, "%d", &temp_raw) != 1) temp_raw = 0;
    fclose(f);
    return temp_raw / 1000.0;
}

int main() {
    struct gpiod_chip *chip = gpiod_chip_open_by_name(CHIP);
    struct gpiod_line *line = gpiod_chip_get_line(chip, PIN);
    gpiod_line_request_output(line, "fan_ctrl", 0);

    int shm_fd = shm_open(SHM_PATH, O_CREAT | O_RDWR, 0666);
    ftruncate(shm_fd, sizeof(fan_state_t));
    fan_state_t *state = mmap(0, sizeof(fan_state_t), PROT_WRITE, MAP_SHARED, shm_fd, 0);

    float current_duty = 0.2;
    float last_temp_target = 0;

    // KICKSTART (2s)
    gpiod_line_set_value(line, 1);
    sleep(KICK_TIME);

    while (1) {
        float temp = get_temp();
        
        if (fabs(temp - last_temp_target) > HYSTERESIS) {
            float target_duty = 0.2;

            if (temp >= TEMP_MAX) {
                target_duty = 1.0;
            } else if (temp > TEMP_MIN) {
                // Diskretizácia na 10% kroky (0.2, 0.3, ..., 1.0)
                float raw_duty = 0.2 + (temp - TEMP_MIN) * 0.8 / (TEMP_MAX - TEMP_MIN);
                target_duty = roundf(raw_duty * 10.0) / 10.0;
            }

            current_duty = target_duty;
            last_temp_target = temp; 
        }

        state->temp = temp;
        state->duty = current_duty;

        long period_us = 1000000 / FREQ;
        long on_us = period_us * current_duty;
        long off_us = period_us - on_us;

        for (int i = 0; i < FREQ; i++) {
            gpiod_line_set_value(line, 1);
            usleep(on_us);
            gpiod_line_set_value(line, 0);
            usleep(off_us);
        }
    }
    return 0;
}

gcc -o fan_ctrl fan_ctrl.c -lgpiod -lrt -lm

sudo mv fan_ctrl /usr/local/bin/
sudo chown root:root /usr/local/bin/fan_ctrl
sudo chmod +x /usr/local/bin/fan_ctrl

sudo nano /etc/systemd/system/fan.service

[Unit]
Description=C-based Fan Control PWM 20Hz
After=network.target

[Service]
ExecStart=/usr/local/bin/fan_ctrl
Restart=always
RestartSec=5
User=root
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target


sudo nano fan_view.py

import mmap
import struct
import time

def read_fan_status():
    with open("/dev/shm/fan_status", "rb") as f:
        mm = mmap.mmap(f.fileno(), 8, access=mmap.ACCESS_READ)
        data = mm.read(8)
        temp, duty = struct.unpack("ff", data)
        return temp, duty * 100

try:
    while True:
        t, d = read_fan_status()
        print(f"Status -> Temp: {t:.1f}°C, Fan: {d:.0f}%", end="\r")
        time.sleep(1)
except FileNotFoundError:
    print("Something wrong...")
