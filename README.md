# 理片 PhotoSorter

[中文](#中文) · [English](#english)

---

## 中文

无广告的 Slidebox 替代品：一张张查看所有还没放进相册的照片，点底部相册名就归档。

### 功能

- **只显示未分类照片**：不在任何相册里的照片才会出现。
- **相册栏**：自动读取 iPhone 里已有的相册，放在底部。每个相册显示一张封面、名字和照片数量，点一下就把当前照片放进去。
  - 默认按照片数量排序，常用的在前面；整理时位置不会跳动。也可以在「管理」里改成手动排序。
  - 长按相册：打开相册 / 从相册栏移除。
- **照片两侧的箭头**：‹ 返回上一步（撤销），› 略过这张。也可以左滑略过、右滑返回。
- **删除**：
  - 点右上角垃圾桶（或上滑照片）：标记这张为待删除，直接跳到下一张，不弹窗。
  - 长按垃圾桶：「全部删除」（系统只确认一次，照片进入「最近删除」，30 天内可找回）或「全部恢复」。
- **管理相册**：新建、改名、删除相册（照片不会被删）、加入或移出相册栏。
- **整理相册里的照片**：打开相册看网格，可以逐张或多选，把照片移到别的相册、移出相册或删除。
- **可靠保存**：保存一张一张排队进行，失败自动重试；顶部显示「保存中…」，真失败会提示并把照片放回待整理。
- 所有改动直接写进系统「照片」App，不上传任何地方。

### 只有 Windows 电脑也能装（GitHub 云端编译 + iloader）

#### 第一步：编译出 .ipa

仓库里的 `.github/workflows/build.yml` 会用 GitHub 免费的 Mac 服务器自动编译。

1. 用 **GitHub Desktop** 打开这个文件夹，Commit 后点 **Push origin**。
2. 打开仓库网页 → **Actions**，等最新一次「Build IPA」变成绿色 ✓（约 5 分钟）。
3. 点进去，在页面最下面 **Artifacts** 下载 `PhotoSorter-ipa`，解压得到 `PhotoSorter.ipa`。

#### 第二步：用 iloader 装到 iPhone

1. 安装 **iTunes**（必须是 Apple 官网版，不要用 Microsoft Store 版）：<https://www.apple.com/itunes/download/win64>。iloader 需要它来连接手机。
2. 从官方渠道下载 **iloader**：<https://github.com/nab138/iloader> 的 Releases 页面，或 iloader.app。
3. iPhone 用数据线连电脑，**解锁手机**，弹出「信任此电脑」时点信任。
4. 打开 iloader，用 Apple ID 登录（建议用小号），导入 `PhotoSorter.ipa` 安装。安装过程中保持手机解锁、亮屏。
5. iPhone 上：
   - **设置 → 隐私与安全性 → 开发者模式** 打开（第一次装完才会出现这个选项，开启后会重启）。
   - **设置 → 通用 → VPN 与设备管理** → 点你的 Apple ID → **信任**。
6. 打开「理片」，照片权限选 **「允许完全访问」**。

#### 更新到新版本

改完代码后重复上面的流程：Push → 等 Actions 编译 → 下载新的 ipa → 用 iloader 再装一次。新版会直接覆盖旧版，整理好的相册不受影响。

> 免费 Apple ID 签名的 app **7 天后会打不开**，用 iloader 把同一个 ipa 再装一次就好。
> 请一直用同一个 Apple ID、同一个工具安装，否则手机上可能出现两个「理片」。

#### 常见问题

| 问题 | 解决 |
|---|---|
| iloader 报 `bad device` | 解锁手机并保持亮屏；拔插数据线、换电脑机身 USB 口；重启 iloader |
| 手机上提示「不受信任的开发者」 | 设置 → 通用 → VPN 与设备管理 → 信任 |
| 找不到「开发者模式」 | 先用 iloader 装一次 app，选项才会出现 |
| 打开 app 看不到相册 | 照片权限要选「完全访问」，到 设置 → 理片 → 照片 修改 |
| Actions 是红色 ✗ | 点进去复制报错信息修代码 |

### 文件结构

```
PhotoSorter/
├── project.yml                 XcodeGen 配置（iOS 17+）
├── .github/workflows/build.yml GitHub Actions 云端编译
└── PhotoSorter/
    ├── PhotoSorterApp.swift     入口
    ├── SorterModel.swift        读相册、找未分类照片、归档 / 略过 / 删除 / 撤销、相册管理
    ├── SorterView.swift         主界面、两侧箭头、底部相册栏
    ├── AlbumManagerView.swift   新建 / 排序 / 删除相册
    ├── AlbumDetailView.swift    相册详情、逐张整理、多选操作
    ├── AssetImageView.swift     大图与缩略图加载（支持 iCloud 照片）
    ├── RootView.swift           权限处理
    └── Assets.xcassets          App 图标
```

---

## English

An ad-free alternative to Slidebox: go through every photo that isn't in an album yet, one at a time, and tap an album name at the bottom to file it.

### Features

- **Unsorted photos only**: a photo shows up only if it isn't in any album.
- **Album bar**: your existing iPhone albums are loaded automatically. Each card shows a cover, the name and the photo count; tap it to put the current photo in that album.
  - Sorted by photo count by default, so the albums you use most come first; positions don't jump around while you sort. You can switch to manual order under "管理" (Manage).
  - Long-press an album: open it / remove it from the bar.
- **Arrows beside the photo**: ‹ goes back one step (undo), › skips this photo. You can also swipe left to skip and right to go back.
- **Deleting**:
  - Tap the trash can (or swipe the photo up): marks it for deletion and moves on, with no prompt.
  - Long-press the trash can: "全部删除" (Delete all — iOS asks once, photos go to Recently Deleted and can be recovered for 30 days) or "全部恢复" (Restore all).
- **Manage albums**: create, rename, delete albums (photos are kept), add to or remove from the bar.
- **Organize inside an album**: open an album as a grid; go one by one or multi-select to move photos to another album, take them out, or delete them.
- **Reliable saving**: saves are queued one at a time and retried on failure; "保存中…" (Saving…) appears at the top, and a real failure is reported and the photo goes back into the queue.
- Every change is written straight to the system Photos library. Nothing is uploaded anywhere.

### Installing with only a Windows PC (GitHub cloud build + iloader)

#### Step 1: Build the .ipa

`.github/workflows/build.yml` builds the app on GitHub's free macOS runners.

1. Open this folder in **GitHub Desktop**, commit, and click **Push origin**.
2. Open the repo on github.com → **Actions** and wait for the latest "Build IPA" run to turn green ✓ (about 5 minutes).
3. Open the run, download `PhotoSorter-ipa` under **Artifacts** at the bottom, and unzip it to get `PhotoSorter.ipa`.

#### Step 2: Install it on your iPhone with iloader

1. Install **iTunes** from Apple's website (not the Microsoft Store version): <https://www.apple.com/itunes/download/win64>. iloader needs it to talk to the phone.
2. Download **iloader** from its official sources only: the Releases page of <https://github.com/nab138/iloader>, or iloader.app.
3. Connect the iPhone by USB, **unlock it**, and tap "Trust This Computer" when asked.
4. Open iloader, sign in with an Apple ID (a secondary one is recommended), import `PhotoSorter.ipa` and install. Keep the phone unlocked with the screen on during the install.
5. On the iPhone:
   - **Settings → Privacy & Security → Developer Mode**: turn it on (the option only appears after the first sideloaded install; the phone restarts).
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
6. Open 理片 and choose **"Allow Full Access"** for photos.

#### Updating

After a code change, repeat the flow: Push → wait for Actions → download the new ipa → install it again with iloader. The new version replaces the old one; your albums are untouched.

> Apps signed with a free Apple ID **stop opening after 7 days** — just install the same ipa again with iloader.
> Always use the same Apple ID and the same tool, or you may end up with two copies of the app.

#### Troubleshooting

| Problem | Fix |
|---|---|
| iloader says `bad device` | Unlock the phone and keep the screen on; replug the cable, use a USB port on the PC itself; restart iloader |
| "Untrusted Developer" on the phone | Settings → General → VPN & Device Management → Trust |
| No "Developer Mode" option | Install the app once with iloader first; the option appears afterwards |
| No albums in the app | Photo access must be "Full Access": Settings → 理片 → Photos |
| Actions run is red ✗ | Open it and copy the error to fix the code |

### Project layout

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
