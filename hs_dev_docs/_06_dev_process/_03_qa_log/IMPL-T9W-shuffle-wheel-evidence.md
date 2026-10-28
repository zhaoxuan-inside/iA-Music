# 实现证据：D6-7「随机」轮盘页应用侧落地（S4 事后增量）

- **task_id**：`iA-Music-BUILD-5`（增项 T9W，非 S6 提取管线域；挂 S4 播放页/REQ-NAV-02 会话面）
- **触发**：开发者指令（2026-10-20 会话原话）「现在的页面少了一个半圆形滑动切歌的页面」= DEC-006 D6-7（轮 16 终稿，开发者逐轮确认 CONFIRMED）的「随机」经典兆赫唱片轮盘页在 Flutter 应用侧缺失（原型 `main_prototype.html` `#p-shuffle` States 已确认，`app/lib/ui/` 无对应页面/路由）。
- **裁决依据**：D6-7 终稿无需重新拍板——应用侧按终稿原样复刻；不新增产品语义。
- **刷新时间**：2026-10-20（Asia/Shanghai）

## §1 视觉/交互锚（原型逐像素实测 → 应用侧）

参考图 `10_classic_radio_wheel.png`（610×1008）映射手机内部 378×818 设计坐标，整盘 `FittedBox(contain)` 等比缩放（`shuffle_page.dart` 顶部注释全档）：

| 槽位 | translate | rotate | 尺寸/备注 | z |
|------|-----------|--------|-----------|---|
| out（出场走廊：被轮回撕裂卡的旧位实体，向头顶外飞出淡去） | (-202.4, -34) | −20.5° | 240×240，opacity→0 | 5 |
| p2 | (-119.3, 118.9) | −15.4° | 240×174 横条 | 10 |
| p1 | (-89.7, 134.2) | −10.2° | 240×174 | 20 |
| in（入场走廊起点：torn 卡自底部淡入落位） | (-163.4, 796.6) | +19.5° | 240×174，opacity 0.55→1 | 22 |
| nxt2 | (-157.7, 642) | +9.5° | 240×174 | 23 |
| nxt | (-91.2, 476.2) | +9.5° | 240×174 | 25 |
| cur（方形焦点） | (-38.3, 257.1) | −0.7° | 240×240 | 40 |

- 卡组**左沿出血**（tx<0）；待播横条顶边紧贴上一卡底边（终稿套嵌）；转盘轴心 (-143.8, 464)。
- **卡恒满 5 张（开发者 2026-10-20 复验澄清裁决，覆盖早轮「out 抑制 p1/末位越界缺卡」细节）**：五主道
  p2/p1/cur/nxt/nxt2 由**环形回绕解析**（mod 池长，负位回尾）——任何站位恒有真歌卡，上滑=轮转卡片
  序列不缺位（池=5 时稳态恰好=整池 5 首全在盘上且互不重复）；torn 卡（被筒回绕到另一头的撕裂位，
  池 5 时=旧 p2 卡）拆双实体走 in/out 走廊（先头顶外飞出淡去、再自底部淡入落位，630ms 清窗后主道
  trackId 元素接管；走廊键=laneString 与主道 trackId 键分道防 Stack key 冲突）。
- 层次**仅靠旋转渐进 + z 序**：静态卡无模糊/缩放/透明度弱化（C67/WIRE 红线）；走廊卡允许淡（其
  begin 淡值随标量补间逐帧走=§8.1）。
- 切歌动效：**轮转=卡片沿转盘轴心 (-143.8, 464) 的弧线转动**（标量五元组端值 + **极坐标轨迹插值**：
  位置由转轴极坐标角度+半径绕轴心同步收敛逐帧现算，轨迹=圆弧——**2026-10-20 复验四轮裁决
  「卡片的滚动应该是沿着圆心转动，而不是所有的卡片都进行上移后再进行切换」=§8.3**；550ms
  `cubic-bezier(.32,.72,.28,1)`；element 以 trackId 为 key 跨槽位迁移，TweenAnimationBuilder
  端值变更从当前值续飞——快连切/池重采样不回跳；**2026-10-20 打磨轮=每帧现算矩阵**）；
  旧当前卡 cur→p1 为同一元素的车道迁移；横条 240↔174 平滑过渡。
