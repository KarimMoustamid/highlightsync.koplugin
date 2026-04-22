# 📚 HighlightSync Plugin for KOReader

**HighlightSync** is a plugin for [KOReader](https://github.com/koreader/koreader) that **synchronizes and merges your highlights, notes, and bookmarks** across multiple devices or cloud backup locations. It allows you to sync highlights made offline on two or more devices, ensuring that no data is lost when syncing.

Supports popular cloud services like **WebDAV** and **Dropbox**, helping you keep your annotations consistent no matter which device you're reading on.

---

## ⚠️ Beta Warning

This plugin is currently in **beta**. Use at your own risk.

While it has been tested on several platforms, the author is **not responsible for any data loss**. Please back up your annotations regularly.

---

## ✅ Tested Devices

- KOReader on **Linux**
- **Boox Go 6**
- **Boox Go 10.3**
- **Android 15**

More devices may work — feel free to open an issue or pull request with your results!

---

## ✨ Features

- 🔄 **Automatic & Manual Sync:** Configurable options to sync automatically on **book open, close, or resume**, or sync manually via menu/gestures.
- 🛡️ **Conflict-free Merging:** Highlights made offline on different devices are combined intelligently without overwriting each other.
- 📝 **True Offline Freedom:** Read and annotate on your Kindle and Boox separately; sync them all when you get Wi-Fi.
- ☁️ Works with **WebDAV** and **Dropbox**.
- 📅 **Smart Updates:** Syncs highlight edits based on the latest timestamp.
- 🕐 **Last Synced Indicator:** The menu shows when the last successful sync occurred.
- 📄 **Export to Markdown:** Export all highlights for the current book to a `.md` file grouped by chapter, ready for Obsidian or any note-taking app.
- 🌐 **Tailscale support:** Sync from anywhere over a secure WireGuard tunnel — no port forwarding required.
- ⚡ **Lightweight** and easy to install.

---

## 📥 Installation

To install the plugin:

1. Download the **latest release** from the [GitHub repository](https://github.com/gitalexcampos/koreader-Highlight-Sync/releases).
2. **Extract the downloaded file** and locate the `highlightsync.koplugin` folder.
3. Copy the `highlightsync.koplugin` folder.
4. Place it inside the `koreader/plugins/` directory on your KOReader device.

---

## 🔧 Setup

1. Open KOReader.
2. Go to the **Main Menu > Tools > Highlight Sync > Sync Cloud**.
3. Set up your **cloud service** (WebDAV or Dropbox).
4. Select the **folder** where your **JSON files** containing the highlights of your books are or will be stored. (This folder **does not need** to be the same as your ebooks folder.)
   ⚠️ **If you change this folder after you've already synced a book**, you **must manually move the book's JSON file** from the old folder to the new one in your cloud service. If the plugin doesn't find the file in the new location, it will assume that the highlights were **deleted on another device** and will remove them during sync.
5. Configure your preferred **Automatic Sync** settings (Open, Close, or Resume) in the settings menu, or use the manual **Sync Highlights** button.

---

## ⚠️ Important Configuration Notes

### 📂 Hash-based Metadata (Sidecar Folder)

If you use KOReader's **"Hash based"** setting for metadata location (instead of the default sidecar folder next to the file), the plugin will generate the sync filename based on that hash (e.g., `c5a2f1...json`) instead of the book title.

**Crucial:** You must ensure **ALL your devices use the same metadata setting**.

- If Device A uses **Hash-based** and Device B uses **File location**, Device A will look for a hashed filename while Device B looks for the book title filename. They will **not** see each other's highlights.

### ⏳ Sync Freeze & Reload

During synchronization, you might experience a **brief freeze** (UI blocking) for a few seconds.

- This is normal behavior due to KOReader's single-core architecture handling the network request and JSON processing.
- After syncing, the plugin will trigger a **document reload**. This is necessary for KOReader to visually render the newly imported highlights on the page.

---

## 🛠 Known Limitations

- The **book names** (or hashes, if configured) on the devices must be **exactly the same** for syncing to work correctly.
- If two highlights start at the same position but end at different ones, the **most recent one is kept**.
- This is an early version — feedback is welcome!

---

## 🤝 Contributing

Pull requests and issue reports are welcome! If you have ideas or find bugs, feel free to open an issue.

---

## 🖥️ Self-Hosted WebDAV Server Setup

If you don't have a WebDAV server, you can run one locally using Docker (works on macOS, Linux, and Windows).

### How It Works

```text
KoReader Device  ──(WebDAV / local network)──►  Docker WebDAV Server  ──►  ./koreader-data/
     (e-reader)                                      (port 8080)            (next to docker-compose.yml)
```

### docker-compose.yml

Credentials and port are read from a `.env` file (never committed). Copy `.env.example` to get started:

```bash
cp .env.example .env
# then edit .env with your preferred username, password, and port
```

```yaml
services:
  webdav:
    image: bytemark/webdav
    container_name: koreader_webdav
    restart: always
    ports:
      - "${WEBDAV_PORT:-8080}:80"
    environment:
      - USERNAME=${WEBDAV_USERNAME}
      - PASSWORD=${WEBDAV_PASSWORD}
    volumes:
      - ./koreader-data:/var/lib/dav
```

> **Security note:** Change the password before exposing this server outside your local network.

### Commands

```bash
# Start (detached)
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f
```

### Connecting KoReader

Use the config that matches your device's situation:

| Scenario | URL | Folder |
| --- | --- | --- |
| Same WiFi / local network (no Tailscale needed) | `http://<host-local-ip>:8080` | `/` |
| Anywhere via Tailscale | `http://<host-tailscale-ip>:8080` | `/` |

> **Important:** The folder must be set to `/` (root). The `bytemark/webdav` image serves files from its root directly — there is no `/data` subfolder to navigate into.

#### Option A — Local network (same WiFi)

No extra software needed. Works for any device on the same network — Kindle, Kobo, phone.

1. Find your host machine's local IP:
   - **macOS:** System Settings → Wi-Fi → Details
   - **Linux:** `ip addr` or `hostname -I`
   - **Windows:** `ipconfig` in a terminal
2. In KoReader: **Tools → Cloud Storage → WebDAV**
3. Enter `http://<host-local-ip>:8080`, your username, password, and `/` as the folder
4. Tap **Sync**

#### Option B — Anywhere via Tailscale

KoReader runs on jailbroken/rooted devices (Kindle, Kobo, Boox, Android) — all of which can run Tailscale. This lets you sync from anywhere over a secure WireGuard tunnel with no port forwarding and no public exposure.

1. Install [Tailscale](https://tailscale.com) on both your host machine and your KoReader device
2. Sign in to the same Tailscale account on both
3. Find your host's Tailscale IP (`100.x.x.x`) in the Tailscale app or dashboard
4. In KoReader: **Tools → Cloud Storage → WebDAV**
5. Enter `http://100.x.x.x:8080`, your username, password, and `/` as the folder
6. Tap **Sync** — works from any network

> The WebDAV server does not need any firewall changes or port forwarding. Tailscale handles the secure tunnel automatically.

### The `.sdr.json` Data Format

Each synced file contains an array of highlight objects:

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
| --- | --- |
| `text` | The highlighted passage |
| `chapter` | Chapter name where the highlight was made |
| `pageno` | Page number |
| `color` | Highlight color (`red`, `yellow`, `blue`, etc.) |
| `drawer` | Highlight style (`underscore`, `lighten`, etc.) |
| `datetime` | When the highlight was first created |
| `datetime_updated` | When it was last modified |
| `pos0` / `pos1` | XPath positions within the EPUB DOM (used internally by KoReader) |
