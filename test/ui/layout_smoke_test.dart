/// UI 冒烟：在 390×844 的手机画布上渲染核心页面，确保没有溢出/断言。
///
/// 只覆盖不依赖真实音频与数据库的展示路径；数据 provider 用最小 override。
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/domain/entities/playback.dart';
import 'package:ia_music/domain/entities/playlist.dart';
import 'package:ia_music/domain/entities/quickplay.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/state/library_providers.dart';
import 'package:ia_music/state/listen_providers.dart';
import 'package:ia_music/state/media_providers.dart';
import 'package:ia_music/state/playback_controller.dart';
import 'package:ia_music/state/playlist_providers.dart';
import 'package:ia_music/state/quickplay_providers.dart';
import 'package:ia_music/ui/detail/detail_page.dart';
import 'package:ia_music/ui/library/songs_page.dart';
import 'package:ia_music/ui/play/now_playing.dart';
import 'package:ia_music/ui/playing/playing_page.dart';
import 'package:ia_music/ui/quickplay/quickplay_page.dart';
import 'package:ia_music/ui/search/search_page.dart';
import 'package:ia_music/ui/shared/ui_kit.dart';

final _track = Track(
  id: 1,
  rootId: 1,
  relPath: 'a.mp3',
  path: '/music/a.mp3',
  title: '夜曲',
  artist: '周杰伦',
  album: '十一月的萧邦',
  genre: '华语流行',
  durationMs: 226000,
  sizeBytes: 1,
  contentHash: 'h',
  audioFormat: 'mp3',
  trackNo: 1,
  coverPath: null,
  addedAt: DateTime(2024, 1, 1),
);

class _FakePlayback extends PlaybackController {
  _FakePlayback(this.initial);

  final PlaybackSnapshot initial;

  @override
  PlaybackSnapshot build() => initial;
}

class _FakeQuickplay extends QuickplayController {
  _FakeQuickplay(this.initial);

  final QuickplayState initial;

  @override
  QuickplayState build() => initial;
}

PlaybackSnapshot _snapshot({Track? current}) => PlaybackSnapshot(
      queue: current == null ? const <Track>[] : [current],
      index: current == null ? -1 : 0,
      playing: current != null,
      loading: false,
      ended: false,
      positionMs: 61000,
      durationMs: current?.durationMs ?? 0,
      volume: 100,
      shuffle: false,
      repeat: RepeatMode.off,
      sleepEndsAt: null,
    );