- 手势：**仅上滑切歌**（阈值 40px；无下滑、无点击切歌）；任意方向拖拽**卡组层**跟手（上移 ≤260px + 绕轴心微顺时针 0.045deg/px）松手 320ms 回弹，**信息区/控件/提示定层不动（2026-10-20 复验二轮裁决「上滑只能滑动卡片，不是整个页面都动」=§8.2）**；播放自然结束由 service 随机模式轮转承接=播完自动上转。
- 信息区右聚（「随机」站名/歌名/歌手/进度条（accent `#4BE0A3`）/时间）随焦点卡实时同步；控件右聚🗑⏸♥（`shuffle_dislike`/`shuffle_toggle`/`shuffle_heart`）；底部「上滑 — 播放下一首」提示（原话=WIRE §5.11）。

## §2 实现面（files）

- **`app/lib/ui/play/shuffle_page.dart`（新）**：全量终稿复刻（**2026-10-20 打磨轮重构=标量补间/ValueNotifier 变换层/微补间进度/入场淡，§8 全档；键位/语义/手感参数不变**）；数据面与胶片页共享同一 `PlaybackService` 随机会话（playback_prd「与胶片页共享同一随机池、当前曲与下一首语义」）；封面=TrackCover（无素材=首字母色块）；红心=PlaylistService；垃圾桶=dislikeThenNext（少播名单）；`PlaybackNoticeBar` 顶部提示条同款。刷新面=status 流订阅 + 500ms 定拍 Future 直读兜底（IMPL-S2 §4-L3 broadcast 跨 zone 不成帧实测口径）。
- **`app/lib/ui/shell/home_shell.dart`**：新增 `jumpToTab(int)`（文字导航跳转缝）+ `openShufflePage()`（壳层推页缝；音乐空间随机入口 `onShuffleRequested` 走此缝）。
- **`app/lib/ui/library/library_list_page.dart`**：新增 `onShuffleRequested` 页缝；**推页语义归位按钮层** `_onShuffleEntryPressed`（见 §5）；`startShuffle` 保持纯开播 API（无导航副作用，测试公共面不变）。
- **`app/lib/ui/play/play_page.dart`**：随机模式 AppBar 增 `play_wheel_entry`（Icons.style）→ 推 ShufflePage（同会话互跳）；轮盘页 AppBar 同位反跳胶片页（`shuffle_back_film`）。

## §3 测试证据（DEC-010 全真；无 Fake/Mock/回放）

- `flutter analyze` 全仓 **0 issues**。
- **`app/test/ui/s4_shuffle_wheel_test.dart`（新）2 用例全过（真 mpv 引擎 + 真 fixture + 真 drift 内存库，tester.runAsync 纪律；12s 内完成）**：
  1. 形态锚：真引擎随机开播→暂停定锚→轮盘装配（`shuffle_page`/`shuffle_deck`）；**TrackCover 数量锚
     =5（2026-10-20 开发者裁决「卡恒满 5 张，不因上滑缺失」：槽位环形回绕，p2/p1/cur/nxt/nxt2 五道
     恒满位——早轮「cur/nxt/nxt2/in=4 卡」锚按开发者在案裁决更新，原型细节覆盖理由已记档 §8.1）**；
     信息区随焦点卡同步（真 DB title 面）；「上滑 — 播放下一首」原话 + 三控件在位；红心 tap →
     `favoriteCount()==1` 且落在焦点卡真行。
  2. 手势锚：上滑 120px（越阈）→ `snapshot.currentTrack` 真前移（引擎真换曲）；下滑 90px → current 不变（D6-7 红线）；垃圾桶 → 立即下一首 + `lastNotice` 原话「已减少这首的推荐」 + `few_watch_list` 真行含被弃曲 id。
