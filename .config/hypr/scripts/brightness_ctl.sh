
#!/bin/bash

# Check if an argument is provided (up or down)
if [[ -z $1 ]]; then
    echo "Usage: $0 {up|down}"
    exit 1
fi

# Set the increment/decrement percentage
BRIGHTNESS_STEP=10%

if [[ $1 == "up" ]]; then
    # Increase the brightness by percentage
    brightnessctl set +$BRIGHTNESS_STEP
    notify-send "Brightness increased by $BRIGHTNESS_STEP"
elif [[ $1 == "down" ]]; then
    # Decrease the brightness by percentage
    brightnessctl set $BRIGHTNESS_STEP-
    notify-send "Brightness decreased by $BRIGHTNESS_STEP"
else
    notify-send "Invalid argument. Use 'up' or 'down'."
    exit 1
fi

