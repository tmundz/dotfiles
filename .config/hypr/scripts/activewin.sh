
#!/bin/bash

# Get the active window details using hyprctl
active_window_info=$(hyprctl activewindow)

# Debugging: Display the raw output to ensure it's captured
echo "$active_window_info"

# Try to extract the class name from the output
window_class=$(echo "$active_window_info" | grep -w "title:" | awk -F': ' '{print $2}')

# Display what we extracted for further debugging
echo "Extracted class: $window_class"

# If the class was found, show a notification, otherwise show an error
if [ -n "$window_class" ]; then
    notify-send "Active Window Class" "Class: $window_class"
else
    notify-send "Error" "Could not detect window class"
fi

