import 'package:flutter/material.dart';
import '../theme/ardent_colors.dart';

/// A branded loading widget featuring the Ardent Hub red circular spinner
/// or an animated pulsing Ardent Hub emblem.
class ArdentLoading extends StatefulWidget {
  const ArdentLoading({
    super.key,
    this.size = 36.0,
    this.showLogo = false,
    this.message,
  });

  final double size;
  final bool showLogo;
  final String? message;

  @override
  State<ArdentLoading> createState() => _ArdentLoadingState();
}

class _ArdentLoadingState extends State<ArdentLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showLogo) {
      return Center(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(ArdentColors.brandCrimson),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: widget.size + 24,
                  height: widget.size + 24,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(ArdentColors.brandCrimson),
                  ),
                ),
                Image.asset(
                  'assets/images/ardent_hub_symbol.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      color: ArdentColors.brandCrimson,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ArdentColors.fg2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen loading screen used during cold boot / session bootstrap.
class ArdentSplashScreen extends StatelessWidget {
  const ArdentSplashScreen({super.key, this.message = 'Loading Ardent Hub...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ardent_hub_logo.png',
              width: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'Ardent Hub',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: ArdentColors.brandCrimson,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(ArdentColors.brandCrimson),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
