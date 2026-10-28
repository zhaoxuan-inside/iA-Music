# VIBECODING EXECUTION SPEC — 歌词显示与编辑
# Source PRD: _02_feature_spec/_01_human_prd/features/lyrics_display_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-LYR-01"
  feature_name: "歌词显示与编辑"
  density: "airy"
  primary_anchor_cta: "生成歌词（无歌词时）/ 保存歌词"

design_tokens:
  usage_notes: |
    歌词页背景: 播放页同一封面模糊底（同层延展，不重新加载）
    歌词正文 17px w500 行高 1.8；当前行 accent 亮色 + w650；非当前行 45% 白；翻译行 14px 65% 白
    滚动: 当前行垂直居中 (scroll-behavior smooth)；点击行 = 跳转

component_tree:
  - component: "LyricsView"
    layout: "播放页内视图切换 (唱片 ⇄ 歌词) 或全屏层"
    children:
      - component: "LyricsScroller"
        elements: [{ type: "LyricLine", states: { active: "accent w650 居中", normal: "45% white" } }, { type: "TranslationLine" }]
        interactions: ["tap_line => seek_to_line_timestamp", "long_press => open_offset_control"]
      - component: "OffsetControl"
        elements: [{ type: "MinusBtn" }, { type: "OffsetValue", mono: true, unit: "s" }, { type: "PlusBtn" }, { type: "SaveBtn" }]
        props: { step: 0.5, min: -10, max: 10 }
      - component: "NoLyricsState"
        elements: [{ type: "Message", text: "这首歌还没有歌词" }, { type: "PrimaryCTA", text: "生成歌词（本地 AI）" }, { type: "SecondaryCTA", text: "手动粘贴歌词" }]

state_machine:
  lyrics_source:
    initial: "RESOLVE"
    states:
      RESOLVE: { on: { FOUND_LRC: "DISPLAY_TIMED", FOUND_EMBEDDED: "DISPLAY_TIMED", FOUND_PLAIN: "DISPLAY_STATIC", NONE: "EMPTY_GUIDE", CORRUPT: "DISPLAY_STATIC + notice" } }
      DISPLAY_TIMED: { on: { TAP_LINE: "DISPLAY_TIMED (seek)", OFFSET_EDIT: "OFFSET_DIRTY" } }
      OFFSET_DIRTY: { on: { SAVE: "DISPLAY_TIMED (persist_lrc)", LIVE_PREVIEW: "OFFSET_DIRTY" } }
      DISPLAY_STATIC: { on: { CONVERT_CTA: "EMPTY_GUIDE" } }
      EMPTY_GUIDE: { on: { AI_GENERATE: "FEAT-LYR-02 flow", PASTE_MANUAL: "MANUAL_INPUT" } }
      MANUAL_INPUT: { on: { CONFIRM: "DISPLAY_TIMED or DISPLAY_STATIC", CANCEL: "EMPTY_GUIDE" } }

field_constraints:
  - field: "offset_seconds"
    type: "number"
    range: [-10, 10]
    step: 0.5
    default: 0
    persist: "导出/更新同目录 .lrc，不写回音频文件"
    message: "歌词偏移 +0.5 秒"
  - field: "manual_lyrics"
    type: "text"
    accepts: ["纯文本", "LRC"]
    rule: "纯文本按无时间轴展示"

executable_tests_gherkin:
  - id: "TEST-LYR-01-DISPLAY"
    given: "《晚风》同目录有 .lrc"
    when: "进入歌词视图"
    then: "逐行显示，当前行高亮居中"
  - id: "TEST-LYR-02-TAP-SEEK"
    given: "歌词视图展示中"
    when: "点击第 10 行"
    then: "进度跳到第 10 行时间戳"
  - id: "TEST-LYR-03-OFFSET-SAVE"
    given: "歌词整体慢 1 秒"
    when: "偏移调至 -1.0s 并保存"
    then: "实时对齐；生成更新后的 .lrc；音频本体未被修改"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 修改/覆盖用户音频文件本体来写歌词"
  - "STRICTLY FORBIDDEN: 歌词文件损坏时白屏（必须降级为纯文本展示 + 提示）"
  - "STRICTLY FORBIDDEN: 无歌词时死胡同（必须给生成/粘贴两个出路）"
