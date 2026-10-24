# 理片 PhotoSorter

无广告的 Slidebox 替代品：显示所有还没放进任何相册的照片，点底部相册名就归档。

## 功能

- 读取 iPhone 里已有的所有相册，第一次打开时全部放到底部相册栏
- 只显示「未分类」照片（不在任何用户相册里的照片）
- 点相册名 → 当前照片放进该相册，自动跳下一张
- 左滑 / 点「跳过」→ 下一张；上滑 / 点「删除」→ 标记删除；右滑 / 左上角按钮 → 撤销上一步
- 标记删除的照片攒在右上角垃圾桶里，一次性删除（系统只弹一次确认，照片进「最近删除」，30 天可找回）
- 「管理相册」：新建相册、把相册加入/移出相册栏、拖动排序、删除相册（照片保留）
- 长按相册栏里的相册也能直接移出
- 可选从最新或最旧的照片开始
- 所有改动直接写进系统「照片」App，不上传任何地方

## 只有 Windows 电脑：GitHub 云端编译 + Sideloadly 安装

### 第一步：用 GitHub 免费的 Mac 云服务器编译出 .ipa

1. 登录 github.com，右上角 **+ → New repository**，名字填 `PhotoSorter`，选 Public 或 Private 都行，点 Create。
2. 新仓库页面点 **uploading an existing file**，把解压后 `PhotoSorter` 文件夹**里面的所有东西**
   （`.github` 文件夹、`PhotoSorter` 文件夹、`project.yml`、`README.md`）一起拖进去，点 **Commit changes**。
   - 确认 `.github/workflows/build.yml` 也传上去了。如果没有，就在仓库里点 **Add file → Create new file**，
     文件名填 `.github/workflows/build.yml`，把内容粘进去。
3. 上传完会自动开始编译。点仓库顶部 **Actions** 标签，等「Build IPA」出现绿色 ✓（大约 5 分钟）。
   - 如果是红色 ✗，点进去把报错复制给 Claude 修。
4. 点进那次成功的运行，页面最下面 **Artifacts** 里下载 `PhotoSorter-ipa`，解压得到 `PhotoSorter.ipa`。

### 第二步：用 Sideloadly 从 Windows 装到 iPhone

1. Windows 上安装（必须从 Apple 官网下载，**不要**用 Microsoft Store 版本）：
   - iTunes：<https://www.apple.com/itunes/download/win64>
   - iCloud for Windows（官网版）
2. 下载安装 **Sideloadly**：<https://sideloadly.io>
3. iPhone 用数据线连电脑，iPhone 上点「信任此电脑」。
4. 打开 Sideloadly，把 `PhotoSorter.ipa` 拖进去，填你的 Apple ID，点 **Start**，按提示输入密码/验证码。
   （建议用一个小号 Apple ID，这个 ID 只用来签名。）
5. iPhone 上：**设置 → 隐私与安全性 → 开发者模式** 打开（会重启）；
   **设置 → 通用 → VPN 与设备管理** → 信任你的 Apple ID。
6. 打开「理片」，允许照片访问时选 **「允许完全访问」**。

> 免费 Apple ID 签名的 app 7 天后会打不开，用 Sideloadly 再装一次同一个 .ipa 就行（不用重新编译），
> 整理结果都在系统相册里，不会丢。Sideloadly 里也可以开自动续签（需要电脑开着 Sideloadly 并和手机在同一 Wi-Fi）。

## 安装到 iPhone（有 Mac 的话）

1. 在 Mac 的 App Store 安装 **Xcode**。
2. 安装 XcodeGen 并生成工程：
   ```bash
   brew install xcodegen
   cd PhotoSorter
   xcodegen generate
   open PhotoSorter.xcodeproj
   ```
3. Xcode 里点左侧 PhotoSorter 工程 → **Signing & Capabilities** → Team 选你的 Apple ID（没有就点 Add Account 登录，免费的 Personal Team 就行）。
   如果提示 bundle id 被占用，把 `com.shang.photosorter` 改成别的，比如 `com.shang.photosorter2`。
4. iPhone 用数据线连 Mac，iPhone 上打开 **设置 → 隐私与安全性 → 开发者模式**（打开后会重启）。
5. Xcode 顶部选你的 iPhone，按 ▶︎ 运行。
6. 第一次运行如果提示「不受信任的开发者」：iPhone **设置 → 通用 → VPN 与设备管理** → 信任你的 Apple ID。
7. 打开 app 时允许照片访问，选 **「允许完全访问」**（只给部分照片的话读不到相册）。

> 用免费 Apple ID 安装的 app 7 天后会打不开，重新连电脑按一次 ▶︎ 就好，整理结果不会丢（都在系统相册里）。
> 付费开发者账号（$99/年）装的可用一年。

## 文件结构

```
PhotoSorter/
├── project.yml              XcodeGen 配置（iOS 17+）
└── PhotoSorter/
    ├── PhotoSorterApp.swift  入口
    ├── SorterModel.swift     读相册、找未分类照片、归档/跳过/删除/撤销、相册管理
    ├── SorterView.swift      主界面 + 底部相册栏
    ├── AssetImageView.swift  大图加载（支持 iCloud 照片）
    ├── AlbumManagerView.swift 新建/排序/删除相册
    └── RootView.swift        权限处理
```
