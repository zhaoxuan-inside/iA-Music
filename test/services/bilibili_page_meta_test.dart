/// B 站分 P 标题解析：真实 100P 合集的分 P 命名回归。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/services/collect/bilibili_page_meta.dart';

void main() {
  group('parseBiliPageMeta', () {
    test('编号 + 歌手-歌名', () {
      final m = parseBiliPageMeta('001.周杰伦-爱在西元前',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '爱在西元前');
      expect(m.artist, '周杰伦');
    });

    test('合作歌手用 _ 连接', () {
      final m = parseBiliPageMeta('005.潘玮柏_弦子-不得不爱',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '不得不爱');
      expect(m.artist, '潘玮柏 / 弦子');
    });

    test('英文/标点艺人名', () {
      final m = parseBiliPageMeta('011.F.I.R.飞儿乐团-你的微笑',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '你的微笑');
      expect(m.artist, 'F.I.R.飞儿乐团');
    });

    test('没有歌手分隔符：保留分 P 名，歌手回退 UP 主', () {
      final m = parseBiliPageMeta('经典老歌串烧',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '经典老歌串烧');
      expect(m.artist, 'UP主');
    });

    test('纯数字分 P 名：用视频标题补齐', () {
      final m = parseBiliPageMeta('12',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '经典老歌100首 - 12');
      expect(m.artist, 'UP主');
    });

    test('空分 P 名：回退标题', () {
      final m = parseBiliPageMeta('',
          fallbackTitle: '经典老歌100首', fallbackArtist: 'UP主');
      expect(m.title, '经典老歌100首');
      expect(m.artist, 'UP主');
    });
  });
}
