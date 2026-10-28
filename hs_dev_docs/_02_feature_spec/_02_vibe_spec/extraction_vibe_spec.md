# VIBECODING EXECUTION SPEC — 分享链接音频提取入库
# Source PRD: _02_feature_spec/_01_human_prd/features/extraction_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-EXT-01"
  feature_name: "分享链接音频提取入库"
  density: "balanced"
  primary_anchor_cta: "开始提取"

design_tokens:
  usage_notes: "解析结果卡: 封面 64px + 标题 + UP主 + 时长; 任务行进度条 2px accent; 速度/进度 tabular-nums"

component_tree:
  - component: "ExtractScreen"
    children:
      - component: "LinkInput"
        props: { multiline: true, extract_url_from_text: true, paste_button: true }
        placeholder: "粘贴 B 站分享链接"
      - component: "ParseResultCard"
        visible_when: "解析成功"
        elements: [{ type: "CoverThumb" }, { type: "TitleCreatorDuration" }, { type: "QualitySelector", options: ["最高可用", ...] }, { type: "SaveLocationNote", text: "将保存到 音乐仓库/提取/" }, { type: "PrimaryCTA", text: "开始提取" }]
      - component: "LoginBanner"
        visible_when: "检测到未登录且解析受限"
        elements: [{ type: "Message", text: "登录后可提取更高音质" }, { type: "Btn", text: "登录 B 站（扫码）" }]
      - component: "TaskQueue"
        row: { elements: [{ type: "TrackTitle" }, { type: "ProgressBar" }, { type: "SpeedETA", mono: true }, { type: "CancelBtn" }] }
        groups: ["进行中", "已完成", "失败"]
      - component: "ComplianceSheet"
        visible_when: "首次使用"
        elements: [{ type: "Statement" }, { type: "ConfirmBtn", text: "我已知晓，仅用于个人合法内容的备份" }]

state_machine:
  parse:
    initial: "IDLE"
    states:
      IDLE: { on: { PASTE_TEXT: "PARSING (debounce 300ms on url detected)" } }
      PARSING: { on: { OK: "PARSED", INVALID_URL: "IDLE + inline_hint", NEED_LOGIN: "PARSED_LIMITED", FAIL: "PARSE_ERROR" } }
      PARSED: { on: { START: "TASK_QUEUED" } }
      PARSED_LIMITED: { on: { LOGIN: "OAUTH_WEBVIEW", START: "TASK_QUEUED" } }
      PARSE_ERROR: { actions: ["保留输入", "重试"] }
  download_task:
    initial: "QUEUED"
    states:
      QUEUED: { on: { START: "DOWNLOADING", CANCEL: "CANCELLED" } }
      DOWNLOADING: { on: { DONE: "POST_PROCESS", CANCEL: "CANCELLED", NETWORK_LOST: "PAUSED", DISK_FULL: "SUSPENDED_DISK", QUALITY_DOWNGRADE: "DOWNLOADING + badge" } }
      PAUSED: { on: { NETWORK_BACK: "DOWNLOADING (resume)" } }
      SUSPENDED_DISK: { on: { SPACE_OK: "DOWNLOADING (resume)" } }
      POST_PROCESS: { entry: "rename+metadata+cover", on: { DONE: "COMPLETED + toast(已加入曲库)", DUP_FOUND: "ASK_DUPLICATE" } }
      ASK_DUPLICATE: { on: { SKIP: "COMPLETED", RE_EXTRACT: "QUEUED" } }
      COMPLETED: { terminal: true }
      FAILED: { on: { RETRY: "QUEUED" } }

field_constraints:
  - field: "link_input"
    type: "text"
    required: true
    rule: "从分享文本中提取首个 URL；支持多 P/合集多选"
    error_message: "没有识别到有效链接，请粘贴 B 站分享内容或视频链接"
  - field: "save_dir"
    type: "path"
    default: "仓库/提取/"
    editable_in: "设置"
  - field: "filename_rule"
    default: "歌手 - 歌名.ext"
    sanitize: "去除「」【】与合集前缀与非法字符"

executable_tests_gherkin:
  - id: "TEST-EXT-01-HAPPY"
    given: "已配置仓库并确认合规声明"
    when: "粘贴 B 站分享文本并点击『开始提取』"
    then: "≤5s 展示解析卡；下载完成后提示『《X》已加入曲库』且带封面元数据"
  - id: "TEST-EXT-02-ERROR-KEEP-INPUT"
    given: "粘贴了失效链接"
    when: "解析"
    then: "原位人话错误；输入内容 100% 保留"
  - id: "TEST-EXT-03-LOGIN-QUALITY"
    given: "未登录时仅有普通码率"
    when: "扫码登录后重新解析"
    then: "出现高码率选项并默认选中"
  - id: "TEST-EXT-04-COMPLIANCE-GATE"
    given: "首次进入提取页"
    when: "未确认合规声明即点击开始提取"
    then: "阻断并弹出声明；确认后才可下载"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 未确认合规声明前发起任何下载"
  - "STRICTLY FORBIDDEN: 解析失败/网络错误时清空用户粘贴的链接"
  - "STRICTLY FORBIDDEN: 实现任何绕过 DRM/付费墙/会员权限的能力"
  - "STRICTLY FORBIDDEN: 断网后任务静默失败（必须暂停并明示，恢复后继续）"
