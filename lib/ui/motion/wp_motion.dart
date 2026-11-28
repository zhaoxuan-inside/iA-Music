/// WP8 招牌动效组件库——Windows Phone 8 默认音乐播放器（Music+Videos Hub /
/// Xbox Music）的三个标志性动画的 Flutter 实现：
///
/// * [FeatherIn]   —— Turnstile Feather：列表条目绕纵轴依次翻入（Silverlight
///   Toolkit `TurnstileFeatherEffect`：`PlaneProjection.RotationY` + 每条递增
///   BeginTime 错峰）。WP8 pivot/panorama 页进入时的「逐条翻开」。
/// * [MarqueeText] —— 走马灯：长标题单行溢出时匀速横滚，首尾停顿循环
///   （WP 音乐播放页/迷你条处理长歌名的方式）。
/// * [FlipTile]    —— 活磁贴轮换：封面磁贴按周期绕纵轴翻面换出背面信息
///   （WP8 磁贴的「活」感；错峰 + 参与上限，常驻动画成本封顶）。
/// * [TiltOnPress] —— Tilt：按压轻微缩放（Silverlight Toolkit tilt 效果；
///   纯黑画布上 InkWell 无水波纹，没有它按钮就是死的）。
/// * [FlipTile]    —— 磁贴翻转：WP8 开始屏幕 live tile 的周期翻面，背面
///   露出次级信息（播放次数/歌名/歌手）后翻回。
///
/// 克制原则：全部一次性/周期性动效都收敛在 IaMotion 令牌；入场动效只在
/// 首次构建时播（长列表滚动不重播）；周期动效不挂 Timer（Interval 分段
/// 映射 + 控制器自循环），参与条目有上限。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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

/* ── 磁贴翻转 ─────────────────────────────────────────────────────── */

/// WP8 live tile 周期翻面：正面 [child] 在 [IaMotion.tileFlipLead] 后绕纵轴
/// 翻到背面 [back]，停留 [IaMotion.tileFlipHold] 再翻回，之后按
/// [IaMotion.tileFlipCycle] 循环。相邻磁贴按 [index] 错峰
/// [IaMotion.tileFlipStagger]，避免整屏齐翻；超出 [IaMotion.tileFlipMaxItems]
/// 的磁贴不参与（恒为正面，常驻动画成本封顶）。
///
/// 两面必须能吃满同一盒子（调用方用 AspectRatio/定宽约束定型；正面遮罩与
/// 背面信息各画各的）。停留段直接返回原 child（零变换零重建），只有 620ms
/// 翻转窗口里有 Transform——周期驱动用单控制器 Interval 分段（MarqueeText
/// 同款），不挂 Timer，widget 测试天然干净。
class FlipTile extends StatefulWidget {
  const FlipTile({
    required this.index,
    required this.back,
    required this.child,
    super.key,
  });

  /// 错峰与参与上限的槽位。
  final int index;

  /// 正面（常态显示的内容）。
  final Widget child;

  /// 背面（翻出时露出的次级信息）。
  final Widget back;

  @override
  State<FlipTile> createState() => _FlipTileState();
}

class _FlipTileState extends State<FlipTile> with SingleTickerProviderStateMixin {
  late final bool _animate = widget.index < IaMotion.tileFlipMaxItems;
  late final int _slot = math.min(widget.index, IaMotion.tileFlipMaxItems - 1);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IaMotion.tileFlipCycle,
  )..addStatusListener((st) {
      if (st == AnimationStatus.completed) _c.forward(from: 0); // 循环
    });

  /// 翻出窗口在周期内的起点（比例）：进页先停 [IaMotion.tileFlipLead]，
  /// 再按槽位错峰；封顶保证翻回之后仍有正面停留。
  late final double _start = math.min(
    (IaMotion.tileFlipLead + IaMotion.tileFlipStagger * _slot).inMicroseconds /
        IaMotion.tileFlipCycle.inMicroseconds,
    1 - 2 * _flipF - _holdF,
  );

  late final double _flipF =
      IaMotion.tileFlip.inMicroseconds / IaMotion.tileFlipCycle.inMicroseconds;
  late final double _holdF = IaMotion.tileFlipHold.inMicroseconds /
      IaMotion.tileFlipCycle.inMicroseconds;

  /// 相位：0=正面 · (0,1)=翻转进度（0 正面起翻，1 翻到背面）· 1=背面停留。
  double _phase(double t) {
    final s = _start, f = _flipF, h = _holdF;
    if (t < s) return 0;
    if (t < s + f) return (t - s) / f; // 翻出
    if (t < s + f + h) return 1;
    if (t < s + f + h + f) return 1 - (t - s - f - h) / f; // 翻回
    return 0;
  }

  @override
  void initState() {
    super.initState();
    if (_animate) _c.forward();
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
      animation: _c,
      builder: (context, front) {
        final p = _phase(_c.value);
        if (p <= 0) return front!; // 正面停留：零开销
        if (p >= 1) return widget.back; // 背面停留：零开销
        // 翻转窗口：前半程正面转离（90° 消失），后半程背面从 90° 转正。
        final angle = p * math.pi;
        const mid = math.pi / 2;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (angle < mid)
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(angle),
                child: front,
              )
            else
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(angle - math.pi),
                child: widget.back,
              ),
          ],
        );
      },
      child: widget.child,
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
