/// IaIcon —— 全站图标唯一取用面（Material Symbols Rounded 细线语言）。
/// 统一圆角细线（Rounded + wght400）；激活态 `fill:1` + accent。
library;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

abstract final class IaIcon {
  // ── 导航 ──
  static IconData get library => Symbols.library_music_rounded; // 曲库 Tab
  static IconData get search => Symbols.search_rounded;
  static IconData get playlist => Symbols.queue_music_rounded;
  static IconData get settings => Symbols.settings_rounded;
  static IconData get tracks => Symbols.music_note_rounded;
  static IconData get albums => Symbols.album_rounded;
  static IconData get artists => Symbols.person_rounded;

  // ── 播放 ──
  static IconData get play => Symbols.play_arrow_rounded;
  static IconData get pause => Symbols.pause_rounded;
  static IconData get next => Symbols.skip_next_rounded;
  static IconData get previous => Symbols.skip_previous_rounded;
  static IconData get shuffle => Symbols.shuffle_rounded;
  static IconData get repeat => Symbols.repeat_rounded;
  static IconData get repeatOne => Symbols.repeat_one_rounded;
  static IconData get sequence => Symbols.playlist_play_rounded;
  static IconData get lyrics => Symbols.lyrics_rounded;
  static IconData get equalizer => Symbols.equalizer_rounded;
  static IconData get heart => Symbols.favorite_rounded;
  static IconData get volume => Symbols.volume_up_rounded;

  // ── 内容操作 ──
  static IconData get link => Symbols.link_rounded;
  static IconData get download => Symbols.download_rounded;
  static IconData get extract => Symbols.travel_explore_rounded;
  static IconData get autoFix => Symbols.auto_fix_high_rounded; // 识别修正
  static IconData get refresh => Symbols.refresh_rounded;
  static IconData get close => Symbols.close_rounded;
  static IconData get back => Symbols.arrow_back_rounded;
  static IconData get more => Symbols.more_horiz_rounded;
  static IconData get add => Symbols.add_rounded;
  static IconData get edit => Symbols.edit_rounded;
  static IconData get delete => Symbols.delete_rounded;
  static IconData get check => Symbols.check_rounded;
  static IconData get checkCircle => Symbols.check_circle_rounded;
  static IconData get error => Symbols.error_rounded;
  static IconData get schedule => Symbols.schedule_rounded;
  static IconData get lock => Symbols.lock_rounded;
  static IconData get person => Symbols.person_rounded;
  static IconData get musicNote => Symbols.music_note_rounded;
  static IconData get album => Symbols.album_rounded;
  static IconData get folder => Symbols.folder_rounded;
  static IconData get scanQr => Symbols.qr_code_scanner_rounded;
  static IconData get qrCode => Symbols.qr_code_2_rounded;
  static IconData get cookie => Symbols.cookie_rounded;
  static IconData get shield => Symbols.verified_user_rounded;
  static IconData get warning => Symbols.warning_rounded;
  static IconData get tune => Symbols.tune_rounded;
  static IconData get gridView => Symbols.grid_view_rounded;
  static IconData get viewList => Symbols.view_list_rounded;
  static IconData get arrowForward => Symbols.arrow_forward_rounded;
  static IconData get lightMode => Symbols.light_mode_rounded;
  static IconData get darkMode => Symbols.dark_mode_rounded;
  static IconData get autoMode => Symbols.brightness_auto_rounded;
  static IconData get logout => Symbols.logout_rounded;
  static IconData get favoriteList => Symbols.favorite_rounded;
}
