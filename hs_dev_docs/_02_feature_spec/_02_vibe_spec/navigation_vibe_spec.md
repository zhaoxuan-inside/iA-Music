# VIBECODING EXECUTION SPEC — 三 Tab 探索（音乐空间/搜索/我的）+「随机」轮盘页
# Source PRD: _02_feature_spec/_01_human_prd/features/navigation_prd.md
# Macro Taste Charter: Inherits /DESIGN.md

meta:
  feature_id: "FEAT-NAV-01"
  feature_name: "三 Tab 探索 +「随机」轮盘页"
  density: "balanced (音乐空间页区块间距 24px)"
  primary_anchor_cta: "随机大卡（音乐空间页唯一一级锚点）"

design_tokens:
  usage_notes: |
    Tab 栏: 高度 56px + 安全区; 纯图标 23px 无文字; 激活=白色 #F0F2F4 / 非激活 #6E747C (DEC-006 对齐官网实拍)
    音乐空间页大标题 28px w700; 区块标题 15px w600 + chevron
    随机大卡: 全宽 20px 圆角, 绿渐变 (#37CE97→#2198B4→#1E6E9D), 封面块 + 随机波形 (逐条延迟动效) + 白色圆钮 52px
    歌单卡: 3 列网格 (移动)/ 6 列 (桌面), 封面 1:1 12px 圆角
    迷你播放条: 悬浮胶囊 52px (左右 10px 边距), 36px 旋转黑胶 + 歌名–歌手 + 播放/队列 (DEC-006)
    我的页统计卡: 3 张图像卡 (渐变底 + 底部遮罩 icon+标签+计数)
    「随机」轮盘页 (DEC-006 D6-7, 轮 16 终稿): 文字导航 + 唱片轮盘 5 槽位 (cur 方形 240px 焦点; p1/p2 与 nxt/nxt2 为 240×174 横条); 卡组沿左弧层叠、左沿出血; 层次仅靠旋转渐进 + z 序 (静态卡无模糊/缩放), 槽位旋转角为参考实测复刻值; 拖拽绕转盘轴心 transform-origin
    海报色板: 森林/奶黄/琥珀/彩虹/薄荷 (默认排布=参考图 10_classic_radio_wheel.png 配色); 海报色不随主题变
    轮盘控件行贴底出血: 🗑(灰) | ⏸(薄荷细条, 非白圆) | ♥(柔粉); 浅色专项色 #78DCBE/#7FD8C4/#76E0BC/#E08BA8 (不动全局 accent)
    轮盘信息区 (右下 128px): 「随机」▾/歌名/歌手/进度条/时刻, 随焦点卡同步

component_tree:
  - component: "AppShell"
    layout_mobile: "内容区 + MiniPlayerBar(悬浮胶囊) + BottomTabBar(音乐空间/搜索/我的, 纯图标)"
    layout_desktop: "LeftNav(240px: 主入口+歌单) + 内容区(max1200) + BottomPlayerBar(72px)"
    children:
      - component: "MusicSpaceScreen (route: discover)"
        children:
          - component: "ShuffleCard"
            elements: [{ type: "ArtTile" }, { type: "Title", text: "随机" }, { type: "Subtitle", text: "随机播放我的曲库" }, { type: "WaveBars" }, { type: "PlayDisc", size: "52px" }]
              action: "random_play_all"
          - component: "RecentlyAddedRow", props: { horizontal_scroll: true, max: 20 }
          - component: "RecentlyPlayedRow", props: { horizontal_scroll: true, max: 10, dedup: true }
          - component: "PlaylistsRow", elements: [{ type: "PlaylistCard" }, { type: "CreatePlaylistCard" }]
      - component: "SearchScreen"
        children:
          - component: "SearchInput", props: { debounce: 300, placeholder: "搜索歌曲 / 歌手 / 专辑", pinyin_initials: true, style: "pill_with_accent_icon" }
          - component: "GenreGrid", genres: ["POP#流行", "Rap#说唱", "Folk#民谣", "Rock#摇滚", "Jazz#爵士", "R&B#节奏布鲁斯", "Electronic#电子", "Classical#古典"], layout: "2_col_cards", colors_sampled_from: "官网实拍 07 (DEC-006)"
          - component: "ResultSections", groups: ["曲目", "歌手", "专辑", "歌单", "来源"] , per_group_max: 3
          - component: "EmptyResult", elements: [{ type: "Message", text: "没有找到与「XX」相关的音乐" }, { type: "Hint", text: "检查拼写，或换一个关键词试试" }]
      - component: "MineScreen"
        children:
          - component: "StatCards", cards: ["喜欢(N)", "历史(N)", "本地(N)"], icons: ["heart", "history", "download"], style: "image_cards"
          - component: "PlaylistSection", first_row: "创建 / 导入歌单（副题：把喜欢的音乐装进歌单）"
          - component: "SettingsEntry", icon: "gear", position: "顶栏右侧", action: "open_settings"
      - component: "ShuffleWheelScreen (route: shuffle)"
        children:
          - component: "TextNav", elements: [{ type: "Tab", text: "随机", active: true }, { type: "Tab", text: "音乐空间" }, { type: "Tab", text: "我的" }]
          - component: "CardDeck", props: { slots: 5, cur: "方形海报 240px 焦点", p1_p2: "左上渐远横条", nxt_nxt2: "下方 240x174 横条", layering: "rotate + z-index only (no blur/scale on static cards)" }
            interactions: ["swipe_up => next_track", "drag => follow_with_rotation", "release => spring_back", "track_ended => auto_spin"]
          - component: "InfoColumn", props: { width: 128, align: "right_bottom" }, elements: [{ type: "DropdownLabel", text: "「随机」" }, { type: "TrackTitle" }, { type: "Artist" }, { type: "ProgressBar" }, { type: "Times", props: { tabular_nums: true } }]
          - component: "WheelControlRow", elements: [{ type: "Bin", action: "to_less_play_list" }, { type: "PauseBars", style: "mint_slim_bars" }, { type: "Heart", style: "soft_pink" }]
          - component: "SwipeHint", text: "上滑 — 播放下一首"
      - component: "MiniPlayerBar"
        elements: [{ type: "VinylDisc", size: "36px", spin_when: "playing" }, { type: "MarqueeTitleArtist" }, { type: "PlayPause" }, { type: "QueueBtn" }]
        interactions: ["tap_bar => open_player", "swipe_left => next_track"]
        hidden_when: "no_session"

state_machine:
  search:
    initial: "IDLE"
    states:
      IDLE: { on: { INPUT: "DEBOUNCING" } }
      DEBOUNCING: { on: { TIMEOUT: "SEARCHING", INPUT: "DEBOUNCING", CLEAR: "IDLE" } }
      SEARCHING: { on: { RESULTS: "RESULTS", EMPTY: "EMPTY_RESULT", FAIL: "INDEX_ERROR" } }
      RESULTS: { on: { INPUT: "DEBOUNCING", CLEAR: "IDLE" } }
      EMPTY_RESULT: { on: { INPUT: "DEBOUNCING" } }
      INDEX_ERROR: { on: { REBUILD: "REBUILDING" } }
      REBUILDING: { on: { DONE: "RESULTS" } }
  mhz:
    rule: "随机池=全库-少播名单; 池<10 时全库补满; 单轮不重复"
  shuffle_wheel:
    initial: "PLAYING"
    states:
      PLAYING: { on: { SWIPE_UP: "SPINNING", TRACK_ENDED: "SPINNING", DRAG: "GESTURE" } }
      GESTURE: { on: { RELEASE_FIRE: "SPINNING", RELEASE_IDLE: "PLAYING" } }
      SPINNING: { on: { SETTLED: "PLAYING" } }
    rule: "仅上滑切歌 (无下滑/无点击切歌); 信息区与控件随焦点卡同步"

field_constraints:
  - field: "search_query"
    min_length: 1
    debounce_ms: 300
    matches: ["标题", "歌手", "专辑", "歌单名", "来源UP主", "拼音首字母"]
    perf_budget: "1万首曲库输入到结果 ≤300ms"

executable_tests_gherkin:
  - id: "TEST-NAV-01-MHZ"
    given: "曲库 200 首可播且无少播名单"
    when: "点击随机卡"
    then: "立即随机开播并展开沉浸页；连续下一首一轮不重复"
  - id: "TEST-NAV-02-PINYIN"
    given: "曲库存在《夜黑雾》"
    when: "搜索输入 yhw"
    then: "300ms 内出现《夜黑雾》"
  - id: "TEST-NAV-03-STATCARD"
    given: "红心 3 首、播过 5 首、曲库 40 首"
    when: "打开我的页"
    then: "三卡分别 3/5/40，点击进入对应列表一致"

hard_guardrails:
  - "STRICTLY FORBIDDEN: 音乐空间页出现在线推荐/排行榜类未兑现内容（反目标）"
  - "STRICTLY FORBIDDEN: Tab 切换导致播放中断或状态丢失"
  - "STRICTLY FORBIDDEN: 搜索空结果显示死胡同（必须给建议）"
  - "STRICTLY FORBIDDEN: 首屏强调色超过 3 处"
  - "STRICTLY FORBIDDEN: 轮盘页出现下滑手势或点击卡面切歌替代上滑 (DEC-006 D6-7 仅上滑)"
  - "STRICTLY FORBIDDEN: 静态非当前卡使用模糊/缩放/透明度弱化 (层次仅靠旋转渐进 + z 序; 仅切歌过渡卡允许淡入淡出)"
  - "STRICTLY FORBIDDEN: 浅色轮盘页暂停键使用白圆底或沿用深色页全局 accent (须薄荷细条等专项色)"
