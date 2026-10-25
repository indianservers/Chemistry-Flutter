import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences extends ChangeNotifier {
  final SharedPreferencesAsync storage;
  WorkspacePreferences(this.storage);
  double glow = 1, textScale = 1;
  bool largeControls = false,
      reducedMotion = false,
      alternativeColors = false,
      patterns = false;
  bool periodicHints = true, moleculeHints = true;
  final Set<int> favoriteElements = {};
  final Set<String> favoriteMolecules = {};
  final List<int> recentElements = [];
  final List<String> recentMolecules = [];
  List<String> pinnedProperties = ['configuration', 'shell', 'position'];
  Map<String, dynamic> periodic = {};
  Map<String, dynamic> molecule = {};
  List<Map<String, dynamic>> cameras = [];
  Future<void> load() async {
    try {
      final raw = await storage.getString('workspace-v2');
      if (raw == null) {
        return;
      }
      final j = jsonDecode(raw) as Map<String, dynamic>;
      glow = (j['glow'] as num? ?? 1).toDouble().clamp(0, 1);
      textScale = (j['textScale'] as num? ?? 1).toDouble().clamp(1, 1.4);
      largeControls = j['largeControls'] == true;
      reducedMotion = j['reducedMotion'] == true;
      alternativeColors = j['alternativeColors'] == true;
      patterns = j['patterns'] == true;
      periodicHints = j['periodicHints'] != false;
      moleculeHints = j['moleculeHints'] != false;
      favoriteElements.addAll(
        (j['favoriteElements'] as List? ?? []).cast<int>(),
      );
      favoriteMolecules.addAll(
        (j['favoriteMolecules'] as List? ?? []).cast<String>(),
      );
      recentElements.addAll((j['recentElements'] as List? ?? []).cast<int>());
      recentMolecules.addAll(
        (j['recentMolecules'] as List? ?? []).cast<String>(),
      );
      pinnedProperties = (j['pinnedProperties'] as List? ?? pinnedProperties)
          .cast<String>();
      periodic = (j['periodic'] as Map?)?.cast<String, dynamic>() ?? {};
      molecule = (j['molecule'] as Map?)?.cast<String, dynamic>() ?? {};
      cameras = (j['cameras'] as List? ?? [])
          .map((v) => (v as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      /* Keep defaults if a preference record is damaged. */
    }
  }

  Future<void> persist({bool notify = true}) async {
    if (notify) {
      notifyListeners();
    }
    await storage.setString(
      'workspace-v2',
      jsonEncode({
        'glow': glow,
        'textScale': textScale,
        'largeControls': largeControls,
        'reducedMotion': reducedMotion,
        'alternativeColors': alternativeColors,
        'patterns': patterns,
        'periodicHints': periodicHints,
        'moleculeHints': moleculeHints,
        'favoriteElements': favoriteElements.toList(),
        'favoriteMolecules': favoriteMolecules.toList(),
        'recentElements': recentElements,
        'recentMolecules': recentMolecules,
        'pinnedProperties': pinnedProperties,
        'periodic': periodic,
        'molecule': molecule,
        'cameras': cameras,
      }),
    );
  }

  void visitElement(int n) {
    recentElements.remove(n);
    recentElements.insert(0, n);
    if (recentElements.length > 12) {
      recentElements.removeLast();
    }
    persist();
  }

  void visitMolecule(String id) {
    recentMolecules.remove(id);
    recentMolecules.insert(0, id);
    if (recentMolecules.length > 12) {
      recentMolecules.removeLast();
    }
    persist();
  }

  void favoriteElement(int n) {
    favoriteElements.contains(n)
        ? favoriteElements.remove(n)
        : favoriteElements.add(n);
    persist();
  }

  void favoriteMolecule(String id) {
    favoriteMolecules.contains(id)
        ? favoriteMolecules.remove(id)
        : favoriteMolecules.add(id);
    persist();
  }

  void setPeriodic(Map<String, dynamic> state) {
    periodic = Map.of(state);
    persist(notify: false);
  }
}
