# KoReader WebDAV Sync Server

## Overview

This project runs a local **WebDAV server** on your Mac that allows your KoReader e-reader device to sync reading data — highlights, bookmarks, and reading progress — over your local network.

KoReader is an open-source document reader available on Kindle, Kobo, Android, and other platforms. It stores reading metadata (highlights, notes, progress) in sidecar `.sdr` directories alongside each book file. By connecting KoReader to this WebDAV server, that data is automatically backed up and made accessible on your Mac.

---

## How It Works

```
KoReader Device  ──(WebDAV / local network)──►  Docker WebDAV Server  ──►  ~/Desktop/KoReader/
     (e-reader)                                      (port 8080)               (your Mac folder)
```

1. Docker runs a WebDAV server (`bytemark/webdav` image) on port `8080`
2. The server exposes your local `~/Desktop/KoReader/` folder over WebDAV
3. KoReader connects to `http://<your-mac-ip>:8080` using the configured credentials
4. Every time KoReader syncs, it writes `.sdr` sidecar data into that folder
5. A companion script (or manual process) converts those `.sdr` files into clean `.json` files stored in `data/Koreader/`

---

## Project Structure

```
KoReader/
├── docker-compose.yml       # WebDAV server configuration
├── DavLock / DavLock.*      # WebDAV lock files (auto-generated, safe to ignore)
└── data/
    └── Koreader/
        └── *.sdr.json       # Parsed highlight/annotation data per book
```

---

## Configuration

The WebDAV server is defined in [docker-compose.yml](docker-compose.yml):

```yaml
services:
  webdav:
    image: bytemark/webdav
    container_name: koreader_webdav
    restart: always
    ports:
      - "8080:80"
    environment:
      - USERNAME=karim
      - PASSWORD=password123
    volumes:
      - /Users/karimmoustamid/Desktop/KoReader:/var/lib/dav
```

| Setting | Value |
|---|---|
| Port | `8080` (mapped from container port 80) |
| Username | `karim` |
| Password | `password123` |
| Synced folder | `~/Desktop/KoReader/` |

> **Security note:** Change the password before exposing this server outside your local network.

---

## Starting the Server

```bash
# Start (detached)
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f
```

---

## Connecting KoReader to the Server

1. Find your Mac's local IP address: **System Settings → Wi-Fi → Details**
2. In KoReader, go to: **Tools → Cloud Storage → WebDAV**
3. Enter the server details:
   - **URL:** `http://<your-mac-ip>:8080`
   - **Username:** `karim`
   - **Password:** `password123`
4. Tap **Sync** — KoReader will push its sidecar data to your Mac

---

## The `.sdr.json` Data Format

Each `.sdr.json` file in `data/Koreader/` contains an array of highlight objects for a given book. Example:

```json
{
  "text": "Everyone wants to start off as an expert, but we need to start as a beginner.",
  "chapter": "Chapter 1: Stop Being a Perfectionist",
  "pageno": 22,
  "color": "red",
  "drawer": "underscore",
  "datetime": "2026-03-24 22:39:31",
  "datetime_updated": "2026-03-24 22:39:51"
}
```

| Field | Description |
|---|---|
| `text` | The highlighted passage |
| `chapter` | Chapter name where the highlight was made |
| `pageno` | Page number |
| `color` | Highlight color (`red`, `yellow`, `blue`, etc.) |
| `drawer` | Highlight style (`underscore`, `lighten`, etc.) |
| `datetime` | When the highlight was first created |
| `datetime_updated` | When it was last modified |
| `pos0` / `pos1` | XPath positions within the EPUB DOM (used internally by KoReader) |
