# VIBECODING EXECUTION SPEC — 首次引导与设置
# Source PRD: _02_feature_spec/_01_human_prd/features/onboarding_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-ONB-01"
  feature_name: "首次引导与设置"
  density: "airy"
  primary_anchor_cta: "使用『音乐』文件夹（步骤1）/ 跳过，直接开始（步骤2）"

design_tokens:
  usage_notes: "引导页: 居中大标题 26px w700 单焦点; 每步仅 1 主 CTA + 1 次 CTA; 步骤指示 2 圆点"

component_tree:
  - component: "OnboardingFlow"
    children:
      - component: "Step1Repo"
        elements: [{ type: "Headline", text: "你的音乐放在哪？" }, { type: "SuggestDirCard", text: "使用『音乐』文件夹" }, { type: "SecondaryAction", text: "选择其他文件夹" }, { type: "ScanResult", visible_when: "扫描中/完成", text: "已发现 N 首" }]
      - component: "Step2FirstTrack"
        elements: [{ type: "Headline", text: "试试提取你的第一首歌" }, { type: "LinkInput" }, { type: "SkipAction", text: "跳过，直接开始" }]
      - component: "DoneScreen"
        elements: [{ type: "Headline", text: "开始聆听" }, { type: "PrimaryCTA" }]
      - component: "ComplianceSheet"
        elements: [{ type: "Statement" }, { type: "ConfirmBtn", text: "我已知晓" }]
      - component: "SettingsScreen"
        groups: ["音乐仓库", "播放", "音效", "歌词", "同步", "外观 (主题/语言, DEC-005)", "关于"]
        row_types: { nav_row: "左图标+标题+chevron", value_row: "标题+当前值+chevron", toggle_row: "标题+开关" }

state_machine:
  onboarding:
    initial: "STEP1"
    states:
      STEP1: { on: { USE_SUGGESTED: "SCANNING", PICK_OTHER: "PICKER", SKIP_ALL: "DONE_EMPTY" } }
      PICKER: { on: { DIR_CHOSEN: "SCANNING", CANCEL: "STEP1" } }
      SCANNING: { on: { DONE: "STEP1_SCANNED", DIR_UNREADABLE: "STEP1 + error" } }
      STEP1_SCANNED: { on: { NEXT: "STEP2" } }
      STEP2: { on: { USE_LINK: "COMPLIANCE_CHECK", SKIP: "DONE" } }
      COMPLIANCE_CHECK: { on: { ACKNOWLEDGED: "EXTRACT_FLOW", CANCEL: "STEP2" } }
      DONE: { entry: "goto_discover_with_shuffle_highlight" }
      DONE_EMPTY: { entry: "goto_discover_empty_state" }
  settings_model:
    states:
      NOT_DOWNLOADED: { on: { DOWNLOAD: "DOWNLOADING" } }
      DOWNLOADING: { on: { DONE: "READY", FAIL: "NOT_DOWNLOADED + retry" } }
      READY: { on: { DELETE: "NOT_DOWNLOADED (confirm first)" } }

field_constraints:
  - field: "repo_dir"
    required_for: "STEP1_ACCEPT"
    rules: ["存在且可读", "重复选择已存在目录 → 提示『已在仓库列表中』"]
  - field: "fast_start_skip"
    rule: "任意步骤均可跳过；跳过后主界面空态必须含导入引导"
  - field: "compliance_ack"
    persist: "本机记录一次即可；关于页可回看"
  - field: "appearance"
    rule: "界面主题(深色/浅色/跟随系统)与界面语言(中文/English/跟随系统)三选；即时生效、本地持久化；应用名与歌曲自身信息不译；歌词生成语言=界面语言（DEC-005）"

executable_tests_gherkin:
  - id: "TEST-ONB-01-FTUE"
    given: "全新安装且系统『音乐』文件夹有 120 首"
    when: "首启动 → 点击『使用『音乐』文件夹』→ 完成扫描 → 跳过第 2 步"
    then: "≤3 屏进入音乐空间页；随机卡可用；曲库计数=120"
  - id: "TEST-ONB-02-SKIP-SAFE"
    given: "全新安装"
    when: "首启动直接全部跳过"
    then: "进入音乐空间页空态且含『选择音乐文件夹』与『提取链接』引导（无死胡同）"
  - id: "TEST-ONB-03-MODEL-MGMT"
    given: "设置 → 歌词模型未下载"
    when: "下载完成后再删除"
    then: "状态回到需下载；生成歌词入口同步变回门禁态"
  - id: "TEST-ONB-04-THEME"
    given: "用户处于深色主题"
    when: "设置 → 外观切换为浅色，随后重启"
    then: "全应用即时切换且无残留深色硬编码块；重启后保持浅色；胶片帧仍为深色实体"
  - id: "TEST-ONB-05-LANG"
    given: "界面语言为中文且队列中有《夜航》"
    when: "设置 → 外观切换为 English"
    then: "界面标签切换为英文；应用名与曲名《夜航》保持原样；歌词生成任务按英文界面语言约定执行"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 引导超过 2 个必选步骤或 3 屏"
  - "STRICTLY FORBIDDEN: 跳过 FTUE 后出现无引导的空死界面"
  - "STRICTLY FORBIDDEN: 未确认合规声明进入提取流程"
  - "STRICTLY FORBIDDEN: 删除模型不二次确认"
