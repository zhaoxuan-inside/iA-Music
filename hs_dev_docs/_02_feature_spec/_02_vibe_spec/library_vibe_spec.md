# VIBECODING EXECUTION SPEC — 音乐仓库与曲库管理
# Source PRD: _02_feature_spec/_01_human_prd/features/library_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-LIB-01"
  feature_name: "音乐仓库与曲库管理"
  density: "balanced"
  primary_anchor_cta: "扫描音乐目录 / 重新扫描"

design_tokens:
  css_variables:
    --color-accent: "#4BE0A3"
    --color-canvas: "#0A0B0D"
    --color-surface: "#16181C"
    --color-surface-2: "#1F2228"
    --color-text-primary: "#F5F6F7"
    --color-text-secondary: "#9BA1A8"
    --color-error: "#FF6B6B"
    --radius-card: "12px"
    --radius-cover: "16px"
  usage_notes: "列表行透明底+hover rgba(255,255,255,0.04)；封面 48px 缩略圆角 8px；缺失态整行 40% 不透明度"

component_tree:
  - component: "LibraryScreen"
    layout: "纵向流: 排序/筛选 sticky + 曲目列表"
    children:
      - component: "SortFilterChips"
        options: ["全部", "歌手", "专辑", "最近入库", "时长"]
        style: "chip 999px; 激活=accent 20% 底 + accent 字色"
      - component: "TrackRow"
        elements: [{ type: "CoverThumb", size: "48px" }, { type: "TitleArtist", lines: 1 }, { type: "QualityCaption" }, { type: "HeartIcon" }, { type: "MoreMenu" }]
        states:
          missing_file: { opacity: 0.4, badge: "文件缺失", action: "定位文件" }
      - component: "ScanProgressBar"
        visible_when: "扫描进行中"
        elements: [{ type: "ProgressBar" }, { type: "Counter", props: { text: "已发现 N 首", mono: true } }]
    states:
      empty: { title: "还没有音乐", cta1: "选择音乐文件夹 ★", cta2: "粘贴一条 B 站链接试试", action_open: "file_picker / extract_screen" }
      loading: { type: "real_progress" }
      error: { message: "音乐仓库『X』无法访问，请重新连接或移除该仓库", actions: ["重新连接", "移除仓库"], preserve: "其余曲库可用" }

state_machine:
  scan:
    initial: "IDLE"
    states:
      IDLE: { on: { SCAN_TRIGGER: "SCANNING" } }
      SCANNING: { entry: "show_progress_counter", on: { DONE: "IDLE", CANCEL: "IDLE", DIR_UNREADABLE: "ERROR" } }
      ERROR: { on: { RETRY: "SCANNING", REMOVE_REPO: "IDLE" } }
  cover_resolver:
    initial: "RESOLVE"
    states:
      RESOLVE: { on: { EMBEDDED: "FOUND", SIBLING_FILE: "FOUND", NO_SOURCE: "FETCH_CHECK" } }
      FETCH_CHECK: { on: { TOGGLE_OFF: "FALLBACK_LETTER", TOGGLE_ON: "SEARCHING" } }
      SEARCHING: { entry: "query_public_cover_source(artist+album/title)", on: { MATCH: "SAVE_LOCAL", NO_MATCH: "FALLBACK_LETTER", OFFLINE: "FALLBACK_LETTER + retry_later" } }
      SAVE_LOCAL: { entry: "write <filename>.cover.jpg beside audio (never overwrite)", on: { OK: "FOUND", WRITE_FAIL: "FALLBACK_LETTER" } }
      FOUND: { display: "cover_art" }
      FALLBACK_LETTER: { display: "letter_block(title_hash_color)", retry_on: ["next_scan", "next_play"] }

field_constraints:
  - field: "repository_path"
    layer: "primary_screen"
    type: "path"
    required: true
    rules: ["必须存在且可读", "不可重复", "不可嵌套子目录"]
    error_message: "无法访问该文件夹（权限或设备未连接），请重新选择"
  - field: "track_title_edit"
    layer: "progressive_fold"
    type: "string"
    required: false
    constraints: "1-200 字符；空则回退文件名；仅改曲库记录不改文件"
    error_message: "标题需在 1-200 字符内"
  - field: "cover_fetch_toggle"
    layer: "settings"
    type: "boolean"
    default: true
    rules: ["仅补缺：有内嵌/同目录封面时不联网", "结果保存为同目录 <文件名>.cover.jpg", "不覆盖已有封面文件", "不修改音频本体", "离线/无结果静默降级首字母色块"]
    error_message: "—（抓取失败不产生用户可见错误，仅降级展示）"

executable_tests_gherkin:
  - id: "TEST-LIB-01-SCAN"
    given: "用户选择含 500 首音乐的目录"
    when: "确认添加仓库"
    then: "显示实时扫描计数；完成后曲库计数=500"
  - id: "TEST-LIB-02-MISSING"
    given: "曲目文件被外部移出仓库"
    when: "触发扫描"
    then: "曲目灰显『文件缺失』；放回并扫描后自动恢复可播放"
  - id: "TEST-LIB-03-UNLINK"
    given: "曲目在曲库中"
    when: "选择『从曲库移除』并确认"
    then: "曲目与歌单引用消失，仓库物理文件仍存在"
  - id: "TEST-LIB-04-COVER-FETCH"
    given: "曲目无内嵌封面与同目录封面，刮削开关开启，网络可用"
    when: "扫描完成并首次播放该曲目"
    then: "联网搜索到封面并生成同目录封面文件；播放页与列表展示该封面；音频本体未被修改"
  - id: "TEST-LIB-05-COVER-OFFLINE"
    given: "同上但设备离线"
    when: "扫描/播放"
    then: "不报错、不阻塞；展示首字母色块；联网后再扫描/播放时自动补抓"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 用『从曲库移除』删除用户物理音频文件"
  - "STRICTLY FORBIDDEN: 修改曲目元数据时写回/破坏原音频文件"
  - "STRICTLY FORBIDDEN: 在线封面抓取覆盖用户已有的内嵌封面或已有同目录封面文件"
  - "STRICTLY FORBIDDEN: 封面抓取的网络失败阻塞扫描、入库或播放（必须静默降级为首字母色块）"
  - "STRICTLY FORBIDDEN: 扫描进度使用假骨架（必须真实计数）"
