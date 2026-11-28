/// 常听与历史屏：磁贴翻面（FlipTile）行为 + 点封面起播。
///
/// 周期翻面不挂 Timer（单控制器 Interval 分段自循环，见 wp_motion.FlipTile），
/// 测试里用带时长 pump 跳到翻面窗口内验证背面信息，绝不 pumpAndSettle
/// （循环控制器永不落定）。
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/data/daos/history_dao.dart';
import 'package:ia_music/domain/entities/playback.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/state/library_providers.dart';
import 'package:ia_music/state/listen_providers.dart';
import 'package:ia_music/state/media_providers.dart';
import 'package:ia_music/state/playback_controller.dart';
import 'package:ia_music/ui/motion/wp_motion.dart';
import 'package:ia_music/ui/played/played_page.dart';

Track _trackOf({required int id, required String title}) => Track(
      id: id,
      rootId: 1,
      relPath: 't$id.mp3',
      path: '/music/t$id.mp3',
      title: title,
      artist: 'A$id',
      album: 'L',
      genre: '',
      durationMs: 60000,
      sizeBytes: 1,
      contentHash: 'h$id',
      audioFormat: 'mp3',
      trackNo: id,
      coverPath: null,
      addedAt: DateTime(2024, 1, 1),
    );

class _FakePlayback extends PlaybackController {
  _FakePlayback(this.initial);

  final PlaybackSnapshot initial;

  @override
  PlaybackSnapshot build() => initial;
}

/// 记录点播命令的假控制器。
class _RecordingPlayback extends _FakePlayback {
  _RecordingPlayback(super.initial);

  final starts = <Track>[];

  @override
  Future<void> playTrack(Track start, {List<Track>? queue, bool? shuffle}) async {
    starts.add(start);
  }
}

PlaybackSnapshot _snapshot({Track? current}) => PlaybackSnapshot(
      queue: current == null ? const <Track>[] : [current],
      index: current == null ? -1 : 0,
      playing: current != null,
      loading: false,
      ended: false,
      positionMs: 0,
      volume: 100,
      shuffle: false,
      repeat: RepeatMode.off,
      sleepEndsAt: null,
    );

/// 常听 1 首（播 5 次）+ 历史 1 首（累计 3 次；正面从不显示次数）。
Widget _app(PlaybackController playback) {
  final top = _trackOf(id: 1, title: '夜曲');
  final recent = _trackOf(id: 2, title: '晴天');
  return ProviderScope(
    overrides: [
      playbackProvider.overrideWith(() => playback),
      coverProvider.overrideWith((ref, key) async => null),
      favoritesSetProvider.overrideWith((ref) => Stream.value(const <int>{})),
      topTracksProvider.overrideWith((ref) => Stream.value([
            TrackPlays(track: top, plays: 5),
          ])),
      historyProvider.overrideWith((ref) => Stream.value([
            HistoryItem(
                track: recent,
                playedAt: DateTime(2024, 1, 2),
                completed: true,
                plays: 3),
          ])),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
      home: const Scaffold(body: PlayedPage()),
    ),
  );
}

/// 渲染并冲刷 StreamProvider 状态（两帧：订阅微任务 + 依赖重建）。
/// 画布拉高到 390×1600：历史段在常听段之下，默认 800px 视口内 sliver
/// 不落位（lazily build），找不到历史磁贴。
Future<void> _pumpPage(WidgetTester tester, PlaybackController playback) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(playback));
  await tester.pump();
  await tester.pump();
}

/// 翻出窗口内（背面停留中段）的时间点。
Duration get _atBack =>
    IaMotion.tileFlipLead +
    IaMotion.tileFlip +
    (IaMotion.tileFlipHold ~/ 2);

/// 羽化最长总时长（末槽位）：落定帧整棵重挂条目（FeatherIn 结构切换），
/// 翻面控制器从重挂后重新起算——先越过落定帧再量翻面窗口。
Duration get _featherSettled =>
    IaMotion.feather + IaMotion.featherStep * IaMotion.featherMaxItems;

