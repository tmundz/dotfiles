#!/bin/bash

# Weather script for Edmonton, AB
# Uses Open-Meteo API (free, no API key required)

# Edmonton coordinates
LAT="53.5461"
LON="-113.4938"

# Fetch weather data
response=$(curl -sf --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current_weather=true" 2>/dev/null)

if [ -n "$response" ]; then
    # Extract temperature from current_weather section
    temp=$(echo "$response" | grep -o '"current_weather":{[^}]*}' | grep -o '"temperature":[0-9.-]*' | cut -d':' -f2)
    if [ -n "$temp" ]; then
        printf "%.0f°C\n" "$temp"
    else
        echo "--"
    fi
else
    echo "--"
fi
