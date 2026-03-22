import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

Future<void> main() async {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    stderr.writeln('HOME is not set');
    exitCode = 1;
    return;
  }

  final hiveDir = Directory(
    '$home/Library/Containers/com.example.taro/Data/Documents',
  );
  if (!hiveDir.existsSync()) {
    stderr.writeln('Hive directory not found: ${hiveDir.path}');
    exitCode = 1;
    return;
  }

  Hive.init(hiveDir.path);
  final box = await Hive.openBox('tm_box');

  final rawOverrides = (box.get('cafeMenuOverrides') ?? '{}') as String;
  final rawGlobalAddons = (box.get('globalAddons') ?? '[]') as String;
  final rawDefaultMenu = box.get('defaultMenu') as String?;

  final overrides = Map<String, dynamic>.from(jsonDecode(rawOverrides));
  final menu = (overrides['tapo'] as List?) ??
      (rawDefaultMenu == null ? const [] : (jsonDecode(rawDefaultMenu) as List));
  final globalAddons = jsonDecode(rawGlobalAddons) as List;

  final outFile = File('assets/menu_seed.json');
  const encoder = JsonEncoder.withIndent('  ');
  final payload = {
    'menu': menu,
    'globalAddons': globalAddons,
  };
  await outFile.writeAsString('${encoder.convert(payload)}\n');

  stdout.writeln(
    'Exported ${(menu).length} menu items and ${globalAddons.length} global addons to ${outFile.path}',
  );

  await box.close();
}
