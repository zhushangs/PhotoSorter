# 理片 PhotoSorter

[简体中文](README.zh-CN.md) · **English**

An ad-free alternative to Slidebox: go through every photo that isn't in an album yet, one at a time, and tap an album name at the bottom to file it.

- [Features](#features)
- [Step 1: Build the ipa](#step-1-build-the-ipa)
- [Step 2: Install on your iPhone](#step-2-install-on-your-iphone)
  - [Option A: Install directly with iloader (simplest, needs a PC every 7 days)](#option-a-install-directly-with-iloader)
  - [Option B: SideStore + auto-refresh (recommended, no PC afterwards)](#option-b-sidestore--auto-refresh)
- [Troubleshooting](#troubleshooting)
- [Project layout](#project-layout)

---

## Features

- **Unsorted photos only**: a photo shows up only if it isn't in any album.
- **Album bar**: your existing iPhone albums are loaded automatically. Each card shows a cover, the name and the photo count; tap it to put the current photo in that album.
  - Sorted by photo count by default, so your most-used albums come first; positions don't jump while you sort. Switch to manual order under "管理" (Manage).
  - Long-press an album: open it / remove it from the bar.
- **Arrows beside the photo**: ‹ goes back one step (undo), › skips this photo. Swipe left to skip, right to go back.
- **Deleting**:
  - Tap the trash can (or swipe the photo up): marks it for deletion and moves on, no prompt.
  - Long-press the trash can: "全部删除" (Delete all — iOS asks once; photos go to Recently Deleted for 30 days) or "全部恢复" (Restore all).
- **Manage albums**: create, rename, delete albums (photos are kept), add to or remove from the bar.
- **Organize inside an album**: grid view; go one by one or multi-select to move, take out of the album, or delete.
- **Reliable saving**: saves are queued and retried; "保存中…" (Saving…) shows at the top, and a real failure is reported and the photo goes back into the queue.
- Every change is written straight to the system Photos library; nothing is uploaded. The app stores no data itself, so if it expires or is deleted your albums stay intact.

---

## Step 1: Build the ipa

Works with only a Windows PC: `.github/workflows/build.yml` builds the app on GitHub's free macOS runners.

1. Open this folder in **GitHub Desktop**, commit, and click **Push origin**.
2. On github.com open the repo → **Actions** and wait for the latest "Build IPA" run to turn green ✓ (about 5 minutes).
3. Open the run, download `PhotoSorter-ipa` under **Artifacts** at the bottom, and unzip it to get `PhotoSorter.ipa`.

> ⚠️ Actions keeps files for **90 days** by default. Save a copy of `PhotoSorter.ipa` on your PC (outside this repo folder).
> Lost it? Actions → "Build IPA" on the left → **Run workflow** on the right, and a fresh build is ready in a few minutes.

---

## Step 2: Install on your iPhone

Both options use **iloader** and a free Apple ID.

**Prerequisites (both options)**

1. Install **iTunes** from Apple's website, not the Microsoft Store: <https://www.apple.com/itunes/download/win64>
   **iCloud for Windows is not needed.**
2. Download **iloader** from its official sources only: the Releases page of <https://github.com/nab138/iloader>, or iloader.app.
3. Set a passcode on the iPhone, connect it by USB, **unlock it**, and tap "Trust This Computer".

### Option A: Install directly with iloader

Good if you only use the app occasionally and don't mind plugging in.

1. Open iloader, sign in with an Apple ID (a secondary one is recommended), choose **Import IPA**, and pick `PhotoSorter.ipa`. Keep the phone unlocked with the screen on.
2. On the iPhone:
   - **Settings → Privacy & Security → Developer Mode**: turn it on (the option appears only after the first sideloaded install; the phone restarts).
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
3. Open 理片 and choose **"Allow Full Access"** for photos.

> Apps signed with a free Apple ID **stop opening after 7 days** ("no longer available"). When you want to use it again, plug in and install the same ipa with iloader; it replaces the old copy and your albums are untouched.

### Option B: SideStore + auto-refresh

Set it up once and the phone re-signs itself daily, so the app opens whenever you need it — even months later — without a PC.

#### 1. Install SideStore with iloader

- Open iloader, sign in, select your iPhone, and install **SideStore (Stable)**.
  - You don't need the LiveContainer versions (they're for people running many apps or needing JIT).
  - If Stable won't open or keeps failing, install **SideStore (Nightly)** instead.
- On the iPhone, as in Option A step 2: turn on **Developer Mode** and **Trust** your Apple ID in VPN & Device Management.

#### 2. Install LocalDevVPN and allow SideStore notifications

- Install **LocalDevVPN** from the App Store, open it, tap **Connect**, and allow the VPN configuration. It only simulates a computer connection on the phone; SideStore needs it on whenever it installs or refreshes.
- **Settings → Notifications → SideStore → Allow Notifications**: turn it on. On iOS 27, refreshing fails with "Source is not authorized" without it. You can turn off banners and sounds and keep only "Allow Notifications".

#### 3. Sign in to SideStore

- With LocalDevVPN connected, open SideStore and sign in with **the same Apple ID you used in iloader**.
- If asked to **revoke a certificate**, accept — that's expected.
- For sign-in errors see [Troubleshooting](#troubleshooting).

#### 4. Install 理片 through SideStore

- In Safari on the iPhone, sign in to GitHub → the repo → Actions → latest green run → download `PhotoSorter-ipa`, then tap the zip in the Files app to unzip it.
- Open SideStore → **My Apps** → **"+"** at the top left → pick `PhotoSorter.ipa`.
- **It must be installed by SideStore** — SideStore can only refresh apps it installed. You can delete an older copy installed by iloader first (your albums are untouched).

#### 5. Create the "理片续签" (refresh) shortcut

Open the Shortcuts app → "+" to create a new shortcut, and add these actions from the search bar at the bottom:

| # | Action | Setting |
|---|---|---|
| 1 | **Set VPN** | LocalDevVPN → **Connect** |
| 2 | **Wait** | 30 seconds |
| 3 | **Refresh All Apps** (search "SideStore") | Tap › to expand; turn off "Show When Run" if present |
| 4 | **Wait** | 60 seconds |
| 5 | **Set VPN** | LocalDevVPN → **Disconnect** |

Name it **理片续签** (or anything you like), tap ▶️ to run it once, then check that SideStore shows **7 DAYS** again.

> If "Refresh All Apps" shows a confirmation that blocks the last two steps: delete steps 4 and 5, and create a separate automation 5 minutes later containing only "Set VPN → Disconnect". The refresh is already done before that prompt appears.

#### 6. Run it automatically every day

Shortcuts → **Automation** → "+" → **Time of Day**:

- Time: when the phone is usually charging on Wi-Fi, e.g. 11 PM or 3 AM.
- Repeat: **Daily** (a few failures don't matter; one success within 7 days is enough).
- Choose **Run Immediately** and turn **Notify When Run** off.
- Next → on the blank page search **Run Shortcut** → choose **理片续签** → Done.

Test it: set the time to two or three minutes from now, let it run on its own, check SideStore shows **7 DAYS**, then set the time back.

> **When you'll still need the PC**: after a major iOS update the pairing file may stop working, or if the automation hasn't succeeded for over 7 days (e.g. the phone was off). Reinstall SideStore with iloader once and you're set again.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| 理片 says "no longer available" | The 7-day free signature expired. Option A: reinstall with iloader. Option B: check the automation, open SideStore and tap Refresh All |
| iloader says `bad device` | Unlock the phone and keep the screen on; replug the cable, use a USB port on the PC itself; restart iloader |
| "Untrusted Developer" | Settings → General → VPN & Device Management → Trust |
| No "Developer Mode" option | Install a sideloaded app once first; the option appears afterwards |
| SideStore sign-in error `-80045` / `-80046` | Settings → User Customizations: turn **On-Device Anisette** off, tap **Reset adi.pb**, force-quit and reopen SideStore, and with LocalDevVPN connected sign in **once**. Don't retry repeatedly |
| `Anisette server returned HTTP status -1` / `-45061` | Try turning On-Device Anisette on and sign in again; or Diagnostics → Developer Options and clear the database; or install the Nightly build |
| Refresh fails with `Source is not authorized` | Settings → Notifications → SideStore → Allow Notifications |
| Don't edit **Anisette Client Configuration** | It holds the identity used to sign in; wrong values break sign-in |
| No albums in 理片 | Photo access must be "Full Access": Settings → 理片 → Photos |
| Actions run is red ✗ | The Annotations section on the run's summary page shows the failing code lines |
| Two copies of 理片 on the phone | You switched Apple ID or install tool. Delete the old one; albums are untouched |

---

## Project layout

```
PhotoSorter/
├── project.yml                 XcodeGen config (iOS 17+)
├── .github/workflows/build.yml GitHub Actions cloud build
└── PhotoSorter/
    ├── PhotoSorterApp.swift     App entry
    ├── SorterModel.swift        Albums, unsorted photos, file / skip / delete / undo, album management
    ├── SorterView.swift         Main screen, side arrows, album bar
    ├── AlbumManagerView.swift   Create / reorder / delete albums
    ├── AlbumDetailView.swift    Album grid, one-by-one review, multi-select actions
    ├── AssetImageView.swift     Full-size and thumbnail loading (iCloud photos supported)
    ├── RootView.swift           Photo permission handling
    └── Assets.xcassets          App icon
```