- 全量回归（门 λ 棚定档后多轮）：宿主域（ui/playback/widget）**36/36 全绿**；全量批跑两轮失败面均**全部落在既有的真网络窗口族**（cover CAA/iTunes ×5、extract B站真链/迁移/取消 ×6（含 `NetworkLostException: 链接解析失败` 如实录）、lyrics LRCLIB 窗 ×3），**零个 T9W/播放域新败**；单件复核 s3 3/3、cover_network 4/4 绿——照既有挂账记档口径，非本次改动回归。

## §4 数据/联动一致性

- 轮盘页与胶片页互跳共享会话：`service.status` 流 + 快照直读双通道；两页 `PlaybackNoticeBar` 同缝。
- `play_page`（胶片页）未改播放语义，仅增轮盘入口按钮（随机模式条件渲染）。
- 深色主题先行（应用态当前深色只读 DEC-005 双主题位）；浅色主题挂账（§6）。

## §3.5 模拟器全真 E2E（2026-10-20 演练窗口；真 UI 驱动 + 真引擎真播放，E2E 全链 14s All tests passed）

- `app/integration_test/s4_shuffle_wheel_test.dart`（新，machine log 实证）：真安装包真进程真库（force-stop 独占）+ 真文件种子（宿主 `adb push /data/local/tmp/wheel`（ASCII 名避 Win 控制台编码实证）→ 应用进程真拷贝 docs/repo → `addRepositoryAndScan` 真扫描 5 首入库）→ `pumpWidget(IaMusicApp)` 真壳 → **tap `shuffle_entry`（按钮层推页真链）** → 轮盘装配 → **真 mpv_audio_kit Android 面真开播**（探针实证：startRandom 372ms 返回、playing=true、pos 推进——S3 DoD3「真平台」此前挂账首破，x86_64 模拟器先行）→ 暂停定锚（EOF 短样本轮转污染防线）→ **上滑 140px=真引擎真换曲** + `shuffle_title` 随焦点卡变化 → 下滑 90px 不切 → 垃圾桶=立即下一首 + `few_watch_list` 真行 → 红心=favoriteCount+1。卡片数取**下界 3 断言**（EOF 诚实语义；宿主锚的精确五卡=卡恒满裁决恒真，全时刻成立）。
- **引擎 Android 首实证**：mpv_audio_kit 在 Android（x86_64 模拟器）startRandom/播放/next/暂停全链真值通过（此前 RV-A/真平台播放从未演练）——**真机 arm64 挂账沿既有**。
- **§8.1 轮复跑（卡恒满 5 机制落地后）**：E2E 同链重跑 **16s All tests passed**；宿主 2 锚（含新 5 卡形态锚）全绿；analyze 0 issues；宿主域串行回归 **78/78 全绿**（ui/playback/playlists/data/scan/widget_test；**并行多目录批跑下 s3 三用例 did-not-complete=引擎/负载争用抖动，单文件秒绿实证非回归**）。全量批跑失败面=既有真网络窗口族（cover×2/lyrics×1 当轮现值），零 T9W 新败。

## §4.5 排障实录（E2E 演练期，2026-10-20）

