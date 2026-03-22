import 'dart:async';

import 'package:flutter/material.dart';

void showAppNotice(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final mediaPadding = MediaQuery.of(context).padding;
  late final OverlayEntry entry;

  void removeEntry() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (context) => _AppNoticeOverlay(
      message: message,
      isError: isError,
      duration: duration,
      topOffset: mediaPadding.top + 10,
      maxWidth: 560,
      backgroundColor: isError
          ? const Color(0xFFD85C5C)
          : scheme.surfaceContainerHighest,
      foregroundColor: isError ? Colors.white : scheme.onSurface,
      borderColor: isError
          ? Colors.white.withValues(alpha: 0.18)
          : scheme.outlineVariant.withValues(alpha: 0.24),
      textStyle: theme.textTheme.bodyMedium?.copyWith(
        color: isError ? Colors.white : scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      onClosed: removeEntry,
    ),
  );

  overlay.insert(entry);
}

class _AppNoticeOverlay extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final double topOffset;
  final double maxWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final TextStyle? textStyle;
  final VoidCallback onClosed;

  const _AppNoticeOverlay({
    required this.message,
    required this.isError,
    required this.duration,
    required this.topOffset,
    required this.maxWidth,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.textStyle,
    required this.onClosed,
  });

  @override
  State<_AppNoticeOverlay> createState() => _AppNoticeOverlayState();
}

class _AppNoticeOverlayState extends State<_AppNoticeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topOffset,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: Dismissible(
                key: ValueKey(
                  '${widget.message}-${DateTime.now().microsecondsSinceEpoch}',
                ),
                direction: DismissDirection.up,
                resizeDuration: null,
                onDismissed: (_) => _dismiss(),
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: widget.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.isError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            color: widget.foregroundColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: widget.textStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
