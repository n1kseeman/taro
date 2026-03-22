import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppItemImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final IconData placeholderIcon;
  final double placeholderIconSize;
  final Color? placeholderColor;
  final FilterQuality filterQuality;

  const AppItemImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.placeholderIcon = Icons.local_cafe,
    this.placeholderIconSize = 44,
    this.placeholderColor,
    this.filterQuality = FilterQuality.medium,
  });

  static final Map<String, Uint8List> _dataCache = {};
  static final Map<String, ImageProvider<Object>> _providerCache = {};

  @override
  Widget build(BuildContext context) {
    final value = imageUrl.trim();
    final provider = _resolveImageProvider(value);
    final fallbackColor =
        placeholderColor ?? Colors.black.withValues(alpha: 0.08);

    Widget child;
    if (provider == null) {
      child = _placeholder(fallbackColor);
    } else {
      child = Image(
        image: provider,
        fit: fit,
        width: width,
        height: height,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _placeholder(fallbackColor),
      );
    }

    return RepaintBoundary(
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _placeholder(Color backgroundColor) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(child: Icon(placeholderIcon, size: placeholderIconSize)),
    );
  }

  ImageProvider<Object>? _resolveImageProvider(String value) {
    if (value.isEmpty) return null;
    final cached = _providerCache[value];
    if (cached != null) return cached;

    try {
      final data = _decodeDataImage(value);
      final provider = data != null
          ? MemoryImage(data)
          : NetworkImage(value) as ImageProvider<Object>;
      _providerCache[value] = provider;
      return provider;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeDataImage(String value) {
    if (!value.startsWith('data:image')) return null;
    final cached = _dataCache[value];
    if (cached != null) return cached;

    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return null;

    try {
      final data = base64Decode(value.substring(commaIndex + 1));
      _dataCache[value] = data;
      return data;
    } catch (_) {
      return null;
    }
  }
}
