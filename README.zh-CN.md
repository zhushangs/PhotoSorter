# 理片 PhotoSorter

**简体中文** · [English](README.md)

无广告的 Slidebox 替代品：一张张查看所有还没放进相册的照片，点底部相册名就归档。

- [功能](#功能)
- [第一步：编译出 ipa](#第一步编译出-ipa)
- [第二步：安装到 iPhone](#第二步安装到-iphone)
  - [方式 A：iloader 直接安装（最简单，每 7 天要连电脑）](#方式-ailoader-直接安装)
  - [方式 B：SideStore + 自动续签（推荐，之后不用碰电脑）](#方式-bsidestore--自动续签)
- [常见问题](#常见问题)
- [文件结构](#文件结构)

---

## 功能

- **只显示未分类照片**：不在任何相册里的照片才会出现。
- **相册栏**：自动读取 iPhone 里已有的相册，放在底部。每个相册显示封面、名字和照片数量，点一下就把当前照片放进去。
  - 默认按照片数量排序，常用的在前面；整理时位置不会跳动。可在「管理」里改成手动排序。
  - 长按相册：打开相册 / 从相册栏移除。
- **照片两侧的箭头**：‹ 返回上一步（撤销），› 略过这张。也可以左滑略过、右滑返回。
- **删除**：
  - 点右上角垃圾桶（或上滑照片）：标记为待删除并跳到下一张，不弹窗。
  - 长按垃圾桶：「全部删除」（系统只确认一次，进入「最近删除」，30 天内可找回）或「全部恢复」。
- **管理相册**：新建、改名、删除相册（照片不会被删）、加入或移出相册栏。
- **整理相册里的照片**：打开相册看网格，逐张或多选，移到别的相册、移出相册或删除。
- **可靠保存**：保存排队进行，失败自动重试；顶部显示「保存中…」，真失败会提示并把照片放回待整理。
- 所有改动直接写进系统「照片」App，不上传任何地方。App 本身不存数据，过期或删掉也不会丢相册。

---

## 第一步：编译出 ipa

只有 Windows 电脑也可以：仓库里的 `.github/workflows/build.yml` 会用 GitHub 免费的 Mac 服务器编译。

1. 用 **GitHub Desktop** 打开这个文件夹，Commit 后点 **Push origin**。
2. 打开仓库网页 → **Actions**，等最新一次「Build IPA」变成绿色 ✓（约 5 分钟）。
3. 点进去，在最下面 **Artifacts** 下载 `PhotoSorter-ipa`，解压得到 `PhotoSorter.ipa`。

> ⚠️ Actions 的文件默认只保留 **90 天**。建议把 `PhotoSorter.ipa` 另存一份到电脑（不要放进这个仓库文件夹）。
> 丢了也没关系：Actions → 左边「Build IPA」→ 右边 **Run workflow**，几分钟后会重新编译一份。

---

## 第二步：安装到 iPhone

两种方式都用 **iloader**，都是免费 Apple ID。

**准备工作（两种方式都需要）**

1. 安装 **iTunes**，必须是 Apple 官网版，不要用 Microsoft Store 版：<https://www.apple.com/itunes/download/win64>
   **不需要装 iCloud for Windows**。
2. 从官方渠道下载 **iloader**：<https://github.com/nab138/iloader> 的 Releases 页面，或 iloader.app。
3. iPhone 设置好锁屏密码，用数据线连电脑，**解锁手机**，点「信任此电脑」。

### 方式 A：iloader 直接安装

适合偶尔用、不介意连电脑的情况。

1. 打开 iloader，用 Apple ID 登录（建议小号），选 **Import IPA**，选 `PhotoSorter.ipa` 安装。安装时保持手机解锁、亮屏。
2. iPhone 上：
   - **设置 → 隐私与安全性 → 开发者模式** 打开（第一次装完才出现这个选项，开启后会重启）。
   - **设置 → 通用 → VPN 与设备管理** → 点你的 Apple ID → **信任**。
3. 打开「理片」，照片权限选 **「允许完全访问」**。

> 免费 Apple ID 签名 **7 天后会打不开**（显示「不再可用」）。想用的时候连电脑，用 iloader 把同一个 ipa 再装一次即可，直接覆盖，相册不受影响。

### 方式 B：SideStore + 自动续签

设置一次后，手机每天自己续签，几个月不用也能随时打开，不用碰电脑。

#### 1. 用 iloader 装 SideStore

- 打开 iloader，用 Apple ID 登录，选你的 iPhone，安装 **SideStore (Stable)**。
  - 不用选 LiveContainer 版本（那是给装很多 app 或需要 JIT 的人用的）。
  - 如果 Stable 版打不开或一直报错，改装 **SideStore (Nightly)**。
- iPhone 上同方式 A 第 2 步：打开**开发者模式**，在 VPN 与设备管理里**信任**。

#### 2. 装 LocalDevVPN 并打开 SideStore 通知

- 在 App Store 装 **LocalDevVPN**，打开后点 **Connect**，允许添加 VPN 配置。它只在本机模拟一个电脑连接，SideStore 安装 / 续签时都要它开着。
- **设置 → 通知 → SideStore → 允许通知** 打开。iOS 27 上不开会导致续签报错「Source is not authorized」。不想被打扰可以把横幅和声音关掉，只留「允许通知」。

#### 3. 登录 SideStore

- 确认 LocalDevVPN 已连接，打开 SideStore，用**和 iloader 相同的 Apple ID** 登录。
- 提示 **revoke certificate（撤销证书）** 时点同意，这是正常的。
- 登录报错见下方[常见问题](#常见问题)。

#### 4. 用 SideStore 安装理片

- 在 iPhone 的 Safari 登录 GitHub → 仓库 → Actions → 最近绿色的运行 → 下载 `PhotoSorter-ipa`，在「文件」App 里点一下 zip 解压。
- 打开 SideStore → **My Apps** → 左上角 **「+」** → 选 `PhotoSorter.ipa`。
- **一定要从 SideStore 装**，SideStore 只能给自己装的 app 续签。之前用 iloader 装的旧理片可以先删掉（相册不受影响）。

#### 5. 建「理片续签」快捷指令

打开「快捷指令」App → 「+」新建，从下方搜索框依次添加：

| # | 动作 | 设置 |
|---|---|---|
| 1 | **设定 VPN** | LocalDevVPN → **连接** |
| 2 | **等待** | 30 秒 |
| 3 | **Refresh All Apps**（搜「SideStore」） | 点右边 › 展开，如有「运行时显示」就关掉 |
| 4 | **等待** | 60 秒 |
| 5 | **设定 VPN** | LocalDevVPN → **断开连接** |

把名字改成 **理片续签**，点右下角 ▶️ 手动跑一次，然后打开 SideStore 看天数是否回到 **7 DAYS**。

> 如果「Refresh All Apps」结束后弹出确认框、卡住后面两步：删掉第 4、5 步，另外建一个晚 5 分钟的自动化，只放「设定 VPN → 断开连接」。续签在弹窗前就已经完成了。

#### 6. 设成每天自动运行

「快捷指令」→ **自动化** → 「+」→ **特定时间**：

- 时间：选手机通常在充电、连 Wi-Fi 的时候，如 23:00 或凌晨 3:00。
- 重复：**每天**（偶尔失败几次也不怕，7 天内总有一次成功）。
- 选 **立即运行**，**通知**关掉。
- 下一步 → 在空白页搜 **运行快捷指令** → 选 **理片续签** → 完成。

测试：先把时间改成两三分钟后，等它自己跑完，打开 SideStore 看是否 **7 DAYS**，确认后再改回原来的时间。

> **仍然需要电脑的情况**：iOS 大版本升级后配对文件可能失效；或自动化连续 7 天以上都没成功（如长时间关机）。这时用 iloader 重新装一次 SideStore 即可。

---

## 常见问题

| 问题 | 解决 |
|---|---|
| 理片显示「不再可用」 | 免费签名过了 7 天。方式 A：用 iloader 重装；方式 B：检查自动化，打开 SideStore 点 Refresh All |
| iloader 报 `bad device` | 解锁手机并保持亮屏；重新插线、用电脑机身 USB 口；重启 iloader |
| 「不受信任的开发者」 | 设置 → 通用 → VPN 与设备管理 → 信任 |
| 找不到「开发者模式」 | 先装一次侧载 app，选项才会出现 |
| SideStore 登录报 `-80045` / `-80046` | Settings → User Customizations：关掉 **On-Device Anisette**，点 **Reset adi.pb**，从后台划掉 SideStore 重开，LocalDevVPN 连着再登录**一次**。别连续重试 |
| 登录报 `Anisette server returned HTTP status -1` / `-45061` | 试试打开 On-Device Anisette 后再登录；或 Diagnostics → Developer Options 清空数据库；或改装 Nightly 版 |
| 续签报 `Source is not authorized` | 设置 → 通知 → SideStore → 允许通知 |
| 不要随便改 **Anisette Client Configuration** | 那里是登录用的身份信息，改错会登录失败 |
| 理片里看不到相册 | 照片权限要「完全访问」：设置 → 理片 → 照片 |
| Actions 是红色 ✗ | 汇总页的 Annotations 会显示出错的代码行 |
| 手机上出现两个理片 | 换过 Apple ID 或安装工具。删掉旧的即可，相册不受影响 |

---

## 文件结构

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
