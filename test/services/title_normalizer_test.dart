/// 歌名归一化纯函数测试（扫描管线的真实规则）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/services/enrich/title_normalizer.dart';

void main() {
  group('normalizeTitle', () {
    test('去前导曲号', () {
      expect(normalizeTitle(raw: '01 - 夜曲').title, '夜曲');
      expect(normalizeTitle(raw: '07_晴天.mp3 前缀', fileName: '07_晴天.mp3').title,
          '晴天.mp3 前缀');
      expect(normalizeTitle(raw: '3 夜曲').title, '夜曲');
    });

    test('歌手已知：按标签剥离', () {
      final n = normalizeTitle(raw: '周杰伦 - 夜曲', artistTag: '周杰伦');
      expect(n.title, '夜曲');
      expect(n.artist, isNull); // 不覆盖已有歌手
    });

    test('歌手未知：文件名推断 歌手 - 歌名', () {
      final n = normalizeTitle(raw: '周杰伦 - 夜曲', fileName: '周杰伦 - 夜曲.mp3');
      expect(n.title, '夜曲');
      expect(n.artist, '周杰伦');
    });

    test('去装饰段：【…】恒去', () {
      expect(normalizeTitle(raw: '夜曲【高清MV】').title, '夜曲');
    });

    test('去含媒体关键词的圆括号段', () {
      expect(normalizeTitle(raw: '夜曲 (Official Video)').title, '夜曲');
      expect(normalizeTitle(raw: '夜曲 (Live)').title, '夜曲');
    });

    test('保留不含关键词的合法括号内容', () {
      expect(normalizeTitle(raw: '夜曲 (2005)').title, contains('(2005)'));
    });

    test('空白折叠与空回退', () {
      expect(normalizeTitle(raw: '   夜曲   ').title, '夜曲');
      expect(normalizeTitle(raw: '【】【】').title, '未知歌曲');
      expect(normalizeTitle(raw: '', fileName: '06.wav').title, '06');
      expect(normalizeTitle(raw: '', fileName: '01.mp3').title, '01');
      expect(normalizeTitle(raw: '', fileName: '01 - 晴天.mp3').title, '晴天');
    });
  });
}
