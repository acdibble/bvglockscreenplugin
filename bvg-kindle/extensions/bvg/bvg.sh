#!/bin/sh
cd "$(dirname "$0")"

# Prevent screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1

# Run the app
./bvg-kindle "$@"

# Re-enable screensaver on exit
lipc-set-prop com.lab126.powerd preventScreenSaver 0
