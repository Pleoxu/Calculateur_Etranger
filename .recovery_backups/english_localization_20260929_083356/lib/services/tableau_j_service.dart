// lib/services/tableau_j_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class TableauJService {
  final String _typeTir;
  Map<String, dynamic>? _data;
  bool _isLoaded = false;

  TableauJService({required String typeTir}) : _typeTir = typeTir;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final path = 'assets/tableaux/Tableau_J_$_typeTir.json';
      final raw = await rootBundle.loadString(path);
      _data = json.decode(raw);
      _isLoaded = true;
    } catch (e) {
      debugPrint('[TableauJService] Erreur de chargement: $e');
      _data = null;
    }
  }

  Future<double?> getCorrection(double tempage, String key) async {
    if (!_isLoaded || _data == null) {
      await load();
      if (_data == null) return null;
    }

    final List<dynamic> rows = _data!['rows'] ?? [];
    if (rows.isEmpty) return null;

    final closestRows = rows.where((r) => r['tempage'] is num).toList();
    closestRows.sort(
      (a, b) => (a['tempage'] as num).compareTo(b['tempage'] as num),
    );

    if (tempage <= closestRows.first['tempage']) {
      return (closestRows.first[key] as num?)?.toDouble();
    }
    if (tempage >= closestRows.last['tempage']) {
      return (closestRows.last[key] as num?)?.toDouble();
    }

    final r2 = closestRows.firstWhere((r) => r['tempage'] >= tempage);
    final r1 = closestRows.lastWhere((r) => r['tempage'] < tempage);

    final t = (tempage - (r1['tempage'] as num)) /
        ((r2['tempage'] as num) - (r1['tempage'] as num));
    final c1 = (r1[key] as num?)?.toDouble() ?? 0.0;
    final c2 = (r2[key] as num?)?.toDouble() ?? 0.0;

    return c1 + t * (c2 - c1);
  }
}
