// lib/presentation/fire/dialogs/meteo_picker_dialog.dart

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/meteo/meteo_parse_result.dart';
import 'package:calculateur_etranger/domain/meteo/universal_meteo_parser.dart';
import 'package:calculateur_etranger/domain/meteo/meteo_validity.dart'
    as domain_validity;
import 'package:calculateur_etranger/presentation/fire/widgets/meteo_validity_dialog.dart'
    as ui_validity;

class MeteoPickResult {
  final String fileName;
  final List<MeteoRow> rows;
  final int? stationAltM;
  final MeteoTemporalInfo? temporalInfo;

  const MeteoPickResult({
    required this.fileName,
    required this.rows,
    required this.stationAltM,
    required this.temporalInfo,
  });
}

Future<MeteoPickResult?> showMeteoPickerDialog({
  required BuildContext context,
  required bool dark,
}) async {
  try {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File selection not supported on the web.'),
          ),
        );
      }
      return null;
    }

    const typeGroup = XTypeGroup(
      label: 'meteo',
      extensions: ['txt', 'metcm', 'met'],
      uniformTypeIdentifiers: [
        'public.text',
        'public.plain-text',
        'public.data',
        'public.item',
      ],
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!context.mounted) return null;

    final file = await openFile(
      acceptedTypeGroups: [typeGroup],
      confirmButtonText: 'OK',
    );

    if (file == null) return null;

    final fileName = file.name;
    final content = await file.readAsString();

    if (content.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier METEO vide ou illisible.')),
        );
      }
      return null;
    }

    final parsed = UniversalMeteoParser.parseWithAltitude(content);
    final rows = parsed.rows;
    final stationAltM = parsed.stationAltitudeM;
    final temporalInfo = parsed.temporalInfo;

    if (temporalInfo != null && context.mounted) {
      final validityResult = domain_validity.MeteoValidityService.checkValidity(
        temporalInfo,
      );

      final shouldContinue = await ui_validity.MeteoValidityDialog.show(
        context,
        validityResult,
        temporalInfo,
        dark: dark,
      );

      if (!shouldContinue) return null;
    }

    if (context.mounted) {
      if (stationAltM == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Weather file loaded, station altitude not found (ΔZ = —).',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Weather file loaded: ${rows.length} levels, station altitude ${stationAltM}m.',
            ),
          ),
        );
      }
    }

    return MeteoPickResult(
      fileName: fileName,
      rows: rows,
      stationAltM: stationAltM,
      temporalInfo: temporalInfo,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open METEO: $e')));
    }
    return null;
  }
}
