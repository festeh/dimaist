import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/label.dart';

class LabelState {
  final List<Label> labels;
  final bool isLoading;

  const LabelState({required this.labels, this.isLoading = false});

  LabelState copyWith({List<Label>? labels, bool? isLoading}) {
    return LabelState(
      labels: labels ?? this.labels,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get label by name (case-insensitive)
  Label? getLabelByName(String name) {
    final lowerName = name.toLowerCase().trim();
    try {
      return labels.firstWhere((l) => l.name == lowerName);
    } catch (_) {
      return null;
    }
  }
}

class LabelNotifier extends Notifier<LabelState> {
  static const String _labelsKey = 'stored_labels';

  static final List<Label> _defaultLabels = [
    const Label(id: 'default_next', name: 'next', color: LabelColors.blue),
    const Label(
      id: 'default_calendar',
      name: 'calendar',
      color: LabelColors.green,
    ),
  ];

  SharedPreferences? _prefs;

  @override
  LabelState build() {
    _loadLabels();
    return const LabelState(labels: [], isLoading: true);
  }

  Future<void> _loadLabels() async {
    _prefs = await SharedPreferences.getInstance();
    final labelsJson = _prefs?.getString(_labelsKey);

    List<Label> labels = [];
    if (labelsJson != null && labelsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(labelsJson);
        labels = decoded.map((e) => Label.fromJson(e)).toList();
      } catch (_) {
        // Invalid JSON, use defaults
        labels = List.from(_defaultLabels);
      }
    } else {
      // No saved labels, use defaults
      labels = List.from(_defaultLabels);
    }

    state = LabelState(labels: labels, isLoading: false);
  }

  Future<void> _saveLabels() async {
    final json = jsonEncode(state.labels.map((l) => l.toJson()).toList());
    await _prefs?.setString(_labelsKey, json);
  }

  Future<void> addLabel(Label label) async {
    // Ensure name is unique (case-insensitive)
    final normalizedName = label.name.toLowerCase().trim();
    if (state.labels.any((l) => l.name == normalizedName)) {
      return; // Label already exists
    }

    final newLabel = label.copyWith(name: normalizedName);
    final newLabels = [...state.labels, newLabel];
    state = state.copyWith(labels: newLabels);
    await _saveLabels();
  }

  Future<void> updateLabel(Label label) async {
    // Ensure name is unique (case-insensitive), excluding the current label
    final normalizedName = label.name.toLowerCase().trim();
    if (state.labels.any((l) => l.name == normalizedName && l.id != label.id)) {
      return; // Another label with this name exists
    }

    final updatedLabel = label.copyWith(name: normalizedName);
    final newLabels = state.labels
        .map((l) => l.id == label.id ? updatedLabel : l)
        .toList();
    state = state.copyWith(labels: newLabels);
    await _saveLabels();
  }

  Future<void> deleteLabel(String labelId) async {
    final newLabels = state.labels.where((l) => l.id != labelId).toList();
    state = state.copyWith(labels: newLabels);
    await _saveLabels();
  }
}

final labelProvider = NotifierProvider<LabelNotifier, LabelState>(
  LabelNotifier.new,
);
