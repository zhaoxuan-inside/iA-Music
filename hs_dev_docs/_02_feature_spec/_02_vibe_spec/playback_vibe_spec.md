# VIBECODING EXECUTION SPEC — 沉浸式播放与播放增强
# Source PRD: _02_feature_spec/_01_human_prd/features/playback_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-PLAY-01"
  feature_name: "沉浸式播放与播放增强"
  density: "airy"
  primary_anchor_cta: "播放/暂停 (64px 最大触控)"

design_tokens:
  usage_notes: |
    播放页背景: 封面 blur≥60px 放大铺满 + 渐变遮罩 (rgba(0,0,0,.35) 顶部 → rgba(0,0,0,.65) 底部)
    大封面 16px 圆角，宽=屏宽-64px (移动) / 360px (桌面)
    三键图标 24-28px；播放键 64px 热区；进度条 3px 轨道 + 12px 圆形拖柄，时间 tabular-nums

component_tree:
  - component: "ImmersivePlayerScreen"
    layout: "全屏覆盖层 (移动: 纵向 顶栏/封面/信息/进度/三键; 桌面: 覆盖式浮层)"
    children:
      - component: "TopBar"
        elements: [{ type: "CollapseChevron", action: "back" }, { type: "Title", text: "正在播放" }, { type: "MoreMenu" }]
      - component: "CoverArt", props: { radius: "16px" }
      - component: "TrackMeta"
        elements: [{ type: "SongTitle", style: "22px w650, 2行截断" }, { type: "ArtistAvatarName" }, { type: "AlbumName" }, { type: "HeartButton" }]
      - component: "ProgressBar"
        elements: [{ type: "ElapsedTime" }, { type: "Track" }, { type: "TotalTime" }]
      - component: "TriControls"
        elements: [{ type: "DislikeBtn", icon: "trash" }, { type: "PlayPauseBtn", size: "64px" }, { type: "NextBtn" }]
      - component: "MoreSheet"
        options: ["查看歌词", "音效", "倍速", "加入歌单", "歌曲信息", "查看队列"]
      - component: "QueueSheet"
        elements: [{ type: "QueueList" }, { type: "ClearQueue" }]
      - component: "MiniPlayerBar"
        layout: "底部 pill: 封面36px + 歌名-歌手(跑马灯) + 播放 + 队列 (无会话时隐藏)"
  - component: "EqualizerScreen"
    elements: [{ type: "PresetChips", options: ["默认", "流行", "摇滚", "古典", "爵士", "低音增强", "自定义"] }, { type: "FiveBandSliders", range: "-12dB ~ +12dB" }, { type: "UnsupportedNotice" }]

state_machine:
  playback:
    initial: "STOPPED"
    states:
      STOPPED: { on: { PLAY: "PLAYING" } }
      PLAYING: { on: { PAUSE: "PAUSED", TRACK_END: "PLAYING (next)", NEXT: "PLAYING (next)", PREV: "PLAYING (prev_or_restart)", SEEK: "PLAYING", FILE_MISSING: "PLAYING (skip + toast)", DECODE_ERROR: "PLAYING (skip + toast)" } }
      PAUSED: { on: { PLAY: "PLAYING", NEXT: "PLAYING (next)", STOP_CLEAR: "STOPPED" } }
  repeat_mode:
    values: ["ORDER", "LIST_LOOP", "SINGLE_LOOP", "SHUFFLE"]
    default: "LIST_LOOP"
    rule: "SHUFFLE 一轮内不重复; 排除少播名单"
  dislike:
    initial: "NORMAL"
    states:
      NORMAL: { on: { DISLIKE: "DISLIKED_SKIP" } }
      DISLIKED_SKIP: { entry: "add_to_less_list, play_next, toast(已减少这首的推荐)" }

field_constraints:
  - field: "speed_options"
    type: "enum"
    values: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    default: 1.0
  - field: "eq_bands"
    type: "array"
    bands: ["60Hz", "230Hz", "910Hz", "3.6kHz", "14kHz"]
    range: [-12, 12]
    unit: "dB"
    default: 0

executable_tests_gherkin:
  - id: "TEST-PLAY-01-ENTER"
    given: "曲库中《夜航》文件存在"
    when: "点击《夜航》"
    then: "≤300ms 出声并进入沉浸页；背景为封面模糊色；标题/歌手正确"
  - id: "TEST-PLAY-02-DISLIKE"
    given: "随机模式播放中"
    when: "点击垃圾桶"
    then: "立即下一首且《夜航》入少播名单；清空名单后可再随机到"
  - id: "TEST-PLAY-03-MISSING-SKIP"
    given: "队列下首文件缺失"
    when: "播放进行到该曲"
    then: "自动跳下一首 + 顶部提示『《旧信》文件缺失，已跳过』"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 垃圾桶=物理删除用户曲目/收藏"
  - "STRICTLY FORBIDDEN: 切歌时 UI 与音频状态不一致（先切 UI 后无声/有声无 UI）"
  - "STRICTLY FORBIDDEN: 进度时间跳字（必须 tabular-nums）"
  - "STRICTLY FORBIDDEN: 设备不支持音效时静默失败（必须明示『当前设备不支持音效调节』）"
