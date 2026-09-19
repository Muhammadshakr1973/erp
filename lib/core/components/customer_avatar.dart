import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class CustomerAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const CustomerAvatar({
    super.key,
    required this.imageUrl,
    this.size = 54,
    this.borderRadius = 16,
    this.placeholderIcon = Icons.person,
    this.iconSize = 28,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  State<CustomerAvatar> createState() => _CustomerAvatarState();
}

class _CustomerAvatarState extends State<CustomerAvatar> {
  bool _useProxy = false;
  bool _hasFailed = false;

  @override
  void didUpdateWidget(covariant CustomerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _useProxy = false;
      _hasFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawUrl = widget.imageUrl?.trim();
    final bg = widget.backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.08);
    final fg = widget.iconColor ?? theme.colorScheme.primary;

    Widget buildPlaceholder() {
      return Container(
        width: widget.size,
        height: widget.size,
        color: bg,
        child: Center(
          child: Icon(
            widget.placeholderIcon,
            color: fg,
            size: widget.iconSize,
          ),
        ),
      );
    }

    if (rawUrl == null || rawUrl.isEmpty || _hasFailed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: buildPlaceholder(),
      );
    }

    final targetUrl = _useProxy
        ? Formatters.proxyImageUrl(rawUrl)
        : Formatters.directImageUrl(rawUrl);

    if (targetUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: buildPlaceholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: bg,
        child: Image.network(
          targetUrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (!_useProxy) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _useProxy = true;
                  });
                }
              });
              return buildPlaceholder();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasFailed) {
                setState(() {
                  _hasFailed = true;
                });
              }
            });
            return buildPlaceholder();
          },
        ),
      ),
    );
  }
}
