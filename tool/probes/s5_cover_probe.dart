// Live diagnostic, never substitutes endpoints or recorded responses.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/cover_fetch_adapter.dart';

Future<void> main(List<String> args) async {
  final adapter = CoverFetchAdapter();
  try {
    final result = await adapter.fetchTrackCover(
      CoverQuery(
        trackId: 1,
        title: args.isEmpty ? 'Come Together' : args[0],
        artistDisplay: args.length < 2 ? 'The Beatles' : args[1],
        albumDisplay: args.length < 3 ? null : args[2],
      ),
    );
    for (final request in adapter.requests) {
      print('REQUEST ${request.startedAt.toIso8601String()} ${request.uri}');
    }
    for (final response in adapter.responses) {
      print('RESPONSE ${response.statusCode} ${response.uri}');
    }
    print('RESULT ${result?.source.name} ${result?.localPath}');
    if (result != null) {
      final file = File(result.localPath);
      print('JPEG_BYTES ${await file.length()}');
      await file.delete();
      await file.parent.delete();
    }
  } finally {
    adapter.close();
  }
}