1. **本批产品级缺陷修复（NAV-01 保活实测违规，修复实录）**：壳层/曲库页 Column 的条件子项（mini 条/播放条 `if (svc != null)`）**无 key 位置配对**——svc 悬现时列表长度变化、Positional reconciliation 把 Expanded 内容（整个曲库页 State/流状态）连根掀掉（`deactivate` 实录：按钮链在 `await startRandom` 区间内页面 State 已卸载 → `mounted=false` 静默不推页）。修复=壳层三子项/曲库页三子项**全键**（`home_notice/home_content/home_strip`、`lib_notice/lib_content/lib_strip`）。影响面=每一次首次起播（mini 条悬现）都会重置曲库页滚动态——**既有产品质量级缺陷**，本档修复并已回归（ui/playback/widget 36/36 全绿）。
2. **skipOffstage 假阴性口径**：全屏路由压栈后底下的 HomeShell 进 Offstage，`find.byType` 默认不找——E2E 取数器须 `skipOffstage: false`（同 T9C 其.. 惊报「无推页」的一次复核定位）。
3. **arb push Future 语义**：`Navigator.push` 的 Future 在 **pop 时**才完成——壳缝若强 await=自锁（排障探针曾自锁 25min 实测）；推页一律 unawaited。
4. **fixture 目录污染事故（如实记档）**：为 push 种子复制的 wheel01..05 曾误留 `test/fixtures/library_smoke` → s2 锚「10 首」实测 15 首基线破坏 → 删除复原后 36/36 全绿。**教训：真文件 fixture 增删须走宿主主 fixture 增补流程（改用规范命名副本）**。
5. 短样本 EOF 轮转污染断言的处理：E2E 进入轮盘后立即 `shuffle_toggle` 暂停定锚（开关后各行断言稳定）。
6. **动效重构排障（2026-10-20 验收打磨轮，§8 全档）**：
   - **宿主手势锚初跑两败（下滑误切歌红线近踩）**：重构把「手势逻辑增量 `_dragY`」与「视觉回弹补间」耦合——上滑后 `_dragY` 残值（−120）未被清零（test fake-async 下回弹 controller 的 ticker 不走帧，吞掉了松手回弹期的视觉清零），下次下滑 90px 后累计 −30…若任何中间帧 ≤ −40 即误触发 next()。修复=**增量态每手势隔离**：`_dragEnd`/`_dragCancel` 里 `_dragY` 即刻归零、回弹只动 `_dragNotifier`（视觉值）与 `_snapAnim`；`_onSnapTick` 不再写 `_dragY`。修复后两锚连跑全绿（36/36）。**红线教训：手势判定输入层的增量状态不得与表现层补间共享同一可变量**。
   - **E2E 双绿后置**：修复后 `flutter test integration_test/s4_shuffle_wheel_test.dart -d emulator-5554` 真 UI 真引擎 E2E 14s All tests passed（同链同耗时）。
7. **模拟器复验环境重建排障（真实录，非缺陷）**：E2E runner 被宿主击杀（SEEDED-OK count=5 后 kill 保安装+实库）→ 私装 APK 变体事故——宿主随后重跑 `flutter test integration_test/seed_probe_test.dart`（§7 结构）重建种库，但 **kill 发生在 runner 卸载/重装收尾之前**，仓内 `app-debug.apk` 已被 integration_test 轮**重建成 test-listener 变体**（VM Service 实录：rootLib=flutter_tools… flutter_test_listener/listener.dart，main 卡驻留泵、永远闪屏）——误判生产 main 卡死 4min 的排障弯路；`flutter build apk --debug` 重产标准包 install 后 28s 冷启动正常出「音乐空间」。**教训：integration_test build 会覆盖 `app/build/app/outputs/flutter-apk/app-debug.apk` 路径？否——** 正确口径=seed 探针轮的 gradle assembleDebug 产物落同路径，缀后手动 `adb install` 装上的即测试变体；手动复验前必须 `flutter build apk --debug` 重产标准包。探针脚本本体按 DEC-010 用完即删（复跑链见表 §7）。
8. **活树结构「卡不全」假警报（排障实录，非缺陷）**：手动验收期多次截屏看到「待播三卡全灭/顶条幻影」→ 疑重构 Broken；VM Service heap 直读实锤（getClassList→getInstances→getObject `PlaybackService` 实例字段）：`_current=4`、`_playing=false`、池 5——**EOF 自动轮转已把 idx 推到尾位（idx4）**，p2/p1 两横条 +方形焦点=尾位唯一可指装配（nxt/nxt2/in 越界位，spec 槽位映射正确）；暂停后目视核=结构完全符合 §1 表。**结论：EOF 短样本轮转入场即污染任何「等待型/单时刻」目视断言——手动验收节奏须先暂停再核。**
9. **E2E 正常收尾=卸包清库实录（§8.1 复跑轮）**：§8.1 E2E 正常通过后（All tests passed），工具对测试变体包做卸载收尾 → **应用实库随包消亡**（重装标准包后「曲库为空」截屏实锤）——早轮 seed 环境靠 kill 保数据成立，而**正常完成的 E2E 轮结束时数据即不可保**；手动复验环境重建顺序必须=「E2E 轮 → seed 探针轮（驻留不退出）→ kill → 标准包 -r 换装」（§7.1 口径，探针须**真驻留泵**防 runner 收尾卸包）。
## §5 排障实录（改档纪律定档，2026-10-20）