Widget _app(Widget child, PlaybackSnapshot snap) {
  return ProviderScope(
    overrides: [
      playbackProvider.overrideWith(() => _FakePlayback(snap)),
      coverProvider.overrideWith((ref, key) async => null),
      favoritesSetProvider.overrideWith((ref) => Stream.value(const <int>{})),
      recentAddedAlbumsProvider
          .overrideWith((ref) => Stream.value(const <AlbumGroup>[])),
      trackCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(accent: kDefaultAccent),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('PlayingPage · 无会话', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(const PlayingPage(), _snapshot()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayingPage · 在播', (tester) async {
    await phone(tester);
    await tester
        .pumpWidget(_app(const PlayingPage(), _snapshot(current: _track)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('NowPlayingPage · 播放屏', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
        _app(const NowPlayingPage(), _snapshot(current: _track)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongsPage · 曲库列表', (tester) async {
    await phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider
            .overrideWith(() => _FakePlayback(_snapshot(current: _track))),
        coverProvider.overrideWith((ref, key) async => null),
        favoritesSetProvider.overrideWith((ref) => Stream.value(const <int>{})),
        tracksProvider.overrideWith((ref, sort) => Stream.value([_track])),
        trackCountProvider.overrideWith((ref) => Stream.value(1)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const Scaffold(body: SongsPage()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('NowPlayingPage · 小屏 320×568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        _app(const NowPlayingPage(), _snapshot(current: _track)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayingPage · 小屏 320×568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        _app(const PlayingPage(), _snapshot(current: _track)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DetailPage · 小屏 320×568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider
            .overrideWith(() => _FakePlayback(_snapshot(current: _track))),
        coverProvider.overrideWith((ref, key) async => null),
        favoritesSetProvider.overrideWith((ref) => Stream.value(const <int>{})),
        quickplayProvider.overrideWith(
            () => _FakeQuickplay(const QuickplayState(loaded: true))),
        albumsProvider.overrideWith((ref) => Stream.value([
              const AlbumGroup(
                album: '十一月的萧邦',
                artist: '周杰伦',
                trackCount: 1,
                totalDurationMs: 226000,
              ),
            ])),
        albumTracksProvider
            .overrideWith((ref, key) => Stream.value([_track])),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const DetailPage(type: DetailType.album, id: '十一月的萧邦'),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuickplayPage · 固定磁贴', (tester) async {
    await phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider
            .overrideWith(() => _FakePlayback(_snapshot(current: _track))),
        coverProvider.overrideWith((ref, key) async => null),
        recentAddedAlbumsProvider.overrideWith((ref) => Stream.value([
              const AlbumGroup(
                album: '十一月的萧邦',
                artist: '周杰伦',
                trackCount: 1,
                totalDurationMs: 226000,
              ),
            ])),
        albumTracksProvider
            .overrideWith((ref, key) => Stream.value([_track])),
        playlistTracksProvider
            .overrideWith((ref, id) => Stream.value(const <Track>[])),
        quickplayProvider.overrideWith(
            () => _FakeQuickplay(const QuickplayState(loaded: true, pins: [
                  QuickplayPin(
                    kind: QuickplayKind.album,
                    key: '十一月的萧邦',
                    title: '十一月的萧邦',
                    subtitle: '周杰伦',
                  ),
                  QuickplayPin(
                    kind: QuickplayKind.playlist,
                    key: '1',
                    title: '夜曲',
                    subtitle: '1 首',
                  ),
                ]))),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const Scaffold(body: QuickplayPage()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuickplayPage · 空态', (tester) async {
    await phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider.overrideWith(
            () => _FakePlayback(_snapshot())),
        coverProvider.overrideWith((ref, key) async => null),
        recentAddedAlbumsProvider
            .overrideWith((ref) => Stream.value(const <AlbumGroup>[])),
        quickplayProvider.overrideWith(
            () => _FakeQuickplay(const QuickplayState(loaded: true))),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const Scaffold(body: QuickplayPage()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QuickplayPage · 小屏 320×568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider
            .overrideWith(() => _FakePlayback(_snapshot(current: _track))),
        coverProvider.overrideWith((ref, key) async => null),
        recentAddedAlbumsProvider
            .overrideWith((ref) => Stream.value(const <AlbumGroup>[])),
        albumTracksProvider
            .overrideWith((ref, key) => Stream.value([_track])),
        artistTracksProvider
            .overrideWith((ref, key) => Stream.value([_track])),
        quickplayProvider.overrideWith(
            () => _FakeQuickplay(const QuickplayState(loaded: true, pins: [
                  QuickplayPin(
                    kind: QuickplayKind.album,
                    key: '十一月的萧邦',
                    title: '十一月的萧邦',
                    subtitle: '周杰伦',
                  ),
                  QuickplayPin(
                    kind: QuickplayKind.artist,
                    key: '周杰伦',
                    title: '周杰伦',
                    subtitle: '全部专辑',
                  ),
                  QuickplayPin(
                    kind: QuickplayKind.album,
                    key: '叶惠美',
                    title: '叶惠美',
                    subtitle: '周杰伦',
                  ),
                ]))),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const Scaffold(body: QuickplayPage()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('showWpToast · 显示与自动收回', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(accent: kDefaultAccent),
      home: const Scaffold(body: _ToastHost()),
    ));
    await tester.tap(find.text('toast'));
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('MusicSearchPage · 本地结果与在线入口', (tester) async {
    await phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playbackProvider
            .overrideWith(() => _FakePlayback(_snapshot(current: _track))),
        coverProvider.overrideWith((ref, key) async => null),
        favoritesSetProvider.overrideWith((ref) => Stream.value(const <int>{})),
        tracksProvider.overrideWith((ref, sort) => Stream.value([_track])),
        artistsProvider.overrideWith((ref) => Stream.value(const <ArtistGroup>[])),
        albumsProvider.overrideWith((ref) => Stream.value(const <AlbumGroup>[])),
        playlistListProvider
            .overrideWith((ref) => Stream.value(const <Playlist>[])),
        ftsSearchProvider
            .overrideWith((ref, query) => Stream.value([_track])),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent),
        home: const MusicSearchPage(),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('本地曲库'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '夜曲');
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('夜曲'), findsWidgets);
  });
}

class _ToastHost extends StatelessWidget {
  const _ToastHost();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () =>
            showWpToast(context, title: 'TOAST', message: 'hello'),
        child: const Text('toast'),
      ),
    );
  }
}
