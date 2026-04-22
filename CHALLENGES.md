# Challenges & Lessons Learned

A personal log of every non-obvious problem encountered while setting up and improving this project, and how each was resolved.

---

## 1. Git repository was not initialized

**Context:** The project folder existed locally but had never been run through `git init`.

**Problem:** Running `git remote -v` returned `fatal: not a git repository`. There was no `.git` folder, so no history, no remote, and no way to push.

**Fix:** Initialized the repo with `git init`, added the fork remote, fetched the upstream history, and merged with `--allow-unrelated-histories` to combine the local files with the existing commit history on GitHub.

---

## 2. README merge conflict on first merge

**Context:** The local project had a new `README.md` documenting the WebDAV server setup. The remote fork also had a `README.md` with the full plugin documentation.

**Problem:** `git merge --allow-unrelated-histories` failed with an `add/add` conflict on `README.md` because both sides created the file independently.

**Fix:** Staged the local `README.md` first, then resolved the conflict manually by keeping the remote's plugin documentation as the main content and appending the WebDAV server setup as a new section at the bottom.

---

## 3. Docker-compose had a hardcoded Mac-specific volume path

**Context:** The original `docker-compose.yml` mounted a hardcoded absolute path (`/Users/karimmoustamid/Desktop/KoReader`) to the container.

**Problem:** The file was not portable — it only worked on one specific machine with one specific folder structure.

**Fix:** Replaced the absolute path with a relative `./koreader-data` mount. Docker creates the folder automatically next to `docker-compose.yml` on first run. Works on macOS, Linux, and Windows.

---

## 4. Credentials hardcoded in docker-compose.yml

**Context:** `USERNAME` and `PASSWORD` were written directly into `docker-compose.yml`.

**Problem:** Committing credentials to a public repository is a security risk. It also made it hard to customize per-user without editing a tracked file.

**Fix:** Moved credentials and port to a `.env` file. Added `.env` to `.gitignore`. Committed `.env.example` as a template so others know what variables to set.

---

## 5. WSL2 was not enabled on the Windows host

**Context:** The Windows machine (accessed via SSH over Tailscale) had `winget` and `git` but no Docker. Docker Desktop requires WSL2.

**Problem:** `wsl --status` showed WSL2 was set as default version but the feature itself was not enabled — running any `wsl` command failed.

**Fix:** Enabled the `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform` features via `dism /online /enable-feature`. This returned exit code `194` (reboot required). Rebooted the machine remotely via `shutdown /r /t 5` and waited for it to come back online.

---

## 6. Docker Desktop credential store fails over SSH

**Context:** Docker Desktop was successfully installed via `winget`. The daemon started. Running `docker compose up -d` from an SSH session failed.

**Problem:** Docker Desktop uses the Windows Credential Manager (`credsStore: desktop`) to store registry credentials. SSH sessions run in a non-interactive logon context that cannot access the Windows Credential Manager, causing the error:

```
error getting credentials - err: exit status 1,
out: A specified logon session does not exist. It may already have been terminated.
```

This error occurred even for public images that require no login, because Docker always attempts credential lookup before pulling.

**Fix:** Removed `"credsStore": "desktop"` from `%USERPROFILE%\.docker\config.json` on Windows and also from `/root/.docker/config.json` inside WSL2 Ubuntu (which had `"credsStore": "desktop.exe"`). Replaced both with `{}`. After that, `docker compose up -d` pulled and started the container successfully.

---

## 7. WSL2 container port not reachable from outside Windows

**Context:** The WebDAV container started inside WSL2 and bound to port `8080`. A `curl` test from the Mac over Tailscale timed out.

**Problem:** WSL2 runs in its own virtual network (`172.29.x.x`). Port bindings inside WSL2 are not automatically forwarded to the Windows host's network interfaces (including the Tailscale interface at `100.92.11.119`).

**Fix:** Two steps:
1. Added a Windows port proxy rule to forward traffic from all interfaces to the WSL2 internal IP:
   ```
   netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=172.29.99.45
   ```
2. Added a Windows Firewall inbound rule to allow TCP port 8080:
   ```
   netsh advfirewall firewall add rule name="KoReader WebDAV" dir=in action=allow protocol=TCP localport=8080
   ```

After both rules, `curl` from the Mac over Tailscale returned `200 OK`.

---

## 8. Wrong WebDAV folder path in KoReader

**Context:** After the server was reachable, connecting KoReader to the WebDAV server returned: *"Cannot fetch list of folder content — please check your configuration or network connection."*

**Problem:** The folder was set to `/data` in KoReader's WebDAV config. A `PROPFIND /data/` request returned `404 Not Found`.

**Root cause:** The `bytemark/webdav` Docker image serves WebDAV from `/var/lib/dav/data/` internally, but maps that directory to the URL root `/`. There is no `/data` path exposed — the root `/` IS the data folder.

**Fix:** Changed the KoReader WebDAV folder setting from `/data` to `/`.

---

## 9. WSL2 internal IP changes on reboot

**Context:** The port proxy rule created in challenge #7 hardcodes the WSL2 IP (`172.29.99.45`).

**Potential problem:** WSL2 assigns a new internal IP on every Windows reboot. After a reboot, the port proxy still points to the old IP and the container becomes unreachable again.

**Workaround:** Re-run the port proxy setup after each reboot, or add a startup script that detects the current WSL2 IP and updates the proxy rule automatically:

```powershell
# Run at startup (Task Scheduler, on logon)
$wslIp = (wsl -d Ubuntu --user root -e bash -c "hostname -I").Trim().Split()[0]
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=$wslIp
```