1. **runAsync 体内 push = 违 REENTRANT 纪律**：初版把推页嵌进 `startShuffle`（s3 锚在 `tester.runAsync` 体内调用）→ s3 三锚齐爆 `Reentrant call to runAsync() denied` + 3min 超时。归因=推页触发的帧管线在调用方 runAsync 区间内展开。
2. **后帧 flush push = 污染命中面**：改后帧（postFrameCallback）推页 → s3 REQ-PLAY-04 的「清空」tap 命中点与他面重合（finder 取点 744,92 实测命中 544,92 面上）→ `少播名单已清空` 断言空命中。开关对照实证（flush 禁用=全绿、启用=复现）。
3. **定档**：推页属**按钮层语义**（用户 tap→onPressed→push），`startShuffle` 回归纯开播 API（s3 公共面零变化）；按钮链＝开播→非空推轮盘页（页缝/独立挂载双路径同语义）。定档后 s3 3/3 全绿、wheel 2/2 全绿。

## §6 挂账

- **浅色主题**：DEC-005 双主题应用态未启用；轮盘页现深色配色（`#0F1215` 底/白系文字/`#4BE0A3` accent），S9 视觉收口时随全局主题体系接入。
- **E2E 状态上移**：模拟器（x86_64，AVD `ia_s5_cover`）全真链 14s **实跑完成**（§3.5，含主链四锚真值）；**arm64 真机窗口核（RV-A 沿既有挂账）**+「半圆手感」主观逐屏核（拖拽阻尼/屏占比观感的目视评审）待开发者真机窗口。
- **EOF 自动上转（播完轮转）的真平台核**：**模拟器已实证（2026-10-20 排障探针，已删）**——真引擎 startRandom 后 12s 时间线逐帧实录：EOF 逐曲推进（~2s/曲）+ 队列走完 `_roundTail`→池重采样开新轮（idx 4→回 0=新轮）+ distinct=5 全池走到；真机 arm64 长时长文件核仍沿 RV-A 挂账。**开发者验收裁决加注**：随机=整池无限循环（REQ-PLAY-03「FM 无限电台」语义与实现一致，开发者拍板重申）。
- **拖拽阻尼 0.045deg/px 为实现值**：原型档未收录该系数（原型为连续 transform 未离散），若日后 Control 面要求可回原型补测。

## §7 命令复跑链

```bash
cd app && export HTTPS_PROXY=http://127.0.0.1:7897
flutter analyze
flutter test test/ui/s4_shuffle_wheel_test.dart
flutter test test/playback/s3_ui_anchor_test.dart
# E2E（模拟器全真，已完成=IMPL-T9W §3.5；复跑同链）：
adb shell "pm uninstall com.hardstone.ia_music"  # 或 am force-stop（幂等 harness 已兼容残留）
flutter test integration_test/s4_shuffle_wheel_test.dart -d emulator-5554
# 注：种子推 /data/local/tmp/wheel（ASCII 名）；探针文件已按 DEC-010 删除
```

