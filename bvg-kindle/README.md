# BVG Kindle Departures

A standalone GTK+ 2.0 application for displaying BVG departures on Kindle e-readers, installable via KUAL.

## Building

### Prerequisites

1. Install Kindle SDK: https://kindlemodding.org/kindle-dev/kindle-sdk.html
2. Generate the toolchain: `./gen-sdk.sh kindlehf` (for FW ≥5.16.3)

### Cross-compile for Kindle

```bash
meson setup --cross-file ~/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt build_kindle
meson compile -C build_kindle
```

## Installation

1. Copy `build_kindle/bvg-kindle` to `/mnt/us/extensions/bvg/`
2. Copy contents of `extensions/bvg/` to `/mnt/us/extensions/bvg/`
3. Launch via KUAL → BVG Departures → Start Display

## Configuration

Edit `/mnt/us/extensions/bvg/config.txt`:

```
station_id=900100003
station_name=Alexanderplatz
```

Or use KUAL → BVG Departures → Configure Station

## Controls

- Press `Escape` or `q` to exit
- Display refreshes every 15 seconds
