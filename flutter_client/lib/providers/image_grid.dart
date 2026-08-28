import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _showNamesKey = 'image_grid_show_names';
const _columnsKey = 'image_grid_columns';

const imageGridMinColumns = 2;
const imageGridMaxColumns = 6;
const imageGridDefaultColumns = 3;

class ImageGridSettings {
  const ImageGridSettings({
    required this.showNames,
    required this.columns,
  });

  static const defaults = ImageGridSettings(
    showNames: false,
    columns: imageGridDefaultColumns,
  );

  final bool showNames;
  final int columns;

  ImageGridSettings copyWith({bool? showNames, int? columns}) {
    return ImageGridSettings(
      showNames: showNames ?? this.showNames,
      columns: columns ?? this.columns,
    );
  }
}

final imageGridProvider =
    NotifierProvider<ImageGridNotifier, ImageGridSettings>(ImageGridNotifier.new);

class ImageGridNotifier extends Notifier<ImageGridSettings> {
  @override
  ImageGridSettings build() {
    Future.microtask(_restore);
    return ImageGridSettings.defaults;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final columns = (prefs.getInt(_columnsKey) ?? imageGridDefaultColumns)
        .clamp(imageGridMinColumns, imageGridMaxColumns);
    state = ImageGridSettings(
      showNames: prefs.getBool(_showNamesKey) ?? false,
      columns: columns,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNamesKey, state.showNames);
    await prefs.setInt(_columnsKey, state.columns);
  }

  Future<void> setShowNames(bool value) async {
    state = state.copyWith(showNames: value);
    await _persist();
  }

  Future<void> setColumns(int value) async {
    state = state.copyWith(
      columns: value.clamp(imageGridMinColumns, imageGridMaxColumns),
    );
    await _persist();
  }
}
