/// iA-Music 应用入口（S9/S10 终装配前的**首次产品装配**，2026-10-19）：
/// * 真库打开（§1.4 回退门：损坏→只读门+提示，不再有计数器 Demo）。
/// * 组合根=`LibraryHub`；壳层=三 Tab HomeShell（NAV-01）。
/// * 停止页兜底=只读门横幅（kRecoveryHint；S9/S10 视觉收口位）。
library;

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/ui/shell/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final gate = await openIaDatabase('${support.path}/ia_music.db');
  final hub = LibraryHub(gate.db);
  runApp(IaMusicApp(hub: hub, readOnlyGate: gate.isReadOnlyGate));
}

final class IaMusicApp extends StatelessWidget {
  const IaMusicApp({super.key, required this.hub, required this.readOnlyGate});

  final LibraryHub hub;
  final bool readOnlyGate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iA-Music',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            if (readOnlyGate)
              Material(
                color: const Color(0xFF7A1F1F),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(kRecoveryHint,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
      home: HomeShell(hub: hub),
    );
  }
}
