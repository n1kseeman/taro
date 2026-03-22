import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/menu.dart';
import '../models/promo_code.dart';

class MenuSeedData {
  final List<MenuItem> menu;
  final List<MenuAddon> globalAddons;
  final List<PromoCode> promoCodes;

  const MenuSeedData({
    required this.menu,
    required this.globalAddons,
    this.promoCodes = const [],
  });

  Map<String, dynamic> toJson() => {
    'menu': menu.map((item) => item.toJson()).toList(),
    'globalAddons': globalAddons.map((addon) => addon.toJson()).toList(),
    'promoCodes': promoCodes.map((promo) => promo.toJson()).toList(),
  };

  static MenuSeedData fromJson(Map<String, dynamic> json) => MenuSeedData(
    menu: (json['menu'] as List? ?? [])
        .map((item) => MenuItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    globalAddons: (json['globalAddons'] as List? ?? [])
        .map((addon) => MenuAddon.fromJson(Map<String, dynamic>.from(addon)))
        .toList(),
    promoCodes: (json['promoCodes'] as List? ?? [])
        .map((promo) => PromoCode.fromJson(Map<String, dynamic>.from(promo)))
        .toList(),
  );
}

class MenuSeedService {
  static const assetPath = 'assets/menu_seed.json';

  static Future<MenuSeedData?> loadBundledSeed() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final seed = MenuSeedData.fromJson(json);
      if (seed.menu.isEmpty) return null;
      return seed;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> writeWorkspaceSeed(MenuSeedData data) async {
    final root = _findWorkspaceRoot();
    if (root == null) return null;

    final assetsDir = Directory('${root.path}/assets');
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }

    final file = File('${assetsDir.path}/menu_seed.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(data.toJson())}\n');
    return file;
  }

  static Directory? _findWorkspaceRoot() {
    var current = Directory.current.absolute;

    while (true) {
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) return current;

      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
  }
}
