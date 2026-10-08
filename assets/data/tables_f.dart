// lib/data/tables_f.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/table_f_entree.dart'; // Importe ton modèle d'entrée Table F

class TablesF {
  final List<TableFEntree> _entries;

  TablesF._internal(this._entries);

  factory TablesF.empty() {
    return TablesF._internal([]);
  }

  // Construit dynamiquement le chemin du fichier selon le type de tir et le canal.
  static String getAssetPath({
    required String typeTir, // "Appui", "Appui_RTC", "OECL"
    required int canal, // 1 à 6
  }) {
    String suffix = 'CH$canal';
    switch (typeTir) {
      case 'Appui':
        return 'assets/data/Tableau B_Appui_$suffix.json';
      case 'Appui_RTC':
        return 'assets/data/Tableau B_Appui_RTC_$suffix.json';
      case 'OECL':
        return 'assets/data/Tableau B_OECL_$suffix.json';
      default:
        throw Exception('Type de tir inconnu : $typeTir');
    }
  }

  Future<void> loadFromAsset(String path) async {
    try {
      final String response = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(response);
      _entries.clear();
      _entries.addAll(data.map((e) => TableFEntree.fromJson(e)).toList());
      print('Table F chargée avec ${_entries.length} entrées depuis $path.');
    } catch (e) {
      print('Erreur de chargement de Table F depuis $path: $e');
      rethrow;
    }
  }

  double getCorrectionForDistance(double distance) {
    if (_entries.isEmpty) {
      print('Table F non chargée ou vide, retour de dérive 0.');
      return 0.0;
    }

    if (distance <= _entries.first.distance) {
      return _entries.first.derive;
    } else if (distance >= _entries.last.distance) {
      return _entries.last.derive;
    } else {
      for (int i = 0; i < _entries.length - 1; i++) {
        final e1 = _entries[i];
        final e2 = _entries[i + 1];
        if (distance >= e1.distance && distance <= e2.distance) {
          return e1.derive +
              (distance - e1.distance) *
                  (e2.derive - e1.derive) /
                  (e2.distance - e1.distance);
        }
      }
    }
    return 0.0;
  }
}
