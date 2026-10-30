import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'floor_plan.dart';
import 'floor_plan_store.dart';

/// One floor map in the collection: its name, whether it can be edited, and
/// its plan.
class FloorMap {
  const FloorMap({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.plan,
  });

  final String id;
  final String name;

  /// A disabled map can only be viewed (step 3, Review), not edited.
  final bool enabled;

  final FloorPlan plan;

  int get tableCount => plan.tables.length;
  int get seatCount => plan.tables.fold(0, (sum, t) => sum + t.seats.length);

  FloorMap copyWith({String? name, bool? enabled, FloorPlan? plan}) => FloorMap(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    plan: plan ?? this.plan,
  );
}

/// Where the collection of floor maps is loaded from and saved to.
abstract interface class FloorMapLibrary {
  /// Every map, in order.
  Future<List<FloorMap>> load();

  /// Saves the list: each map's name and enabled flag, and their order.
  /// Plans are saved separately, with [savePlan].
  Future<void> saveList(List<FloorMap> maps);

  /// Saves one map's plan and returns where it was saved, for a confirmation
  /// message.
  Future<String> savePlan(String id, FloorPlan plan);

  /// Deletes one map's plan, once the map is gone from the list.
  Future<void> removePlan(String id);
}

/// Loads and saves one map's plan through a [FloorMapLibrary], for the
/// floor plan page.
class FloorMapPlanRepository implements FloorPlanRepository {
  const FloorMapPlanRepository(this.library, this.map);

  final FloorMapLibrary library;
  final FloorMap map;

  @override
  Future<FloorPlan> load() async => map.plan;

  @override
  Future<String> save(FloorPlan plan) => library.savePlan(map.id, plan);
}

/// Keeps the maps as JSON files in the app's documents folder:
///   * `floor_maps.json` lists them: `{"maps": [{"id", "name", "enabled"}]}`
///   * `<id>.json` holds each map's plan.
///
/// On the first run there's no list yet: it starts with one map, from the
/// `main_floor.json` saved by earlier versions of the app if there is one,
/// else from the bundled sample.
class JsonFileFloorMapLibrary implements FloorMapLibrary {
  const JsonFileFloorMapLibrary({
    this.assetPath = 'assets/floor_plans/main_floor.json',
  });

  /// The sample plan the first map starts from.
  final String assetPath;

  static const _firstId = 'main_floor';

  Future<Directory> _dir() => getApplicationDocumentsDirectory();

  Future<File> _listFile() async =>
      File('${(await _dir()).path}/floor_maps.json');

  Future<File> _planFile(String id) async =>
      File('${(await _dir()).path}/$id.json');

  @override
  Future<List<FloorMap>> load() async {
    final listFile = await _listFile();
    if (!await listFile.exists()) {
      final planFile = await _planFile(_firstId);
      final plan = FloorPlan.parse(
        await planFile.exists()
            ? await planFile.readAsString()
            : await rootBundle.loadString(assetPath),
      );
      final maps = [FloorMap(id: _firstId, name: plan.name, plan: plan)];
      await savePlan(_firstId, plan);
      await saveList(maps);
      return maps;
    }

    final json = jsonDecode(await listFile.readAsString());
    if (json is! Map<String, dynamic> || json['maps'] is! List) {
      throw const FormatException('floor_maps.json: expected {"maps": [...]}');
    }
    return [
      for (final entry in (json['maps'] as List).cast<Map<String, dynamic>>())
        FloorMap(
          id: entry['id'] as String,
          name: entry['name'] as String,
          enabled: entry['enabled'] as bool? ?? true,
          plan: FloorPlan.parse(
            await (await _planFile(entry['id'] as String)).readAsString(),
          ),
        ),
    ];
  }

  @override
  Future<void> saveList(List<FloorMap> maps) async {
    final file = await _listFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'maps': [
          for (final map in maps)
            {'id': map.id, 'name': map.name, 'enabled': map.enabled},
        ],
      }),
    );
  }

  @override
  Future<String> savePlan(String id, FloorPlan plan) async {
    final file = await _planFile(id);
    await file.parent.create(recursive: true);
    await file.writeAsString(plan.encode());
    return file.path;
  }

  @override
  Future<void> removePlan(String id) async {
    final file = await _planFile(id);
    if (await file.exists()) await file.delete();
  }
}
