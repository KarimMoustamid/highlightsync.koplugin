# Improvements Log

Tracks all changes made to this fork beyond the upstream plugin.

---

## Bug Fixes

### 1. Stale comment in `_meta.lua`

- **Status:** done
- **File:** `_meta.lua:5`
- **Issue:** Leftover `-- ← Add this line!` comment from development noise.
- **Fix:** Removed the comment.

### 2. Global variable leaks in `main.lua`

- **Status:** done
- **File:** `main.lua` — `SyncBookHighlights` function
- **Issue:** `SidecarDir`, `FileName`, `Raw_name`, and `DataAnnotations` were assigned without `local`, making them unintended globals that could cause bugs if two syncs overlap.
- **Fix:** Declared all four as `local` inside the function scope.

### 3. `pos0.x` typo in `merge.lua`

- **Status:** done
- **File:** `merge.lua:96`
- **Issue:** Sort comparator used `b.pos0.y` instead of `b.pos0.x` when comparing x-coordinates, causing incorrect ordering of PDF highlights on the same line.
- **Fix:** Corrected to `a.pos0.x < b.pos0.x`.

### 4. Untranslated comments in `merge.lua`

- **Status:** done
- **File:** `merge.lua` — lines 54, 63, 76, 82
- **Issue:** Several inline comments were left in Spanish/Portuguese (`-- Processa os highlights locais`, etc.).
- **Fix:** Translated all comments to English.

---

## Enhancements

### 5. `.env` support for `docker-compose.yml`

- **Status:** done
- **Issue:** Credentials and port were hardcoded directly in `docker-compose.yml`, making it awkward to share or version-control the file.
- **Fix:** Extracted `USERNAME`, `PASSWORD`, and `PORT` into a `.env` file. Added `.env` to `.gitignore`.

### 6. Sync status — last synced timestamp in menu

- **Status:** done
- **Issue:** No indication in the UI of when the last successful sync occurred.
- **Fix:** Persist the last sync timestamp in reader settings and display it in the Highlight Sync menu.

### 7. Export highlights to Markdown

- **Status:** done
- **Issue:** No way to export highlights out of KoReader into a readable format for note-taking apps like Obsidian.
- **Fix:** Added a menu option that writes all highlights for the current book to a `.md` file, grouped by chapter.
