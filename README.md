# BVG Lock Screen for KOReader

A KOReader plugin that displays Berlin public transport (BVG) departure information on the lock screen.

![Example display](https://v6.bvg.transport.rest/)

## Features

- Real-time departure data from BVG API
- Station search and favorites management
- Configurable departure count, time range, and transport filters
- E-ink optimized display with monospace alignment
- Periodic refresh every 15 seconds (only when data changes)
- Full screen refresh every 10 minutes to prevent ghosting
- Battery percentage indicator
- Rate limiting to respect API

## Installation

Copy the `bvglockscreen.koplugin` folder to your KOReader plugins directory:

- **Kindle**: `/mnt/us/koreader/plugins/`
- **Kobo**: `.adds/koreader/plugins/`
- **Desktop**: `~/.config/koreader/plugins/`

## Usage

1. Open KOReader
2. Go to **Tools → BVG Lock Screen**
3. Search for and select a station
4. Optionally add stations to favorites
5. Configure settings (departure count, time range, transport types)
6. Go to **Settings → Screen → Screensaver → Wallpaper**
7. Select **Show BVG departures on sleep screen**

## Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Departures shown | Number of departures to display | 8 |
| Time range | How far ahead to look for departures | 30 min |
| Transport types | Filter by U-Bahn, S-Bahn, Bus, Tram, etc. | All enabled |
| Font size | Small, Medium, or Large | Medium |

## Display Layout

```
Alexanderplatz                    14:32
──────────────────────────────────────
M13 S Warschauer Str.              5 min
 21 Weißensee                     12 min
 U2 Ruhleben                       3 min
 U5 Hönow                          7 +2
 U8 Hermannstraße                 14 min
                                    85%
```

## API

Uses the public [BVG REST API](https://v6.bvg.transport.rest/) (v6).

- No API key required
- Self-imposed rate limit: 1 request per 15 seconds
- Retry logic for transient network failures

## License

MIT