void main() {
  testWidgets('PlayedPage · 冒烟：两段网格渲染无异常', (tester) async {
    await _pumpPage(tester, _FakePlayback(_snapshot()));
    expect(tester.takeException(), isNull);
    expect(find.text('夜曲'), findsWidgets); // 常听正面（背面未翻）
    expect(find.text('晴天'), findsOneWidget);
  });

  testWidgets('PlayedPage · 点封面起播（按曲目身份）', (tester) async {
    final playback = _RecordingPlayback(_snapshot());
    await _pumpPage(tester, playback);
    await tester.pump(const Duration(milliseconds: 500)); // 羽化落定，未到首翻
    await tester.tap(find.text('晴天'));
    await tester.pump();
    expect(playback.starts.single.id, 2);
  });

  testWidgets('PlayedPage · 历史磁贴翻面露出次数/歌名/歌手，周期末翻回',
      (tester) async {
    await _pumpPage(tester, _FakePlayback(_snapshot()));
    // 双层羽化（HubPage 段落级 + 磁贴级）各自落定时都整棵重挂子树，
    // 磁贴层羽化在段落层落定后重新起算——两次落定帧都越过后，
    // 翻面控制器才真正稳定起算。
    await tester.pump(_featherSettled);
    await tester.pump(_featherSettled);

    // 首翻前：历史正面无次数（与常听 front meta 区分开）
    expect(find.text('3 次'), findsNothing);
    expect(find.text('5 次'), findsOneWidget);

    // 翻出窗口内：背面信息页（次数 accent 大字 + 歌名 + 歌手）
    await tester.pump(_atBack);
    expect(tester.takeException(), isNull);
    expect(find.text('3 次'), findsOneWidget);
    expect(find.text('晴天'), findsNWidgets(2)); // 正面行 + 背面
    expect(find.text('A2'), findsNWidgets(2));
    // 常听磁贴同窗口翻面：正面 meta 之外多出背面大字
    expect(find.text('5 次'), findsNWidgets(2));

    // 周期走完翻回：背面消失
    await tester.pump(IaMotion.tileFlipCycle - _atBack);
    await tester.pump();
    expect(find.text('3 次'), findsNothing);
    expect(find.text('5 次'), findsOneWidget);
  });

  testWidgets('FlipTile · 超参与上限的磁贴恒为正面', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlipTile(
          index: IaMotion.tileFlipMaxItems,
          back: const Text('BACK'),
          child: const Text('FRONT'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(_atBack);
    expect(find.text('BACK'), findsNothing);
    expect(find.text('FRONT'), findsOneWidget);
  });

  testWidgets('FlipTile · 末槽位错峰翻面（窗口后移不越界）', (tester) async {
    final last = IaMotion.tileFlipMaxItems - 1;
    final atBack = IaMotion.tileFlipLead +
        IaMotion.tileFlipStagger * last +
        IaMotion.tileFlip +
        (IaMotion.tileFlipHold ~/ 2);
    expect(atBack < IaMotion.tileFlipCycle, isTrue,
        reason: '末槽位窗口必须落在周期内');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlipTile(
          index: last,
          back: const Text('BACK'),
          child: const Text('FRONT'),
        ),
      ),
    ));
    await tester.pump();

    // 未到自己的错峰窗口：仍是正面
    await tester
        .pump(IaMotion.tileFlipLead + IaMotion.tileFlipStagger * last ~/ 2);
    expect(find.text('BACK'), findsNothing);

    // 进入窗口（背面停留中段）：翻面
    await tester.pump(IaMotion.tileFlipStagger * last ~/ 2 +
        IaMotion.tileFlip +
        (IaMotion.tileFlipHold ~/ 2));
    expect(find.text('BACK'), findsOneWidget);

    // 周期收尾翻回
    await tester.pump(IaMotion.tileFlipCycle - atBack);
    await tester.pump();
    expect(find.text('FRONT'), findsOneWidget);
  });
}
