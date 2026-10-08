import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';

/// Bag icon → expands into − qty + stepper. Collapses back at qty 0.
class AnimatedCartButton extends StatefulWidget {
  final int quantity;
  final int stockQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool enabled;

  const AnimatedCartButton({
    super.key,
    required this.quantity,
    required this.stockQuantity,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  @override
  State<AnimatedCartButton> createState() => _AnimatedCartButtonState();
}

class _AnimatedCartButtonState extends State<AnimatedCartButton>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  bool get _showCounter => widget.quantity > 0;
  bool get _atMax =>
      widget.stockQuantity > 0 && widget.quantity >= widget.stockQuantity;
  bool get _outOfStock => widget.stockQuantity <= 0 && widget.quantity <= 0;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.18), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 40),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && widget.quantity > 0) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onBagTap() async {
    if (!widget.enabled || _outOfStock || _atMax) return;
    await _bounceController.forward(from: 0);
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    if (_outOfStock) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Iconsax.bag_cross,
          size: 18,
          color: Colors.grey.shade600,
        ),
      );
    }

    return GestureDetector(
      onTap: () {}, // absorb card taps
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        height: 40,
        width: _showCounter ? 108 : 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _showCounter
                ? const [AppColors.primary, AppColors.primaryDark]
                : const [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_showCounter ? 20 : 14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: _showCounter ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_showCounter ? 20 : 14),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.25, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(scale: animation, child: child),
                ),
              );
            },
            child: _showCounter
                ? _buildStepper(key: const ValueKey('stepper'))
                : _buildBag(key: const ValueKey('bag')),
          ),
        ),
      ),
    );
  }

  Widget _buildBag({required Key key}) {
    return KeyedSubtree(
      key: key,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBagTap,
          borderRadius: BorderRadius.circular(14),
          child: ScaleTransition(
            scale: _bounceScale,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Iconsax.bag_2, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper({required Key key}) {
    return KeyedSubtree(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _stepBtn(
              icon: Iconsax.minus,
              onTap: widget.enabled ? widget.onRemove : null,
            ),
            Expanded(
              child: Center(
                child: ScaleTransition(
                  scale: _pulseScale,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      '${widget.quantity}',
                      key: ValueKey(widget.quantity),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _stepBtn(
              icon: Iconsax.add,
              onTap: (!widget.enabled || _atMax) ? null : widget.onAdd,
              dimmed: _atMax,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required VoidCallback? onTap,
    bool dimmed = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 34,
          height: 40,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: dimmed ? 0.4 : 1),
            size: 16,
          ),
        ),
      ),
    );
  }
}
