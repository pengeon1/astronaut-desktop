#!/bin/bash

# If launched on startup, wait for desktop environment to fully initialize
if [ "$1" = "--startup" ]; then
    sleep 10
fi

# Pre-fetch initial Spotify state
python3 "$HOME/.config/conky/Astronaut/scripts/spotify.py" 2>/dev/null

# Close any active conky instances
killall -q conky
sleep 1

# Start Astronaut conky detached in background
setsid nohup conky -c "$HOME/.config/conky/Astronaut/Astronaut.conf" </dev/null >/dev/null 2>&1 &

exit 0
