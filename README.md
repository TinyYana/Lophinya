# Lophinya

`Paper` → `Folia` → [`Lophine`](https://github.com/LophineLabs/Lophine) → `Lophinya`

Folia 把世界切成好幾個 region 並行跑，效能是上去了，代價是既有插件幾乎全部要重寫。
官方自己講得很直白：對現有插件的相容性預期是零。

Lophinya 就是在處理這件事。一層核心的相容墊片，讓沒有官方 Folia 版本的插件，
用原本的 jar、原本的設定、原本的資料，直接在 Folia 上跑。

如果這個東西對你有用，給顆 Star 吧，我會很開心。⭐

---

## 先講清楚它不做什麼

這是為 Lycohinya 這台伺服器做的，不是通用發行版。所以：

它不承諾支援整個 Paper／Spigot 生態。目標是「任何 Paper 插件丟上去都能跑」沒錯，
但實際被驗證過的只有那台伺服器真的在用的東西。

它也不是效能 fork。效能全部來自 Folia 跟 Lophine，這一層加的東西只有相容性，
而且相容性通常是拿效能去換的。

然後我大概不會處理 issue。你可以自由拿去用，但別期待有人回。

## 三條規則

這三條不是理念宣傳，是實際上砍掉過很多寫法的東西。

**核心裡不能有 per-plugin 清單。** 一旦變成「插件升版、換版本、裝新的就要改核心程式碼」，
那「支援任何 Paper 插件」實際上就變成「支援有人記得去 vet 過的插件」，
而且營運的人要裝新插件還得等我出 release。這不合理。

**程式碼層面不拒絕任何插件。** 沒有 jar 黑名單，沒有白名單，可設定的清單也不行——
可設定只是把決定權搬走，機制還是交付出去了，等於背書「拒絕插件」是正常做法。
已知會出事的插件，寫進文件讓人自己判斷就好。載入失敗就讓它失敗，
把失敗變成功才是這裡要做的事。

**每一層都要能整層關掉。** 所有改動都掛在系統屬性後面，預設開，關掉之後行為逐字回到上游。
出事的時候第一件事是先關掉，不是先查是誰的錯。

## 目前處理了哪些東西

不逐個 patch 列，按主題分。全部是通用機制，程式碼裡沒有任何插件名稱。

**排程器**——被 region 架構拒絕的 Bukkit 同步任務，改用呼叫端當下真實的上下文派到對的 region。
async 任務則是在建構的那一刻捕捉「它是從哪裡被建立的」，而不是去猜 Runnable 裡面在做什麼。

**傳送**——Folia 沒發的 `PlayerTeleportEvent`／`EntityTeleportEvent`／`PlayerChangedWorldEvent` 補回來。
另外還有騎乘中的實體完全無法被傳送、跨 region 交接、乘客事件、跨世界座標偏移這幾個。

**方塊讀取**——跨 region 或跨世界的唯讀查詢，改由已經在記憶體裡的區塊回答。
區塊不在的話照舊大聲失敗，因為那需要載入，而那是另一回事。

**啟動期**——region 還沒開始 tick 之前，啟動執行緒本來就是全域狀態的唯一存取者。
那正是 Paper 主執行緒在同一時點的處境，而在 Paper 上這些插件呼叫是完全正常的做法。

**指令派送**——console 身分在 region 執行緒上的派送交回 global region，
但解析留在呼叫端，這樣同步回傳值才保得住。

**經濟與權限**——經濟 provider 的 per-account 序列化，還有補完上游同步化權限管理器時漏掉的兩個方法。

**計分板**——按 Folia 自己的規則開放：插件自有計分板任何 tick 執行緒都行，
主計分板的結構性變更要 global 執行緒，玩家指派要擁有那個玩家的執行緒。一律大聲失敗，不猜 owner。

**診斷**——被拒絕的排程跟 off-region 讀取會印出 jar、呼叫點、world、座標。
在這種平台上，一個沒有上下文的 NPE 等於沒有資訊。

### 不做的四件事

不關掉、不繞過、不吞掉 Folia 的 thread ownership 檢查（寫入那一側一行都沒動）。
不把任意同步任務丟給 `GlobalRegionScheduler`。
不從沒有上下文的 `Runnable` 去猜 region owner。
不偽造平台狀態去讓檢查通過。

那些檢查不是障礙。沒有它們，這裡每一個問題都會變成無法重現的資料競態。

## Kill switch

預設全開，加 `=false` 關掉，用 `-D` 傳給 JVM：

```
-Dlophinya.compat.crossRegionBlockRead=false
```

<details>
<summary>全部 24 個</summary>

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

## 建置

要 Java 25。

```bash
./gradlew applyAllPatches                      # 第一次會去 clone 上游，很慢
BUILD_NUMBER=1 ./gradlew createPaperclipJar    # → lophine-server/build/libs/*-paperclip-*.jar
```

`BUILD_NUMBER` 一定要設。沒設的話版本字串會是 `local-SNAPSHOT`，
有些插件會據此判定不相容然後自我停用，你會得到完全錯的結論——這個坑我踩過。

Windows 上先把 repo-local 的 `core.autocrlf` 設成 `false`、`core.longpaths` 設成 `true`，
不然 `.patch` 會被轉成 CRLF，套用直接壞掉。

## API

沿用上游 Lophine 的座標：

```kotlin
repositories { maven("https://repo.bacteriawa.com/repository/maven-public/") }
dependencies { compileOnly("fun.bm.lophine:lophine-api:26.2.build.+") }
java { toolchain.languageVersion.set(JavaLanguageVersion.of(25)) }
```

## 致謝

這個 fork 只做最上面那一層，下面全是別人的東西。

[**PaperMC**](https://github.com/PaperMC/Paper) 的 Paper 與 [**Folia**](https://github.com/PaperMC/Folia)——
region 化的設計是這一切的前提，而這裡所有的難題也都是因為它把「單一主執行緒」這個假設拿掉了。
Folia 的 thread ownership 檢查我是刻意不去繞的，那些檢查是唯一讓「哪裡不安全」看得見的東西。

[**LophineLabs／Lophine**](https://github.com/LophineLabs/Lophine)——直接上游。
生電行為的可再現性、可設定的原版特性、還有一大堆 Folia bug 修復都是它做的。

**Luminol**、**Leaves** 這些被 Lophine vendored 進來的專案——裡面的 region API 跟世界熱載入，
是這邊好幾個相容性修正能成立的基礎。

上游的 issue 請回報到上游，不要送來這裡。

## 授權

繼承自上游，見 [`LICENSE.md`](LICENSE.md)。
