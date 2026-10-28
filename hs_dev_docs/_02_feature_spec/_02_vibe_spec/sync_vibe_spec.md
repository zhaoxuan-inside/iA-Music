# VIBECODING EXECUTION SPEC — 多端同步
# Source PRD: _02_feature_spec/_01_human_prd/features/sync_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-SYNC-01"
  feature_name: "多端同步"
  density: "balanced"
  primary_anchor_cta: "立即同步 / 连接测试"

design_tokens:
  usage_notes: "同步中心: 上次同步时间(相对时间+tabular-nums); 计数徽标; 失败列表红色 12px; 通道卡 = 图标+名称+状态点"

component_tree:
  - component: "SyncCenterScreen"
    children:
      - component: "ChannelCardList"
        visible_when: "未配置通道"
        cards: [{ id: "webdav", label: "WebDAV", note: "最稳定，推荐" }, { id: "onedrive", label: "OneDrive" }, { id: "gdrive", label: "Google Drive" }, { id: "github", label: "GitHub", note: "仅同步歌单/歌词/元数据，不存音频" }]  # DEC-008: 百度网盘移除（2026-10-17）
      - component: "ChannelForm"
        fields_by_channel: { webdav: ["服务器地址", "账号", "密码"], oauth: ["授权登录按钮"], github: ["仓库地址", "访问 Token"] }
        actions: [{ type: "TestConnectionBtn", text: "连接测试" }]
      - component: "SyncStatusPanel"
        elements: [{ type: "LastSyncTime" }, { type: "PendingCounters", mono: true }, { type: "CurrentTask", elements: ["文件名", "进度", "速度"] }, { type: "ManualSyncBtn", text: "立即同步" }]
      - component: "FailureList"
        row: { elements: ["文件名", "原因", "重试按钮"] }
      - component: "ConflictCopiesEntry"
        text: "冲突副本（N）"
      - component: "TombstoneNote"
        text: "删除同步仅传播记录，云端音频文件不会被自动删除"

state_machine:
  sync_engine:
    initial: "IDLE"
    states:
      IDLE: { on: { LOCAL_CHANGE: "DEBOUNCE", MANUAL_SYNC: "PREPARE" } }
      DEBOUNCE: { entry: "wait_30s", on: { TIMEOUT: "PREPARE", NEW_CHANGE: "DEBOUNCE" } }
      PREPARE: { entry: "scan_diff", on: { DIFF_EMPTY: "IDLE + toast(已是最新)", DIFF_FOUND: "TRANSFERRING" } }
      TRANSFERRING: { on: { DONE: "IDLE + summary", NETWORK_LOST: "PAUSED", AUTH_EXPIRED: "NEEDS_REAUTH", DISK_FULL: "SUSPENDED_DISK" } }
      PAUSED: { entry: "show_reason", on: { NETWORK_BACK: "TRANSFERRING (resume)" } }
      NEEDS_REAUTH: { on: { REAUTH: "TRANSFERRING" } }
      SUSPENDED_DISK: { on: { SPACE_OK: "TRANSFERRING (resume)" } }
  conflict:
    rule: "记录级 last-writer-wins by updated_at; 败者写为冲突副本(可查看/删除)"
    playlist_merge: "集合并集; 删除按墓碑时间戳比较"

field_constraints:
  - field: "webdav_password / tokens"
    storage: "本机加密安全存储；不上传任何第三方服务器"
  - field: "remote_dir"
    default: "iA-Music/"
  - field: "sync_light / sync_audio"
    type: "boolean"
    default: [true, true]
    rule: "github 通道 sync_audio 强制 false 且 UI 禁用"

executable_tests_gherkin:
  - id: "TEST-SYNC-01-CROSS-DEVICE"
    given: "手机与电脑均配置同一 WebDAV"
    when: "手机提取一首新歌并红心，等待自动同步"
    then: "≤30s 轻数据+音频上传；电脑同步后记录/红心/可播放文件齐全"
  - id: "TEST-SYNC-02-TOMBSTONE"
    given: "两设备曲库一致"
    when: "设备A移除《晚风》并同步"
    then: "设备B曲库移除该记录；云盘音频文件仍存在"
  - id: "TEST-SYNC-03-RESUME"
    given: "同步中网络中断"
    when: "网络恢复"
    then: "任务自动续传完成；本地数据无损"
  - id: "TEST-SYNC-04-GITHUB-GUARD"
    given: "配置 GitHub 通道"
    when: "查看设置"
    then: "音频同步开关不可用并明示『GitHub 仅同步轻数据』"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 同步删除时物理删除云端音频文件"
  - "STRICTLY FORBIDDEN: 冲突时静默丢弃任一侧修改（必须保留冲突副本）"
  - "STRICTLY FORBIDDEN: 同步失败影响本地数据可用性"
  - "STRICTLY FORBIDDEN: 凭据明文落盘或上传"
  - "STRICTLY FORBIDDEN: 在 GitHub 通道上传音频文件"
