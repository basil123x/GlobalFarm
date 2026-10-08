import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';

class CoachTutorialStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  /// Used when [targetKey] is null (e.g. swipe area).
  final Rect Function(Size screenSize)? fallbackRect;
  /// Pulsing swipe-up arrow (TikTok-style browse hint).
  final bool showSwipeHint;

  const CoachTutorialStep({
    this.targetKey,
    required this.title,
    required this.description,
    this.fallbackRect,
    this.showSwipeHint = false,
  });
}

/// Dark overlay with a circular spotlight around UI targets, step by step.
class AppCoachTutorial extends StatefulWidget {
  final List<CoachTutorialStep> steps;
  final VoidCallback onFinish;
  final VoidCallback? onSkip;
  final bool isArabic;

  const AppCoachTutorial({
    super.key,
    required this.steps,
    required this.onFinish,
    this.onSkip,
    this.isArabic = true,
  });

  @override
  State<AppCoachTutorial> createState() => _AppCoachTutorialState();
}

class _AppCoachTutorialState extends State<AppCoachTutorial>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _swipeAnimController;
  late final Animation<double> _swipeOffset;
  late final Animation<double> _swipeOpacity;

  CoachTutorialStep get _step => widget.steps[_index];

  bool get _isLast => _index >= widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _swipeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 18, end: -10), weight: 70),
      TweenSequenceItem(tween: Tween(begin: -10, end: 18), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _swipeAnimController, curve: Curves.easeInOut),
    );
    _swipeOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.2), weight: 35),
    ]).animate(_swipeAnimController);

    _syncSwipeAnimation();
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    super.dispose();
  }

  void _syncSwipeAnimation() {
    if (_step.showSwipeHint) {
      if (!_swipeAnimController.isAnimating) {
        _swipeAnimController.repeat();
      }
    } else {
      _swipeAnimController.stop();
      _swipeAnimController.reset();
    }
  }

  Rect? _resolveTargetRect(Size screenSize) {
    final key = _step.targetKey;
    if (key?.currentContext != null) {
      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.attached) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    }
    return _step.fallbackRect?.call(screenSize);
  }

  void _next() {
    if (_isLast) {
      widget.onFinish();
      return;
    }
    setState(() {
      _index++;
      _syncSwipeAnimation();
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _syncSwipeAnimation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    final screenSize = MediaQuery.sizeOf(context);
    final target = _resolveTargetRect(screenSize);

    final hole = target != null
        ? Rect.fromCenter(
            center: target.center,
            width: (target.width + 28).clamp(56.0, _step.showSwipeHint ? 160.0 : 140.0),
            height: (target.height + 28).clamp(
              56.0,
              _step.showSwipeHint ? 160.0 : 140.0,
            ),
          )
        : Rect.fromCenter(
            center: Offset(screenSize.width / 2, screenSize.height * 0.42),
            width: _step.showSwipeHint ? 150 : 120,
            height: _step.showSwipeHint ? 150 : 120,
          );

    final tooltipAbove = hole.center.dy > screenSize.height * 0.45;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(hole: hole),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
              ),
            ),
          ),
          Positioned(
            left: hole.left - 4,
            top: hole.top - 4,
            width: hole.width + 8,
            height: hole.height + 8,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.55),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_step.showSwipeHint)
            Positioned(
              left: hole.left,
              top: hole.top,
              width: hole.width,
              height: hole.height,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _swipeAnimController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _swipeOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _swipeOffset.value),
                        child: child,
                      ),
                    );
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.arrow_up_3,
                        color: Colors.white,
                        size: 42,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Icon(
                        Iconsax.arrow_up_2,
                        color: Colors.white70,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            top: tooltipAbove ? null : hole.bottom + 24,
            bottom: tooltipAbove
                ? (screenSize.height - hole.top + 24)
                : null,
            child: _buildTooltipCard(ar),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(bool ar) {
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_index + 1} / ${widget.steps.length}',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _step.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _step.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onSkip ?? widget.onFinish,
                  child: Text(
                    ar ? 'تخطي' : 'Skip',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Spacer(),
                if (_index > 0)
                  TextButton(
                    onPressed: _back,
                    child: Text(ar ? 'رجوع' : 'Back'),
                  ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLast
                        ? (ar ? 'تم' : 'Done')
                        : (ar ? 'التالي' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;

  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addOval(
        Rect.fromCenter(
          center: hole.center,
          width: hole.width,
          height: hole.height,
        ),
      );
    final path = Path.combine(PathOperation.difference, overlay, cutout);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
