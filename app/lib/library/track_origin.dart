/// 曲目来源统一抽象（用户裁定：本地文件与 B 站在线音乐**一个模型**，不二元分叉）。
///
/// 领域事实：两条入库通道（本地扫描 / B 站提取）早已汇入同一 `tracks` 表、
/// 同一 `TrackLite` 播放队列、同一封面链——不存在行为分叉，只有**展示散点**：
/// UI 层曾到处写 `sourceType == 'bilibili'` 字符串判断。本文件是唯一来源面：
/// 判定用 [TrackOriginX.origin]，展示用 [TrackOriginX.originLabel]。
library;

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/l10n/app_localizations.dart';

enum TrackOrigin { local, bilibili }

extension TrackOriginX on Track {
  /// 来源判定（唯一入口；sourceType 空值/未知一律归本地——extract 链路
  /// 注册时恒写 'bilibili'，故 null=本地扫描是稳定不变量）。
  TrackOrigin get origin =>
      sourceType == 'bilibili' ? TrackOrigin.bilibili : TrackOrigin.local;

  /// 展示标签（角标/详情共用；本地不展示——「本地」不是需要声明的信息）。
  String? originLabel(AppLocalizations t) => switch (origin) {
        TrackOrigin.bilibili => t.sourceBili,
        TrackOrigin.local => null,
      };
}
