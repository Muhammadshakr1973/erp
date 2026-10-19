import 'package:flutter/material.dart';

/// Gardi Company official brand logo widget
class GardiLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;

  const GardiLogo({
    super.key,
    this.height = 36,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/1.png',
      height: height,
      width: width,
      fit: fit,
    );
  }
}

/// Reusable AppBar leading widget displaying Gardi Logo with optional back button
class GardiAppBarLeading extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const GardiAppBarLeading({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (showBackButton) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BackButton(onPressed: onBack),
          const SizedBox(width: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: GardiLogo(height: 32),
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Center(
        child: GardiLogo(height: 36),
      ),
    );
  }
}
