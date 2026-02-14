#!/bin/bash
# Start virtual framebuffer and VNC server for headed browser access

# Start Xvfb (virtual display :99, 1280x720)
Xvfb :99 -screen 0 1280x720x24 -ac &
sleep 1

# Start VNC server (no password, viewable + interactive)
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &
sleep 0.5

echo "VNC server running on port 5900"