### §7.1 手动复验环境重建链（2026-10-20 实录补全；seed 探针本体已删=重写同款）

```bash
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
# ⓪ 种子推送（fixture 原件，ASCII 目标名）
cd app
adb shell mkdir -p /data/local/tmp/wheel
adb push test/fixtures/library_smoke/探曲01.mp3 /data/local/tmp/wheel/wheel01.mp3   # …02/03.mp3 04/05.m4a 同理
# ① 标准包（integration_test 轮会污染 app-debug.apk 生成 test-listener 变体=§4.5-7 教训）
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# ② seed 探针（重写 integration_test/seed_probe_test.dart=§7 同款：真拷贝 docs/repo →
#    addRepositoryAndScan → print('SEEDED-OK count=N') → 驻留泵等击杀；验完即删）：
flutter test integration_test/seed_probe_test.dart -d emulator-5554   # 后台跑
# ③ 宿主见 SEEDED-OK count=5 后 kill dart runner（外部击杀=known 'Some tests failed' 假象）
#    注意：kill 后包=**integration 变体**（rootLib=listener.dart），须 ① 重产标准包再 install
# ④ 启动核对：am start -n com.hardstone.ia_music/.MainActivity（冷启动 ~28s 为常态非卡死）
#    驱动：adb shell input tap 1015 202（随机入口）→ 轮盘页；暂停钮≈(693,2253)；
#    手动验收节奏=先暂停再核（EOF 短样本 ~2s/曲 轮转污染，§4.5-8）
```

## §8 动效质量打磨（2026-10-20 验收轮；「随机页面 UI 动画有点差」开发者反馈触发）

**不改语义/键位/手势红线**，只修动效产因。四处根因与修复（`app/lib/ui/play/shuffle_page.dart` 重构）：

1. **矩阵插值抽动（最重产因）**：槽位迁移原先 `AnimatedContainer.transform` 对两枚复合矩阵
   （translate→rotate→translate 反折）直接 `MatrixTween.lerp`——矩阵乘积的插值 ≠ 枢轴旋转的
   插值，动画期枢轴与几何不同步=卡片"绕无所谓"抽动。重构=**标量逐项补间**（`_SlotP`：
   tx/ty/角度/高度/淡五元组，`TweenAnimationBuilder` 端值变更从当前值续飞——ImplicitlyAnimated
   语义，快连切/池重采样不回跳）+ 每帧现算矩阵（pivot h/2 跟随插值，动画期枢轴恒与几何一致）。
   卡内 TrackCover 移入 builder `child:` 常驻参数层=补间帧封面零重建。
2. **拖拽掉帧（jank 根除）**：原先每 drag update setState → 整页 5 张封面全重建。重构=
   `ValueNotifier<double>(_dragNotifier)` 只 rebuild 纯 Transform 一层（卡组/封面/信息区在
   `child:` 常驻）；松手回弹=显式 `AnimationController`（320ms easeOutCubic 口径保持）。
   拖拽判定语义原样（仅上滑阈值 40px=next()；`clamp(-260..0)`+0.045deg/px 绕轴心）。
3. **进度条步进感**：position 500ms 定拍 tick 直跳 ∘→ `TweenAnimationBuilder<double>` 260ms
   linear 微补间（tick 间滑行）；进度条键位 `shuffle_progress` 保持（其 Container 内层）。
