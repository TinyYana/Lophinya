<div align="center">

# Lophinya

**讓既有的 Paper／Spigot 插件，以原本的 binary、設定與資料，在 Folia 的 region 架構上安全運作。**

`Paper` → `Folia` → [`Lophine`](https://github.com/LophineLabs/Lophine) → **`Lophinya`**

</div>

---

## 這是什麼

Lophinya 是 [Lophine](https://github.com/LophineLabs/Lophine) 的 fork，為 Lycohinya 伺服器而做。

Folia 把世界切成多個 region 並行 tick，效能因此上得去，代價是**幾乎所有既有插件都要改寫**才能跑。
官方的說法很直接：對現有插件的相容性預期是零。

Lophinya 的核心產品就是處理這件事——**一層核心相容墊片**，讓那些沒有官方 Folia 版本的插件，
**不用改一行原始碼、不用換 jar、不用搬設定與資料**，就能在 Folia 上正確運作。

## 這不是什麼

- ❌ **不承諾支援整個 Paper／Spigot 生態。** 它是為一台實際運作的伺服器做的，不是通用發行版。
- ❌ **不是效能 fork。** 效能來自 Folia 與 Lophine，Lophinya 加的全部是相容性。
- ❌ **不提供支援。** 你可以自由使用，但請不要期待 issue 會被處理。

---

## 三條設計原則

這三條決定了程式碼長什麼樣，也決定了哪些做法被拒絕。

### 1. 核心不得內建 per-plugin 清單

任何「插件更新、換版本、裝新插件就要改核心程式碼」的設計都是錯的——那等於把每個插件的決定權
交給建置核心的人，於是「支援任何 Paper 插件」實際上變成「支援有人記得去 vet 過的插件」，
營運者也沒辦法在不等核心 release 的情況下裝新插件。

### 2. 程式碼層面不拒絕任何插件

沒有 jar 黑名單，沒有插件白名單，**連可設定的清單都沒有**。
已知會出問題的插件，該做的是把知識寫成文件讓人自己判斷，不是寫成伺服器程式碼去強制執行。
**載入失敗就讓它失敗——把失敗變成功才是這個專案要做的事。**

### 3. 每一層墊片都要能整層關掉

所有相容性修改都掛在系統屬性後面，預設開啟，關掉之後行為**逐字**回到未修改的上游。
出事的時候，第一件事永遠是「先關掉再說」，而不是「先查是誰的錯」。

---

## 相容墊片處理了哪些問題

依主題分組，不逐一列出 patch。全部都是通用機制，不含任何插件名稱。

| 主題 | 處理的問題 |
|---|---|
| **排程器** | 被 region 架構拒絕的 Bukkit 同步排程任務，改以呼叫端**當下真實的**上下文派送到正確的 region；async 任務在建構當下捕捉它是從哪裡被建立的，而不是從內容去猜 |
| **傳送** | 補回 Folia 未觸發的 `PlayerTeleportEvent`／`EntityTeleportEvent`／`PlayerChangedWorldEvent`；修正騎乘中的實體無法被傳送、跨 region 交接、乘客事件與跨世界座標 |
| **方塊讀取** | 跨 region／跨世界的**唯讀**方塊查詢改由已常駐的區塊回答；區塊不在記憶體時仍照原樣大聲失敗 |
| **啟動期** | 啟動執行緒在 region ticking 尚未開始前被視為全域狀態的合法擁有者——這是 Paper 主執行緒在同一時點的處境，也是極常見的 Bukkit 慣用法 |
| **指令派送** | console 身分在 region 執行緒上的指令派送交回 global region，解析仍留在呼叫端以保留同步回傳值 |
| **經濟與權限** | 經濟 provider 的 per-account 序列化；補完上游對權限管理器同步化時漏掉的方法 |
| **計分板** | 以符合 Folia 規則的方式開放 Bukkit scoreboard API：插件自有計分板可在任何 tick 執行緒操作，主計分板的結構性變更要求 global 執行緒，玩家指派要求擁有該玩家的執行緒——**一律大聲失敗，絕不猜測 owner** |
| **診斷** | 被拒絕的排程與 off-region 讀取都會印出可歸因的來源（jar、呼叫點、world、座標），而不是丟一個沒有上下文的 NPE |
| **相容閘門** | `folia-supported` 閘門預設**全部放行**，讓任何 Paper 插件都能載入；不能跑的就在真正的呼叫點失敗 |

### 硬性不做的事

- 不關閉、不繞過、不吞掉 Folia 的 thread ownership 檢查（**寫入側一律原封不動**）
- 不把任意同步任務丟給 `GlobalRegionScheduler`
- 不從沒有上下文的 `Runnable` 猜 region owner
- 不偽造平台狀態去讓檢查通過

---

## Kill switch

全部預設開啟，加 `=false` 關閉，以 `-D` 傳給 JVM：

```
-Dlophinya.compat.crossRegionBlockRead=false
```

<details>
<summary>完整清單</summary>

| 屬性 | 關掉之後 |
|---|---|
| `lophinya.compat.foliaSupportedAllowlist` | 回到上游的 `folia-supported` 閘門 |
| `lophinya.compat.restoreAsyncScheduler` | 回到上游的 async scheduler 行為 |
| `lophinya.compat.pluginSchedulerDispatch` | 不再派送被拒絕的插件排程任務 |
| `lophinya.compat.callerContextDispatch` | 不再依呼叫端上下文派送 |
| `lophinya.compat.asyncContextInheritance` | async 任務不再繼承建立當下的上下文 |
| `lophinya.compat.economySerialization` | 關閉經濟 provider 的 per-account 序列化 |
| `lophinya.compat.permissionLocking` | 回到上游的權限管理器同步化 |
| `lophinya.compat.teleportSemantics` | 回到上游的 `Entity#teleport` 行為 |
| `lophinya.compat.teleportEvents` | 不再補發傳送事件 |
| `lophinya.compat.passengerTeleportEvents` | 不再為乘客補發傳送事件 |
| `lophinya.compat.passengerTeleportCrossWorldOffset` | 回到上游的跨世界乘客座標 |
| `lophinya.compat.ridingTeleport` | 騎乘中的實體回到無法被傳送 |
| `lophinya.compat.teleportHandover` | 關閉跨 region 傳送交接 |
| `lophinya.compat.paperLibEnvironment` | 不再替換插件內嵌的 PaperLib |
| `lophinya.compat.commandDispatchHandover` | console 指令派送回到 stock 拒絕 |
| `lophinya.compat.scoreboardApi` | 關閉 Bukkit scoreboard API |
| `lophinya.compat.startupContextDispatch` | 關閉啟動期上下文派送 |
| `lophinya.compat.startupGlobalContext` | 啟動執行緒回到 stock 拒絕 |
| `lophinya.compat.crossRegionBlockRead` | 跨 region 唯讀方塊查詢回到 stock 拒絕 |
| `lophinya.compat.serverCurrentTick` | `MinecraftServer.currentTick` 回到凍結值 |
| `lophinya.compat.waypointRemakeConnections` | 回到上游未實作的狀態 |
| `lophinya.compat.diagnostics` | 關閉相容性診斷輸出 |
| `lophinya.compat.regionReadDiagnostics` | off-region 讀取回到未歸因的失敗 |
| `lophinya.compat.teleportRefusalDiagnostics` | 關閉傳送拒絕的診斷 |

</details>

---

## 建置

需要 **Java 25**。

```bash
./gradlew applyAllPatches                      # 首次會 clone 上游，很慢
BUILD_NUMBER=1 ./gradlew createPaperclipJar    # → lophine-server/build/libs/*-paperclip-*.jar
```

> ⚠ 測插件相容性時**一定要設 `BUILD_NUMBER`**。沒設的話版本字串是 `local-SNAPSHOT`，
> 部分插件會據此判定不相容而自我停用，你會得到錯誤的結論。

Windows 上請先設好 repo-local 的 `core.autocrlf=false` 與 `core.longpaths=true`，
否則 `.patch` 會被轉成 CRLF 而套用失敗。

## API

沿用上游 Lophine 的 API 座標：

```kotlin
repositories { maven("https://repo.bacteriawa.com/repository/maven-public/") }
dependencies { compileOnly("fun.bm.lophine:lophine-api:26.2.build.+") }
java { toolchain.languageVersion.set(JavaLanguageVersion.of(25)) }
```

---

## 致謝

Lophinya 站在四層別人的工作上面，**這個 fork 自己只做最上面那一層**。

- **[PaperMC](https://github.com/PaperMC/Paper)** — Paper 與 Folia。region 化的多執行緒設計是這一切的前提，
  而這個 fork 所有的難題也都源自它把「單一主執行緒」這個假設拿掉了。
- **[Folia](https://github.com/PaperMC/Folia)** — 本專案**刻意不去繞過**它的 thread ownership 檢查。
  那些檢查不是障礙，是唯一讓「哪裡不安全」變得看得見的東西；
  沒有它們，這裡每一個問題都會變成無法重現的資料競態。
- **[LophineLabs／Lophine](https://github.com/LophineLabs/Lophine)** — 直接上游。
  生電行為的可再現性、可設定的原版特性，以及大量 Folia bug 修復都來自它。
- **Luminol、Leaves** 等被 Lophine vendored 的專案 — 其中的 region API 與世界熱載入
  是本專案數個相容性修正得以成立的基礎。

上游的 issue 請回報到上游，不要送到這裡。

## 授權

繼承自上游專案，見 [`LICENSE.md`](LICENSE.md)。
