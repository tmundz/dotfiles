#!/bin/bash

read_cpu_total_idle() {
    awk '/^cpu / { idle=$5+$6; total=0; for (i=2; i<=NF; i++) total+=$i; print total, idle }' /proc/stat
}

cpu_usage() {
    read -r total_a idle_a < <(read_cpu_total_idle)
    sleep 0.2
    read -r total_b idle_b < <(read_cpu_total_idle)

    awk -v ta="$total_a" -v ia="$idle_a" -v tb="$total_b" -v ib="$idle_b" '
        BEGIN {
            total = tb - ta
            idle = ib - ia
            if (total <= 0) print 0
            else printf "%.0f", (100 * (total - idle) / total)
        }'
}

hwmon_by_name() {
    local wanted="$1"
    local hwmon name

    for hwmon in /sys/class/hwmon/hwmon*; do
        [ -r "$hwmon/name" ] || continue
        name=$(cat "$hwmon/name")
        if [ "$name" = "$wanted" ]; then
            printf '%s\n' "$hwmon"
            return 0
        fi
    done

    return 1
}

temp_c() {
    local file="$1"

    if [ -r "$file" ]; then
        awk '{ printf "%.0f", $1 / 1000 }' "$file"
    else
        printf 'N/A'
    fi
}

# AMD: k10temp / amdgpu — Intel: coretemp / i915. Try AMD first, fall back to Intel.
cpu_hwmon=$(hwmon_by_name k10temp || hwmon_by_name coretemp)
gpu_hwmon=$(hwmon_by_name amdgpu || hwmon_by_name i915)

cpu_load=$(cpu_usage)
cpu_tctl=$(temp_c "$cpu_hwmon/temp1_input")
cpu_ccd=$(temp_c "$cpu_hwmon/temp3_input")

gpu_usage="N/A"
for busy_file in /sys/class/drm/card*/device/gpu_busy_percent; do
    [ -r "$busy_file" ] || continue
    gpu_usage=$(cat "$busy_file")
    break
done

gpu_edge=$(temp_c "$gpu_hwmon/temp1_input")
gpu_junction=$(temp_c "$gpu_hwmon/temp2_input")
gpu_mem=$(temp_c "$gpu_hwmon/temp3_input")

text="󰻠 ${cpu_load}% ${cpu_tctl}°C | 󰢮 ${gpu_usage}% ${gpu_edge}°C"
tooltip="CPU: ${cpu_load}%\nCPU Tctl: ${cpu_tctl}°C\nCPU CCD: ${cpu_ccd}°C\nGPU: ${gpu_usage}%\nGPU edge: ${gpu_edge}°C\nGPU junction: ${gpu_junction}°C\nGPU memory: ${gpu_mem}°C"

printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
