// D1 / checkpoint A: real files → real scan/SQLite → real mpv → playlists.
import 'dart:async';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/mpv_engine_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/playlists/playlist_service.dart';

void main() {
  test('D1 扫描真实计数→随机实播→封面→红心/歌单→按序播放；音频不改', () async {
    final dir = await Directory.systemTemp.createTemp('ia_d1_');
    final db = (await openIaDatabaseMemory()).db;
    final hub = LibraryHub(db);
    final engine = MpvEngineAdapter();
    final playback = PlaybackService(engine, hub.data);
    final playlist = PlaylistService(hub.data);
    StreamSubscription<EngineEvent>? events;
    addTearDown(() async {
      await events?.cancel();
      await playback.dispose();
      await hub.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });
    await for (final file in Directory('test/fixtures/library_smoke').list()) {
      if (file is File) {
        await file.copy('${dir.path}/${file.uri.pathSegments.last}');
      }
    }
    final covered = await File('test/fixtures/cover/embedded.mp3')
        .copy('${dir.path}/探曲03.mp3');
    final before = sha256.convert(await covered.readAsBytes()).toString();
    final scan = await hub.addRepositoryAndScan(dir.path);
    expect(scan.total, 10);
    expect(scan.skipped, 2);
    final rows = await hub.trackRowsSnapshot(LibSort.title);
    expect(rows.length, 10);
    final withCover = rows.singleWhere((t) => t.relPath == '探曲03.mp3');
    expect(withCover.contentHash, before);
    expect((await hub.covers.decide(withCover.id)).kind, CoverKind.embedded);

    await playback.init();
    final playing = Completer<void>();
    events = engine.events.listen((e) {
      if (e is EngineStateChanged &&
          e.state == EngineState.playing &&
          !playing.isCompleted) {
        playing.complete();
      }
    });
    await playback.startRandom(poolSize: 5);
    await playing.future.timeout(const Duration(seconds: 15));
    await playback.pause();
    final snapshot = playback.snapshot;
    expect(snapshot.queue.length, 5);
    expect(snapshot.queue.map((t) => t.id).toSet().length, 5);
    expect(snapshot.mode, PlaybackMode.random);
    final first = snapshot.currentTrack!.id;
    final second = snapshot.queue.firstWhere((t) => t.id != first).id;
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(await playlist.toggleFavorite(first, nowMs: now), isTrue);
    expect(await playlist.favoriteCount(), 1);
    final custom = await playlist.create('D1 真链演练', nowMs: now);
    expect(await playlist.addTo(custom.id, first, nowMs: now), isTrue);
    expect(await playlist.addTo(custom.id, second, nowMs: now), isTrue);
    expect(await playlist.addTo(custom.id, first, nowMs: now), isFalse);
    final saved = await playlist.rows(custom.id);
    expect(saved.map((t) => t.id).toList(), [first, second]);
    await playback.playTrackIds(saved.map((t) => t.id).toList());
    expect(playback.snapshot.queue.map((t) => t.id).toList(), [first, second]);
    expect(playback.snapshot.currentTrack!.id, first);
    expect(sha256.convert(await covered.readAsBytes()).toString(), before);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
