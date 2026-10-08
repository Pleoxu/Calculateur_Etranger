// lib/services/report/message_pd_local_store.dart
//
// Restauration du stockage PDF local.
// Cette version reprend les donnees deja collectees dans MessagePdData.
// Aucun recalcul balistique n'est effectue ici.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:calculateur_etranger/domain/report/message_pd_data.dart';

class MessagePdLocalStore {
  const MessagePdLocalStore();

  Future<File> savePdf(
    MessagePdData data, {
    Uint8List? batteryMapPng,
    Uint8List? globalMapPng,
    Uint8List? impactMapPng,
    Uint8List? redMapPng,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${documents.path}/comptes_rendus');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final fileName = 'compte_rendu_${_stamp(now)}.pdf';
    final file = File('${reportsDir.path}/$fileName');

    final document = pw.Document();
    final pieceResults = _pieceResults(data);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
        header: (context) => _header(context, now),
        footer: (context) => _footer(context),
        build: (context) => <pw.Widget>[
          pw.Text(
            'COMPTE RENDU TECHNIQUE',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('1. CONFIGURATION'),
          _kv('Systeme', data.systeme),
          _kv('Fire type', data.typeTir),
          if (_hasText(data.munition)) _kv('Ammunition', data.munition!),
          _kv('Fusee', data.fusee),
          if (_hasText(data.chargeOperateur))
            _kv('Operator charge', data.chargeOperateur!),
          if (_hasText(data.masse)) _kv('Mass', data.masse!),
          if (_hasText(data.tirSimilaire))
            _kv('Similar fire', data.tirSimilaire!),
          if (_hasText(data.meteo)) _kv('Meteo', data.meteo!),
          pw.SizedBox(height: 10),
          _sectionTitle('2. POSITIONS'),
          if (_hasText(data.piecePosition))
            _kv('Piece directrice', data.piecePosition!),
          if (_hasText(data.objectifPosition))
            _kv('Target', data.objectifPosition!),
          pw.SizedBox(height: 10),
          _sectionTitle('3. MAIN CALCULATION ELEMENTS'),
          if (_hasText(data.distance)) _kv('Distance', data.distance!),
          if (_hasText(data.azimut)) _kv('Azimuth', data.azimut!),
          if (_hasText(data.denivelee)) _kv('Denivelee', data.denivelee!),
          pw.SizedBox(height: 10),
          _sectionTitle('4. LAST CALCULATION RESULTS'),
          if (_hasText(data.noire)) _kv('Firing bearing', data.noire!),
          if (_hasText(data.aqe)) _kv('AQE', data.aqe!),
          if (_hasText(data.charge)) _kv('Charge', data.charge!),
          if (_hasText(data.temps)) _kv('Time of flight', data.temps!),
          if (pieceResults.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('5. RESULTS BY TARGET / OFFSET'),
            ...pieceResults.map(_pieceResultBlock),
          ],
          if (batteryMapPng != null ||
              globalMapPng != null ||
              impactMapPng != null ||
              redMapPng != null) ...[
            pw.SizedBox(height: 14),
            _sectionTitle(
              pieceResults.isNotEmpty
                  ? '6. EXTRAITS CARTOGRAPHIQUES'
                  : '5. EXTRAITS CARTOGRAPHIQUES',
            ),
            if (batteryMapPng != null)
              _mapBlock(
                'Implantation batterie / piece directrice',
                batteryMapPng,
              ),
            if (globalMapPng != null)
              _mapBlock('General PD-to-target map', globalMapPng),
            if (impactMapPng != null) _mapBlock('Impact area', impactMapPng),
            if (redMapPng != null) _mapBlock('Impact area + RED', redMapPng),
          ],
        ],
      ),
    );

    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  List<_PdfPieceResult> _pieceResults(MessagePdData data) {
    try {
      final dynamic rawData = data;
      final dynamic rawList = rawData.pieceResults;
      if (rawList is! Iterable) return const <_PdfPieceResult>[];

      final out = <_PdfPieceResult>[];
      for (final dynamic item in rawList) {
        try {
          final label = (item.label ?? '').toString().trim();
          if (label.isEmpty) continue;
          out.add(
            _PdfPieceResult(
              pieceLabel: label,
              objectiveLabel: _objectiveLabel(label),
              offsetM: _asDouble(item.offsetM),
              noire: _asText(item.noire),
              aqe: _asText(item.aqe),
              charge: _asText(item.charge),
              temps: _asText(item.temps),
            ),
          );
        } catch (_) {}
      }

      out.sort((a, b) {
        if (a.pieceLabel.toUpperCase() == 'PD') return -1;
        if (b.pieceLabel.toUpperCase() == 'PD') return 1;
        return a.pieceLabel.compareTo(b.pieceLabel);
      });
      return out;
    } catch (_) {
      return const <_PdfPieceResult>[];
    }
  }

  pw.Widget _pieceResultBlock(_PdfPieceResult result) {
    final offset = result.offsetM;
    final offsetText = offset == null
        ? null
        : '${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(1)} m';

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '${result.objectiveLabel} / ${result.pieceLabel}',
            style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
          ),
          if (offsetText != null) _kv('Offset', offsetText),
          if (_hasText(result.noire)) _kv('Firing bearing', result.noire!),
          if (_hasText(result.aqe)) _kv('AQE', result.aqe!),
          if (_hasText(result.charge)) _kv('Charge', result.charge!),
          if (_hasText(result.temps)) _kv('Time of flight', result.temps!),
        ],
      ),
    );
  }

  pw.Widget _mapBlock(String title, Uint8List bytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(height: 8),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ],
    );
  }

  pw.Widget _header(pw.Context context, DateTime now) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'REPORT - LAST CALCULATION',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(_humanDate(now), style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          'Document generated automatically from the last calculation.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          'Page ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _kv(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              key,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
          ),
        ],
      ),
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty && value.trim() != '—';
  }

  static String? _asText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == '—' || text == 'null') return null;
    return text;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _objectiveLabel(String pieceLabel) {
    final id = pieceLabel.trim().toUpperCase();
    if (id == 'PD') return 'OPD';
    final match = RegExp(r'^PS(\d+)$').firstMatch(id);
    if (match != null) return 'OS${match.group(1)}';
    return 'O$id';
  }

  static String _stamp(DateTime d) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  static String _humanDate(DateTime d) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _PdfPieceResult {
  const _PdfPieceResult({
    required this.pieceLabel,
    required this.objectiveLabel,
    this.offsetM,
    this.noire,
    this.aqe,
    this.charge,
    this.temps,
  });

  final String pieceLabel;
  final String objectiveLabel;
  final double? offsetM;
  final String? noire;
  final String? aqe;
  final String? charge;
  final String? temps;
}
