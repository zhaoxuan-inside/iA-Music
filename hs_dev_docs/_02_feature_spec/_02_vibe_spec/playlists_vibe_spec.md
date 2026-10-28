# VIBECODING EXECUTION SPEC — 歌单、红心与播放历史
# Source PRD: _02_feature_spec/_01_human_prd/features/playlists_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-PL-01"
  feature_name: "歌单、红心与播放历史"
  density: "balanced"
  primary_anchor_cta: "创建歌单 / 播放全部"

design_tokens:
  usage_notes: "红心收藏色 #FF5C7A 仅用于已红心；未红心=白描边心形；歌单封面=前 4 首 2x2 拼贴"

component_tree:
  - component: "MineScreen"
    children:
      - component: "StatCardsRow"
        cards: [{ label: "我喜欢的音乐", icon: "heart" }, { label: "播放历史", icon: "history" }, { label: "本地曲库", icon: "library" }]
      - component: "PlaylistSection"
        children: [{ component: "PlaylistCard", props: { cover: "2x2 拼贴", name: "w600 14px", count: "caption" } }, { component: "CreatePlaylistCard", action: "create" }]
  - component: "AddToPlaylistSheet"
    layout: "底部弹层 (radius-top 20px)"
    elements: [{ type: "PlaylistOptionList" }, { type: "NewPlaylistInlineInput", placeholder: "给歌单起个名字" }]
  - component: "HeartButton"
    states: { unliked: "outline white", liked: "filled #FF5C7A + 150ms scale pop" }

state_machine:
  heart_toggle:
    initial: "UNLIKED"
    states:
      UNLIKED: { on: { TAP: "LIKING" } }
      LIKING: { entry: "optimistic_update", on: { PERSIST_OK: "LIKED", PERSIST_FAIL: "UNLIKED_ROLLBACK + toast" } }
      LIKED: { on: { TAP: "UNLIKING" } }
      UNLIKING: { entry: "optimistic_update", on: { PERSIST_OK: "UNLIKED", PERSIST_FAIL: "LIKED_ROLLBACK + toast" } }
  add_to_playlist:
    initial: "SHEET_OPEN"
    states:
      SHEET_OPEN: { on: { SELECT_PLAYLIST: "ADDING", CREATE_NEW: "CREATE_INPUT" } }
      CREATE_INPUT: { on: { CONFIRM: "ADDING", CANCEL: "SHEET_OPEN" } }
      ADDING: { on: { SUCCESS_DUPLICATE: "SHEET_OPEN + inline_toast(已在歌单中)", SUCCESS_NEW: "SHEET_CLOSED + toast", FAIL: "SHEET_OPEN + error" } }

field_constraints:
  - field: "playlist_name"
    type: "string"
    required: true
    constraints: "1-40 字符；允许同名但提示"
    error_message: "歌单名称需在 1-40 字符内"
  - field: "playlist_dup_guard"
    type: "rule"
    rule: "同一曲目不可重复加入同一歌单"
    error_message: "《{title}》已在『{playlist}』中"

executable_tests_gherkin:
  - id: "TEST-PL-01-HEART"
    given: "用户播放《晚风》未红心"
    when: "点击红心"
    then: "红心即时填充红色；我的页红心计数+1"
  - id: "TEST-PL-02-DUP"
    given: "《晚风》已在歌单《深夜》"
    when: "再次加入《深夜》"
    then: "原位提示『已存在』，不产生重复条目"
  - id: "TEST-PL-03-HISTORY-CAP"
    given: "历史已有 500 条"
    when: "播放新曲目"
    then: "最旧记录淘汰；新记录在『今天』分组首位"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 取消红心时删除播放历史或曲目"
  - "STRICTLY FORBIDDEN: 同一歌单出现重复曲目"
  - "STRICTLY FORBIDDEN: 红心状态乐观更新失败后不回滚（必须回滚并提示）"