4. **inFloor 入场淡落地**：终稿原型 in 槽=淡（§1 表 opacity→0.55 口径随 `_SlotP.opacity`
   逐帧走）；此前静态 1.0=违档。out 出场卡=同五元组（cur→out 淡出）。
   **入档要件**：宿主 2 锚 + 壳/曲库/胶片页宿主域回归 36/36 全绿 + analyze 0 + E2E 14s 全绿
   （§4.5-6 排障两刀）；模拟器真机驱动截屏核=轮转中间帧（迁移/标题随焦）/落定帧/尾位装配
   （§4.5-8）。手势判定语义零改动（** Álgebra 红线=id 键位/手感参数 40px/260deg/320ms 均保持）。

## §8.1 轮盘恒满 5 卡机制（2026-10-20 复验二轮收口；开发者澄清裁决触发）

**触发（开发者复验原话）**：「页面上滑，滑动的是歌曲卡片，歌曲卡片永远都会有 5 个，不会因为上滑
导致缺失」——早轮 7 槽位体系在卡恒满口径下暴露缺位面：idx=0 无已播史（p1/p2 缺 2 张）、轮转期
「out 在场抑制 p1 重影」=p1 槽瞬空、尾位 idx=池尾（nxt/nxt2/in 越界全灭）、池重采样换轮新帧更甚。
**产品语义归 D6-7 细节覆盖**（视觉完整性 > 早轮走廊细节；宿主形态锚 4→5 按开发者在案裁决同步，
理由已记档 §3-1）：

1. **五主道环形回绕解析**：`_laneIndex` = `(currentIndex + rel) mod poolLen`（负位回尾）——
   p2/p1/cur/nxt/nxt2 任何站位恒有真歌卡；pool=5 时五道恰好=整池五首全在盘上且互不重复
   （const 表 `_laneRel`：cur 0/p1 −1/p2 −2/nxt 1/nxt2 2）。
2. **torn 走廊机制（取代旧 `_outId` cur→out 淡出+抑制体系）**：车道回绕撕裂位（新车道在旧车道
   下方=「新车道 rel > 旧车道 rel+0.5」，`_laneByTid` 每曲上一次车道图；换轮=resample 换 queue
   实例 → 车道图重置不做撕裂迁移）拆双实体：**exit 走廊**（旧车道几何起→out 几何淡出）+ **entry
   走廊**（in 0.55 淡起→新车道落位），630ms（`kTurnCleanup`）清窗由主道 trackId 元素接管=几何/
   不透明度连续无跳。走廊键=laneString（`exit_$tid`/`entry_$tid`）与主道 trackId 键分道防 Stack
   key 冲突（早轮 suppress 逻辑随 `_outId` 一并退役）。
3. **稳态恒 5 张**：pool≥5 五主道恒满（撕裂位由 entry 走廊占位防双重渲染）；pool<5 同卡共道去重
   （防 Stack key 冲突，理论边缘=池不足不见）。过渡期帧面=5 主道+走廊 ≤7（全轮转无一缺位）。
4. **`_SlotP` 全字段 `==` 补刀（恒抖产因）**：早轮 `_SlotP` 无 `==`，TweenAnimationBuilder 每次
   父 setState（500ms 直读 tick 定拍）判「端值变更」→ 550ms 补间从当前值重启=卡片恒微抖——
   「动画有点差」辅因。补全 `==`/`hashCode`（五标量全等）后同端值重建不重启动。
5. **已知边缘（如实记档）**：①630ms 窗内快连切=走廊被后序撕裂覆盖重排，首撕裂位改主道直挂
   （瞬移落位，动画截断可感但无缺位/无崩）；②池重采样换轮=车道映射重置，同池曲目的车道重排
   为一次性元素迁移飞行（每整轮 ~10s 一次，非每曲）；③exit 起=旧车道**静态**几何，若撕裂前
   主道仍在动画期（快连切）则首帧有视觉截断并入 ① 同口径。
6. **入档要件（全链复绿）**：analyze 0 issues；宿主 2 锚（新 5 卡形态锚+手势红线锚）全绿；
   宿主域串行回归 78/78（ui/playback/playlists/data/scan/widget_test）；E2E 同链 16s All tests
   passed（§3.5 增录）。**键位/手势语义/手感参数（40px 阈值/260px 上限/0.045deg/px/320ms/
   550ms 曲线）零改动**。

