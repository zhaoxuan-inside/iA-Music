/// 页面路由表——跨页跳转的唯一出口。
///
/// 页面互不认识：所有跨域页面 push 收口在此（zuneRoute 转场在 route.dart
/// 统一挂）。路由层是唯一允许 import 页面本体的 UI 公共件——调用方
/// （页面/编排层）只 import 这里，不 import 页面文件。共享组合页
/// （detail/search 双域容器）可被各域直接 import，不受此限。
library;

import 'package:flutter/material.dart';

import '../../domain/entities/track.dart';
import '../collect/extract_tasks_page.dart';
import '../collect/link_extract_page.dart';
import '../collect/platform_search_page.dart';
import '../detail/detail_page.dart';
import '../enrich/process_page.dart';
import '../layout/route.dart';
import '../library/track_edit_page.dart';
import '../plugins/plugins_page.dart';
import '../search/search_page.dart';

export '../detail/detail_page.dart' show DetailType;

/// 打开详情页（专辑/歌手/流派/歌单四型）。
Future<void> openDetail(BuildContext context, DetailType type, String id) =>
    Navigator.of(context)
        .push(zuneRoute<void>(builder: (_) => DetailPage(type: type, id: id)));

/// 打开编辑歌曲信息页。
Future<void> openTrackEdit(BuildContext context, Track track) =>
    Navigator.of(context)
        .push(zuneRoute<void>(builder: (_) => TrackEditPage(track: track)));

/// 打开搜索页。
Future<void> openSearch(BuildContext context) => Navigator.of(context)
    .push(zuneRoute<void>(builder: (_) => const MusicSearchPage()));

/// 打开平台站内搜索提取页（收集域，指定插件源）。
Future<void> openPlatformSearch(
        BuildContext context, String pluginId, String name) =>
    Navigator.of(context).push(zuneRoute<void>(
        builder: (_) =>
            PlatformSearchPage(pluginId: pluginId, name: name)));

/// 打开链接提取页（收集域）。
Future<void> openLinkExtract(BuildContext context) => Navigator.of(context)
    .push(zuneRoute<void>(builder: (_) => const LinkExtractPage()));

/// 打开提取任务详情页（收集域）。
Future<void> openExtractTasks(BuildContext context) => Navigator.of(context)
    .push(zuneRoute<void>(builder: (_) => const ExtractTasksPage()));

/// 打开插件管理页（插件域）。
Future<void> openPlugins(BuildContext context) => Navigator.of(context)
    .push(zuneRoute<void>(builder: (_) => const PluginsPage()));

/// 打开歌曲处理页（补全域）。
Future<void> openProcess(BuildContext context) => Navigator.of(context)
    .push(zuneRoute<void>(builder: (_) => const ProcessPage()));
