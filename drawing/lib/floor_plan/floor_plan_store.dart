import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'floor_plan.dart';

/// Where a floor plan is loaded from and saved to.
abstract interface class FloorPlanRepository {
  Future<FloorPlan> load();

  /// Saves [plan] and returns where it was saved, for a confirmation message.
  Future<String> save(FloorPlan plan);
}

/// Loads and saves the plan as a JSON file.
///
/// An installed app can't change files bundled inside it, so by default:
///   * it saves to `main_floor.json` in the app's documents folder, and
///   * loads that saved copy if there is one, else the bundled asset.
///
/// While developing, point it at the project's own JSON file instead, so Save
/// updates the file you edit (this works on the simulator, not on a real
/// device):
///
///     flutter run --dart-define=FLOOR_PLAN_FILE=/absolute/path/main_floor.json
class JsonFileFloorPlanRepository implements FloorPlanRepository {
  const JsonFileFloorPlanRepository({
    this.assetPath = 'assets/floor_plans/main_floor.json',
    this.filePath = const String.fromEnvironment('FLOOR_PLAN_FILE'),
  });

  final String assetPath;

  /// The JSON file to load from and save to. Empty means "use the app's
  /// documents folder".
  final String filePath;

  Future<File> _file() async {
    if (filePath.isNotEmpty) return File(filePath);
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${assetPath.split('/').last}');
  }

  @override
  Future<FloorPlan> load() async {
    final file = await _file();
    final source = await file.exists()
        ? await file.readAsString()
        : await rootBundle.loadString(assetPath);
    return FloorPlan.parse(source);
  }

  @override
  Future<String> save(FloorPlan plan) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(plan.encode());
    return file.path;
  }
}