## §8.2 手势域收窄=卡组层（2026-10-20 复验三轮收口；开发者澄清裁决触发）

**触发（开发者复验原话）**：「上滑只能滑动卡片，不是整个页面都动」——早轮「任意方向拖拽整盘跟手」
细节被覆盖：拖拽帧整页（含信息区/控件/提示）一起位移+绕转=信息区文字跟手晃动的手感污染。
产品语义归 D6-7 细节覆盖（拖拽动面=卡组，其余定层）：

1. **实现**：`_deck` 结构重排——外层 GestureDetector（整盘捕获**不随拖拽位移**=热区稳定；SizedBox
   378×818 持 `shuffle_deck` 键不变）→ 内层 `Positioned.fill` + `ValueListenableBuilder` 只包
   卡组 Stack（恒满五卡+torn 走廊），`_deckMatrix(dragY)` 只应用于卡组层；信息区/控件/提示移入
   外层 Stack 定层子项。**零 setState 驱动面不变**（仅 Transform 层随 notifier 重建）。
2. **手感口径零改动**：clamp(-260..0)+绕轴心 0.045deg/px+320ms 回弹+40px 阈值全部保持（应用域收
   窄，未动参数）；手势判定（仅上滑切歌）零改动。
3. **入档要件（全链复绿）**：analyze 0 issues；宿主 2 锚全绿（手势锚中的下滑 drag warn=起始点落
   空区=语义本就不动作，绿属正确）；宿主域串行回归 78/78；E2E 同链 22s All tests passed。

## §8.3 轮转轨迹=绕转盘轴心弧线（2026-10-20 复验四轮收口；开发者澄清裁决触发）

**触发（开发者复验原话）**：「卡片的滚动应该是沿着圆心转动，而不是所有的卡片都进行上移后，
在进行切换」——三轮手势域收窄后拖拽只动卡组，但**轮转轨迹本身仍是逐项直线插值**
（tx/ty 直插=卡片平移飞向新车道，观感=整列上移+切换瞬换的错觉）。D6-7 终稿旋转渐进语义的
轨迹形态被开发者拍板=**绕轴心弧线**：

1. **实现**：`_SlotTween.lerp` 改极坐标轨迹插值——起/终车道中心（`tx+120, ty+h/2`）对转盘轴心
   （`kPivotX/kPivotY=(-143.8,464)`，与拖拽绕转轴心共用常量）求向量→极角差归一到 (-π,π]→
   每帧 `pivot + 极坐标(极角 lerp, 半径 lerp)` 现算中心→反解 tx/ty。轨迹=以轴心为圆心、半径随
   车道差同步收敛的**连续圆弧**（先转后到位的「轮盘被拨动」观感）；卡自转角/高度/透明度仍
   标量 lerp（端值=车道实测）。直线 `lerpTo` 退役。
2. **不变面**：550ms cubic-bezier(.32,.72,.28,1)/端值/手感参数全保持；`_SlotP ==` 全字段等
   （§8.1-4 零抖产因防线：begin==end 时极角差=0，稳态零输出）；torn 走廊卡（p2→out / in→nxt2）
   天然走同款弧线（出/入场走廊本就异半径极位）。
3. **入档要件（全链复绿）**：analyze 0 issues；宿主 2 锚全绿；宿主域串行回归 78/78
   （s3_ui_anchor 批跑 did-not-complete 两用例=引擎争用抖动史，单文件 3/3 秒绿实证非回归）；
   E2E 同链 21s All tests passed；模拟器目视核=轮转中间帧弧线轨迹/落定帧车道端值不变。
   **键位/手势语义/手感参数（40px/260px/0.045deg/px/320ms/550ms 曲线）零改动**。
