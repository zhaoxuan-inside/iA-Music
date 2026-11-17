/// WP8 招牌动效组件库——Windows Phone 8 默认音乐播放器（Music+Videos Hub /
/// Xbox Music）的四个标志性动画的 Flutter 实现：
///
/// * [FeatherIn]   —— Turnstile Feather：列表条目绕纵轴依次翻入（Silverlight
///   Toolkit `TurnstileFeatherEffect`：`PlaneProjection.RotationY` + 每条递增
///   BeginTime 错峰）。WP8 pivot/panorama 页进入时的「逐条翻开」。
/// * [HubTileFlip] —— Live Tile Flip：磁贴周期性绕纵轴 3D 翻面（Music+Videos
///   Hub 马赛克磁贴的灵魂；WP8 主屏 Flip 模板）。翻面时钟由 [tileFlipTickProvider]
///   全局供给，生产入口开启、测试环境静默。
/// * [MarqueeText] —— 走马灯：长标题单行溢出时匀速横滚，首尾停顿循环
///   （WP 音乐播放页/迷你条处理长歌名的方式）。
/// * [TiltOnPress] —— Tilt：按压轻微缩放（Silverlight Toolkit tilt 效果；
///   纯黑画布上 InkWell 无水波纹，没有它按钮就是死的）。
///
/// 克制原则：全部一次性/周期性动效都收敛在 IaMotion 令牌；入场动效只在
/// 首次构建时播（长列表滚动不重播）；翻面相位按磁贴错开，永不同步。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';

/* ── Turnstile Feather ────────────────────────────────────────────── */

