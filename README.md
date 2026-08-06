<div align="center">

# Lophinya

**讓既有 Paper／Spigot 插件用原本的 jar、設定與資料，直接在 Folia 上跑的核心相容墊片**

`Paper` → `Folia` → [`Lophine`](https://github.com/LophineLabs/Lophine) → `Lophinya`

[![Java](https://img.shields.io/badge/Java-25-orange?style=flat-square)](https://adoptium.net/)
[![Minecraft](https://img.shields.io/badge/Minecraft-26.2-brightgreen?style=flat-square)](https://github.com/TinyYana/Lophinya/releases)
[![Releases](https://img.shields.io/github/v/release/TinyYana/Lophinya?style=flat-square&color=blue)](https://github.com/TinyYana/Lophinya/releases)
[![Stars](https://img.shields.io/github/stars/TinyYana/Lophinya?style=flat-square&color=yellow)](https://github.com/TinyYana/Lophinya/stargazers)

覺得有用的話，給顆 ⭐ 我會很開心

</div>

---

## 為什麼有這個東西

Folia 把世界切成好幾個 region 並行跑，效能是上去了，代價是既有插件幾乎全部要重寫
——官方講得很直白，對現有插件的相容性預期是零

Lophinya 就是在處理這件事。一層核心的相容墊片，讓沒有官方 Folia 版本的插件，
用原本的 jar、原本的設定、原本的資料直接跑起來

## 它不做什麼

| | |
|---|---|
| **不承諾支援整個 Paper／Spigot 生態** | 目標是「任何 Paper 插件丟上去都能跑」沒錯，但實際驗證過的只有一台伺服器真的在用的東西 |
| **主線不是效能 fork** | 效能主要還是來自 Folia 跟 Lophine，這一層的主線只加相容性，而相容性通常是拿效能去換的。唯一例外是下面「實驗性」那節，一個預設關閉、需要另外選擇加入的效能功能 |
| **大概不會處理 issue** | 可以自由拿去用，但別期待有人回 |

## 三條規則

不是理念宣傳，是實際砍掉過很多寫法的東西

**核心裡不能有 per-plugin 清單。**
一旦變成「插件升版、換版本、裝新的就要改核心程式碼」，那「支援任何 Paper 插件」實際上就變成
「支援有人記得去 vet 過的插件」，營運的人要裝新插件還得等我出 release

**程式碼層面不拒絕任何插件。**
沒有 jar 黑名單，沒有白名單，可設定的清單也不行——可設定只是把決定權搬走，機制還是交付出去了。
已知會出事的插件寫進文件讓人自己判斷就好，載入失敗就讓它失敗，把失敗變成功才是這裡要做的事

**每一層都要能整層關掉。**
所有改動都掛在系統屬性後面，預設開，關掉之後行為逐字回到上游。
出事的時候第一件事是先關掉，不是先查是誰的錯

---

## 目前處理了哪些

全部是通用機制，程式碼裡沒有任何插件名稱

| 主題 | 內容 |
|---|---|
| **排程器** | 被 region 架構拒絕的 Bukkit 同步任務，改用呼叫端當下真實的上下文派到對的 region；async 任務在建構那一刻捕捉「它是從哪被建立的」，而不是去猜 `Runnable` 裡在做什麼 |
| **傳送** | 補回 Folia 沒發的 `PlayerTeleportEvent`／`EntityTeleportEvent`／`PlayerChangedWorldEvent`；修正騎乘中的實體完全無法被傳送、跨 region 交接、乘客事件、跨世界座標偏移 |
| **方塊讀取** | 跨 region／跨世界的唯讀查詢改由已在記憶體的區塊回答；區塊不在就照舊大聲失敗，因為那需要載入，是另一回事 |
| **啟動期** | region 還沒開始 tick 之前，啟動執行緒本來就是全域狀態的唯一存取者——那正是 Paper 主執行緒在同一時點的處境 |
| **指令派送** | console 身分在 region 執行緒上的派送交回 global region，解析留在呼叫端，同步回傳值才保得住 |
| **經濟與權限** | 經濟 provider 的 per-account 序列化；補完上游同步化權限管理器時漏掉的兩個方法 |
| **計分板** | 按 Folia 自己的規則開放：插件自有計分板任何 tick 執行緒都行，主計分板結構性變更要 global 執行緒，玩家指派要擁有那個玩家的執行緒。一律大聲失敗，不猜 owner |
| **診斷** | 被拒絕的排程與 off-region 讀取會印出 jar、呼叫點、world、座標。在這種平台上，一個沒有上下文的 NPE 等於沒有資訊 |

### 不做的四件事

- 不關掉、不繞過、不吞掉 Folia 的 thread ownership 檢查（寫入那一側一行都沒動）
- 不把任意同步任務丟給 `GlobalRegionScheduler`
- 不從沒有上下文的 `Runnable` 去猜 region owner
- 不偽造平台狀態去讓檢查通過

那些檢查不是障礙。沒有它們，這裡每一個問題都會變成無法重現的資料競態

---

## 實驗性：村民尋路平行化

村民尋路（走去工作站、走去床鋪、閒晃）預設還是走原本的同步搜尋，在 region 自己的
tick 執行緒上算完才繼續。這個功能把搜尋本身移到獨立的 worker thread 做，owner
thread 只負責送出請求、等結果、驗證之後再套用——閒置的 worker 有上限、有 deadline，
逾時或驗證失敗就整批丟棄，不會讓 tick 執行緒卡住。

跟上面「目前處理了哪些」不一樣：那些是相容性功能、預設全開；這個是**效能**功能、
**預設關閉**，兩個 flag 都要開才會生效：

```
-Dlophinya.parallel.enabled=true
-Dlophinya.parallel.navigation=true
```

開發環境（12 核心）量到的數字：100～1000 隻村民同時尋路時，平均 tick 成本比同步版
低，規模越大差距越明顯；但這是開發機數字，不是正式服規格下的保證。目前狀態是可以
部署到隔離測試服，還沒有正式服的長期運行紀錄。關掉的話行為逐字回到原本的同步尋路，
沒有殘留狀態。

---

## Kill switch

預設全開，加 `=false` 關掉，用 `-D` 傳給 JVM

```
-Dlophinya.compat.crossRegionBlockRead=false
```

<details>
<summary><b>全部 24 個</b></summary>

<br>

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

要 Java 25

```bash
./gradlew applyAllPatches                      # 第一次會去 clone 上游，很慢
BUILD_NUMBER=1 ./gradlew createPaperclipJar    # → lophine-server/build/libs/*-paperclip-*.jar
```

`BUILD_NUMBER` 一定要設。沒設的話版本字串會是 `local-SNAPSHOT`，有些插件會據此判定不相容然後自我停用，
你會得到完全錯的結論——這個坑我踩過

Windows 上先把 repo-local 的 `core.autocrlf` 設成 `false`、`core.longpaths` 設成 `true`，
不然 `.patch` 會被轉成 CRLF，套用直接壞掉

## API

沿用上游 Lophine 的座標

```kotlin
repositories { maven("https://repo.bacteriawa.com/repository/maven-public/") }
dependencies { compileOnly("fun.bm.lophine:lophine-api:26.2.build.+") }
java { toolchain.languageVersion.set(JavaLanguageVersion.of(25)) }
```

---

## 致謝

這個 fork 只做最上面那一層，下面全是別人的東西

| | |
|---|---|
| [**Paper**](https://github.com/PaperMC/Paper) ／ [**Folia**](https://github.com/PaperMC/Folia) | region 化的設計是這一切的前提，而這裡所有的難題也都是因為它把「單一主執行緒」這個假設拿掉了。Folia 的 thread ownership 檢查我是刻意不去繞的，那些檢查是唯一讓「哪裡不安全」看得見的東西 |
| [**Lophine**](https://github.com/LophineLabs/Lophine) | 直接上游。生電行為的可再現性、可設定的原版特性、還有一大堆 Folia bug 修復都是它做的 |
| **Luminol**／**Leaves** | 被 Lophine vendored 進來的專案，裡面的 region API 跟世界熱載入是這邊好幾個相容性修正能成立的基礎 |

上游的問題請回報到上游，不要送來這裡

## 授權

繼承自上游，見 [`LICENSE.md`](LICENSE.md)

<div align="center">

<br>

**如果這個東西幫到你，給顆 ⭐ 吧**

</div>
