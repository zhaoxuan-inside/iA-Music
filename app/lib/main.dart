/// iA-Music 应用入口（2026-10-25 第三轮 UI 重构装配，DEC-012）：
/// * 真库打开（损坏→只读门+提示横幅兜底）。
/// * 组合根=`LibraryHub`；壳层=AppShell（资料库中心：TRACKS 首页，
///   桌面侧栏子树/移动 4 Tab，D12-3）。
/// * 主题=封面动态取色（AccentController → buildIaTheme；null=品牌绿，D12-6）
///   × DEC-005 外观三选。
library;

import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/app_shell.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';
import 'package:ia_music/ui/shell/onboarding_page.dart';
import 'package:ia_music/ui/theme/accent_controller.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 应用版本（与 pubspec.yaml 同步；WS8 发布时一并 bump）。
const String kIaAppVersion = '1.1.0+4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestNotificationPermission(); // REQ-PLAY-05：后台播放通知（Android 13+）
  final support = await getApplicationSupportDirectory();
  final gate = await openIaDatabase('${support.path}/ia_music.db');
  final hub = LibraryHub(gate.db);
  // 启动重挂既有仓库 watcher + 增量补扫（关闭期间盘上变更入库 → 识别修正入队）。
  await hub.attachWatchers();
  await hub.sync.attach(); // WS6 同步域（通道装配 + drift 变更喂点）
  // T9B 启动续泵（拆分年代 resolved 队列可长；合规门禁在 resumeQueued 内一致执行）。
  await hub.extract.resumeQueued();
  hub.wireExtractRevisionToRevisions();
  final appearance = await AppearanceController.load(hub.data);
  final locale = await LocaleController.load(hub.data); // D5-2 语言三选
  final accent = AccentController(hub.covers); // D12-6 动态取色
  runApp(IaMusicApp(
    hub: hub,
    readOnlyGate: gate.isReadOnlyGate,
    appearance: appearance,
    locale: locale,
    accent: accent,
  ));
}

/// Android 13+ 通知运行时权限（媒体会话通知面；best-effort 不阻塞启动）。
Future<void> _requestNotificationPermission() async {
  if (!Platform.isAndroid) {
    return;
  }
  try {
    await Permission.notification.request();
  } on Object {
    // 未授权→通知栏控制不可用，App 内播放不受影响
  }
}

final class IaMusicApp extends StatefulWidget {
  const IaMusicApp({
    super.key,
    required this.hub,
    required this.readOnlyGate,
    required this.appearance,
    required this.locale,
    this.accent,
  });

  final LibraryHub hub;
  final bool readOnlyGate;
  final AppearanceController appearance;

  /// 语言三选（DEC-005 D5-2）。
  final LocaleController locale;

  /// 动态取色（null=装配面未提供→固定品牌绿基板，测试缝）。
  final AccentController? accent;

  @override
  State<IaMusicApp> createState() => _IaMusicAppState();
}

class _IaMusicAppState extends State<IaMusicApp> {
  /// FTUE 门（REQ-ONB-01）：首次安装（无 onboarding.done 标记）→ 引导页。
  bool? _onboardDone; // null=读取中

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      final raw = await widget.hub.data.shell.value(kOnboardingDoneKey);
      if (mounted) {
        setState(() => _onboardDone = raw == 'true');
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    // 三层：seed（换曲）× themeMode（DEC-005 三选）× locale（D5-2 语言三选）；
    // MaterialApp 内建 AnimatedTheme + IaPalette.lerp 全字段插值承载平滑过渡。
    return ValueListenableBuilder<Color?>(
      valueListenable:
          widget.accent ?? const AlwaysStoppedAnimation<Color?>(null),
      builder: (context, seed, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: widget.appearance,
        builder: (context, mode, _) => ValueListenableBuilder<AppLanguage>(
          valueListenable: widget.locale,
          builder: (context, lang, _) => MaterialApp(
          title: 'iA-Music',
          theme: buildIaTheme(Brightness.light, seed: seed),
          darkTheme: buildIaTheme(Brightness.dark, seed: seed),
          themeMode: mode,
          locale: widget.locale.resolvedLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            // Android 15 edge-to-edge：状态栏透明，图标亮暗随主题画布反色。
            value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  if (widget.readOnlyGate)
                    Material(
                      color: const Color(0xFF7A1F1F),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(kRecoveryHint(),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            ),
          ),
          home: _onboardDone == false
              ? OnboardingPage(
                  hub: widget.hub,
                  onDone: () async {
                    if (mounted) {
                      setState(() => _onboardDone = true);
                    }
                  },
                )
              : AppShell(
                  hub: widget.hub,
                  appearance: widget.appearance,
                  locale: widget.locale,
                  accent: widget.accent,
                ),
          ),
        ),
      ),
    );
  }
}
