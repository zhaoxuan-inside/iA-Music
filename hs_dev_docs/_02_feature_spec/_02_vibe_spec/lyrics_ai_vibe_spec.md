# VIBECODING EXECUTION SPEC — 模型歌词提取
# Source PRD: _02_feature_spec/_01_human_prd/features/lyrics_ai_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-LYR-02"
  feature_name: "模型歌词提取"
  density: "balanced"
  primary_anchor_cta: "生成歌词 / 批量生成歌词"

design_tokens:
  usage_notes: "任务行: 曲名 + 状态徽标(等待/进行中百分比/完成/失败) + 行尾操作；进度百分比与耗时 tabular-nums"

component_tree:
  - component: "LyricsAiTaskScreen"
    children:
      - component: "ModelGate"
        visible_when: "模型未下载"
        elements: [{ type: "Message", text: "音乐识别模型（约 XXX MB，仅需下载一次）" }, { type: "PrimaryCTA", text: "下载模型" }, { type: "ProgressBar" }]
      - component: "TaskQueueList"
        groups: ["进行中", "等待中", "已完成", "失败"]
        row: { elements: [{ type: "TrackTitle" }, { type: "StatusBadge" }, { type: "RowActions", options: ["取消", "重试", "预览"] }] }
      - component: "PreviewSheet"
        elements: [{ type: "EditableLyricsText" }, { type: "SaveBtn", text: "保存歌词" }, { type: "RegenerateBtn" }]
      - component: "BatchSelectBar"
        elements: [{ type: "SelectedCount", mono: true }, { type: "BatchGenerateBtn", text: "批量生成歌词" }]

state_machine:
  generation_task:
    initial: "QUEUED"
    states:
      QUEUED: { on: { START: "RUNNING", CANCEL: "CANCELLED" } }
      RUNNING: { entry: "progress_percent_tick", on: { DONE: "PREVIEW", NO_VOCAL: "DONE_NO_FILE", FAILED: "FAILED", CANCEL: "CANCELLED" } }
      PREVIEW: { on: { EDIT: "PREVIEW", SAVE: "SAVED", DISCARD: "CANCELLED" } }
      SAVED: { terminal: true }
      DONE_NO_FILE: { entry: "toast(未检测到人声，未生成歌词文件)" }
      FAILED: { on: { RETRY: "QUEUED" } }
      CANCELLED: { terminal: true, cleanup: "no_partial_file" }
  queue:
    concurrency: 1
    entry: "serial_dispatch"
    pause_resume: true

field_constraints:
  - field: "model_size"
    display: "设置页与门禁页均展示体积与占用"
  - field: "existing_lyrics_overwrite"
    rule: "已有 .lrc 时触发生成 → 确认弹层"
    confirm_text: "已有歌词，生成将覆盖现有 .lrc（音频文件不受影响），继续？"
  - field: "mobile_foreground_notice"
    rule: "移动端非前台时暂停推理并提示"
    message: "保持应用在前台可以获得更快速度"

executable_tests_gherkin:
  - id: "TEST-LYRAI-01-FIRST-RUN"
    given: "模型未下载"
    when: "首次点击『生成歌词』"
    then: "先进入模型下载门禁；完成后自动开始生成并显示百分比"
  - id: "TEST-LYRAI-02-NO-VOCAL"
    given: "纯器乐曲目"
    when: "生成完成"
    then: "提示『未检测到人声，未生成歌词文件』且无 .lrc 产生"
  - id: "TEST-LYRAI-03-OFFLINE"
    given: "模型已下载，设备断网"
    when: "触发生成"
    then: "流程正常完成（无网络请求）"
  - id: "TEST-LYRAI-04-CANCEL"
    given: "任务进行中"
    when: "取消任务"
    then: "任务终止且不产生半成品 .lrc"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 上传用户音频到任何服务器（纯本地推理）"
  - "STRICTLY FORBIDDEN: 生成完成后不经预览直接覆盖用户现有歌词"
  - "STRICTLY FORBIDDEN: 并发多任务推理占满设备（并发=1）"
  - "STRICTLY FORBIDDEN: 超性能目标时不做标注（进度必须真实）"
