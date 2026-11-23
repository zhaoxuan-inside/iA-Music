/// 右缘字母速查轨——复刻 Windows 11 跳转栏（jump bar）逻辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/design_tokens.dart';

/// 右缘字母速查轨——复刻 Windows 11 跳转栏（jump bar）逻辑：
///
/// * **按下即定位**：手指落点对应字母立即生效（跳组 + 中央大字母弹出），
///   轨上该字母高亮放大，第一下就有振动确认；
/// * **拖动实时刷屏**：列表跟随手指即时跳组（无缓动等待），每越过一个
///   字母触发一次 `selectionClick` 振动，与 Win11 滑过刻度一致；
/// * **松手即停**：大字母消失、列表停在该组；横向滑出轨道仍按纵向位置
///   连续定位（ gesture 状态保留，手指不脱靶）。
class LetterRail extends StatefulWidget {
  const LetterRail({
    required this.letters,
    required this.onPick,
    this.onEnd,
    super.key,
  });

  final List<String> letters;
  final ValueChanged<String> onPick;
  final VoidCallback? onEnd;

  @override
  State<LetterRail> createState() => _LetterRailState();
}

class _LetterRailState extends State<LetterRail> {
  int _active = -1;
  bool _pressed = false;

  void _locate(Offset local, {bool force = false}) {
    if (widget.letters.isEmpty) {
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final y = local.dy.clamp(0.0, box.size.height - 1);
    final i = (y / box.size.height * widget.letters.length).floor().clamp(
      0,
      widget.letters.length - 1,
    );
    if (force || i != _active) {
      if (i != _active) {
        HapticFeedback.selectionClick(); // 越过一个字母 = 一次刻度振动
      }
      setState(() => _active = i);
      widget.onPick(widget.letters[i]);
    }
  }

  void _press(Offset local) {
    if (!_pressed) {
      _pressed = true;
      _active = -1; // 新一次按压：即使落在同一字母也要跳一次
    }
    _locate(local, force: true);
  }

  void _finish() {
    if (!_pressed) {
      return;
    }
    _pressed = false;
    if (_active != -1) {
      HapticFeedback.lightImpact(); // 松手确认
      setState(() => _active = -1);
    }
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<IaPalette>()!.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 按下 / 拖动共用一套定位逻辑：触点在哪组，列表就在哪组
      onVerticalDragDown: (d) => _press(d.localPosition),
      onVerticalDragUpdate: (d) => _locate(d.localPosition),
      onVerticalDragEnd: (_) => _finish(),
      onVerticalDragCancel: _finish,
      onTapDown: (d) => _press(d.localPosition),
      onTapUp: (_) => _finish(),
      onTapCancel: _finish,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.letters.length; i++)
            SizedBox(
              height: 16,
              child: Center(
                child: Text(
                  widget.letters[i],
                  style: TextStyle(
                    fontSize: i == _active ? 13 : IaSpacing.railLetter,
                    fontWeight: i == _active ? IaType.semibold : IaType.regular,
                    color: i == _active ? accent : IaColors.textMid,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
