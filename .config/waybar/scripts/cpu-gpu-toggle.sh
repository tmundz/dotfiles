#!/bin/bash

# CPU stats
cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')

# CPU temp
cpu_temp="N/A"
for hwmon in /sys/class/hwmon/hwmon*/; do
    if [ -f "${hwmon}name" ]; then
        name=$(cat "${hwmon}name")
        if [[ "$name" == "k10temp" || "$name" == "coretemp" || "$name" == "zenpower" ]]; then
            if [ -f "${hwmon}temp1_input" ]; then
                cpu_temp=$(($(cat "${hwmon}temp1_input") / 1000))
                break
            fi
        fi
    fi
done

# GPU stats (AMD)
gpu_usage="N/A"
gpu_temp="N/A"

for card in /sys/class/drm/card*/device/gpu_busy_percent; do
    if [ -f "$card" ]; then
        gpu_usage=$(cat "$card")
        break
    fi
done

for hwmon in /sys/class/hwmon/hwmon*/; do
    if [ -f "${hwmon}name" ]; then
        name=$(cat "${hwmon}name")
        if [[ "$name" == "amdgpu" ]]; then
            if [ -f "${hwmon}temp1_input" ]; then
                gpu_temp=$(($(cat "${hwmon}temp1_input") / 1000))
                break
            fi
        fi
    fi
done

echo "{\"text\": \"󰻠 ${cpu_usage}% ${cpu_temp}°C | 󰢮 ${gpu_usage}% ${gpu_temp}°C\"}"