/// Turnstile Feather 入场：按 [index] 错峰绕纵轴翻入 + 淡入，一次性播放。
///
/// 超出 [IaMotion.featherMaxItems] 的条目不再动画（直接显示）——WP8 的羽毛
/// 效果只发生在进页一瞬，长列表滚动出新行时不再翻动。
class FeatherIn extends StatefulWidget {
  const FeatherIn({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<FeatherIn> createState() => _FeatherInState();
}

class _FeatherInState extends State<FeatherIn>
    with SingleTickerProviderStateMixin {
  /// 参与错峰的槽位（上限截断）。
  late final int _slot = math.min(widget.index, IaMotion.featherMaxItems);
  late final bool _animate = widget.index <= IaMotion.featherMaxItems;

  // 错峰延迟并入动画时长（Interval 曲线实现"前段静止"）——不用 Timer：
  // widget 测试里挂起定时器会判失败，控制器则天然干净。
  late final Duration _total = IaMotion.feather + IaMotion.featherStep * _slot;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _total.inMicroseconds > 0
          ? (IaMotion.featherStep * _slot).inMicroseconds /
                _total.inMicroseconds
          : 0,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (_animate) {
      _c.forward(); // 下一帧自然起跑，无需定时器
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        final v = _a.value;
        if (v >= 0.999) {
          return child!; // 落定后不再变换（零开销）
        }
        final angle = (1 - v) * IaMotion.featherAngle * math.pi / 180;
        return Opacity(
          opacity: v,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/* ── Live Tile Flip ───────────────────────────────────────────────── */

/// 磁贴翻面全局时钟。生产入口（main）置 [tileFlipsEnabled] = true 后才会
/// 产生定时器；测试/纯布局环境保持 false——磁贴只显示正面，无挂起定时器。
bool tileFlipsEnabled = false;

/// 磁贴翻面节拍流（每 [IaMotion.tileTick] 一拍，值为拍号）。
final tileFlipTickProvider = StreamProvider<int>((ref) {
  if (!tileFlipsEnabled) {
    return const Stream<int>.empty();
  }
  final ctrl = StreamController<int>.broadcast();
  var tick = 0;
  final timer = Timer.periodic(IaMotion.tileTick, (_) => ctrl.add(tick++));
  ref.onDispose(() {
    timer.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});

/// Live Tile Flip：正面 [front] 与背面 [back] 绕纵轴周期性 3D 翻面。
///
/// 翻面节拍来自全局时钟；[phaseSeed] 决定这块磁贴的翻面周期与相位——
/// 多块磁贴各自错峰翻面，绝不同步（WP8 马赛克磁贴的呼吸感）。
class HubTileFlip extends ConsumerStatefulWidget {
  const HubTileFlip({
    required this.front,
    required this.back,
    this.phaseSeed = 0,
    super.key,
  });

  final Widget front;
  final Widget back;
  final int phaseSeed;

  @override
  ConsumerState<HubTileFlip> createState() => _HubTileFlipState();
}

class _HubTileFlipState extends ConsumerState<HubTileFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IaMotion.tileFlip,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );

  /// 翻面周期（拍数）：3～5 拍一次，按种子确定性取值。
  late final int _period = 3 + (widget.phaseSeed.abs() % 3);

  /// 相位：本磁贴落在哪一拍。
  late final int _phase = widget.phaseSeed.abs() % _period;

  bool _showBack = false;
  bool _flipping = false;

  @override
  void initState() {
    super.initState();
    // listenManual：不随 build 重挂订阅。
    ref.listenManual(tileFlipTickProvider, (_, tick) {
      final t = tick.value;
      if (t != null && !_flipping && t % _period == _phase) {
        _flip();
      }
    });
  }

  void _flip() {
    if (!mounted) {
      return;
    }
    _flipping = true;
    setState(() => _showBack = !_showBack);
    _c.forward(from: 0).whenComplete(() {
      _flipping = false;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        final t = _a.value;
        if (t <= 0 || t >= 1) {
          return child!; // 静止面：正面或背面
        }
        // 0→180°，翻过 90° 换面；背面按 (angle−180°) 补偿，永远无镜像。
        final angle = t * math.pi;
        final back = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(back ? angle - math.pi : angle),
          child: back ? widget.back : widget.front,
        );
      },
      child: _showBack ? widget.back : widget.front,
    );
  }
}

/* ── 走马灯 ───────────────────────────────────────────────────────── */

/// WP8 音乐播放器的长文本走马灯：单行溢出时按 [IaMotion.marqueeSpeed] 匀速
/// 横滚，起始停顿 [IaMotion.marqueeLead]、回卷前停顿 [IaMotion.marqueeHold]；
/// 不溢出时与普通 Text 无异。
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final TextPainter _tp = TextPainter(
    text: TextSpan(text: widget.text, style: widget.style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  double _overflow = 0;
  double _lineHeight = 0;
  Object? _lastKey;

  // 单控制器跑完整循环：lead（看清原文）→ 匀速横滚 → hold（喘口气回卷）。
  // 三段用 Interval 分段映射，无需任何定时器；completed 后自动重跑。
  static const Duration _lead = IaMotion.marqueeLead;
  Duration _scroll = Duration.zero;

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) {
      _lastKey = null; // 下一帧重测重排
    }
  }

  /// 量宽并决定是否滚动（文本或视口变化时调用一次）。
  void _setup(double maxWidth) {
    _tp
      ..text = TextSpan(text: widget.text, style: widget.style)
      ..layout();
    final w = _tp.width;
    _lineHeight = _tp.height;
    if (w <= maxWidth) {
      _overflow = 0;
      _c.stop();
      return;
    }
    _overflow = w - maxWidth + IaSpacing.xl; // 尾部留一段空档再回卷
    _scroll = Duration(
      milliseconds: ((_overflow / IaMotion.marqueeSpeed) * 1000).round().clamp(
        1200,
        16000,
      ),
    );
    if (!_loopHooked) {
      _loopHooked = true;
      _c.addStatusListener((st) {
        if (st == AnimationStatus.completed) {
          _c.forward(from: 0); // 循环
        }
      });
    }
    _c
      ..duration = _lead + _scroll + IaMotion.marqueeHold
      ..forward(from: 0);
  }

  bool _loopHooked = false;

  /// 当前位移比例（0→1）：lead 段停 0，scroll 段线性推进，hold 段停在 1。
  double _shift(double t) {
    final cycle = _c.duration!.inMicroseconds;
    final leadF = _lead.inMicroseconds / cycle;
    final endF = (_lead.inMicroseconds + _scroll.inMicroseconds) / cycle;
    if (t <= leadF) {
      return 0;
    }
    if (t >= endF) {
      return 1;
    }
    return (t - leadF) / (endF - leadF);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final key = Object.hash(widget.text, widget.style, box.maxWidth);
        if (key != _lastKey) {
          _lastKey = key;
          _setup(box.maxWidth);
        }
        if (_overflow <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        return ClipRect(
          child: SizedBox(
            height: _lineHeight,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, child) => Transform.translate(
                  offset: Offset(-_shift(_c.value) * _overflow, 0),
                  child: child,
                ),
                child: Text(widget.text, maxLines: 1, style: widget.style),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ── Tilt ─────────────────────────────────────────────────────────── */

/// WP8 Toolkit「Tilt」按压反馈：按下轻微缩放 [IaMotion.tiltScale]，抬起回弹。
/// 监听原始指针事件（不进手势竞技场），不影响 InkWell 的点击语义。
class TiltOnPress extends StatefulWidget {
  const TiltOnPress({required this.child, super.key});

  final Widget child;

  @override
  State<TiltOnPress> createState() => _TiltOnPressState();
}

class _TiltOnPressState extends State<TiltOnPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IaMotion.tilt,
    value: 1,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _c.reverse(),
      onPointerUp: (_) => _c.forward(),
      onPointerCancel: (_) => _c.forward(),
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Transform.scale(
          scale: IaMotion.tiltScale + (1 - IaMotion.tiltScale) * _a.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
