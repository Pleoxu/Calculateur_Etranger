// lib/services/messages/ct_piece_display_payload.dart
//
// Generic display payload for CTMSG.
// This layer is intentionally domain-agnostic: it transports labeled
// sections/fields without interpreting their operational meaning.

import 'dart:convert';
import 'dart:typed_data';

class CtPieceDisplayField {
  const CtPieceDisplayField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  Map<String, Object> toJson() => <String, Object>{
        'label': label,
        'value': value,
      };

  static CtPieceDisplayField fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final value = json['value'];

    if (label is! String || label.trim().isEmpty) {
      throw const FormatException('Label de champ invalide.');
    }
    if (value is! String) {
      throw const FormatException('Valeur de champ invalide.');
    }

    return CtPieceDisplayField(
      label: label,
      value: value,
    );
  }
}

class CtPieceDisplaySection {
  const CtPieceDisplaySection({
    required this.title,
    required this.fields,
  });

  final String title;
  final List<CtPieceDisplayField> fields;

  Map<String, Object> toJson() => <String, Object>{
        'title': title,
        'fields': fields.map((field) => field.toJson()).toList(),
      };

  static CtPieceDisplaySection fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final rawFields = json['fields'];

    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Titre de section invalide.');
    }
    if (rawFields is! List) {
      throw const FormatException('Liste de champs invalide.');
    }

    return CtPieceDisplaySection(
      title: title,
      fields: rawFields
          .map(
            (item) => CtPieceDisplayField.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CtPieceDisplayPayload {
  const CtPieceDisplayPayload({
    required this.title,
    required this.sections,
  });

  static const int schemaVersion = 1;

  final String title;
  final List<CtPieceDisplaySection> sections;

  Map<String, Object> toJson() => <String, Object>{
        'schema': 'ct-piece-display',
        'version': schemaVersion,
        'title': title,
        'sections': sections.map((section) => section.toJson()).toList(),
      };

  Uint8List toBytes() => Uint8List.fromList(
        utf8.encode(jsonEncode(toJson())),
      );

  static CtPieceDisplayPayload fromBytes(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload pièce invalide.');
    }

    if (decoded['schema'] != 'ct-piece-display') {
      throw const FormatException('Schéma de payload non reconnu.');
    }

    if (decoded['version'] != schemaVersion) {
      throw FormatException(
        'Version de payload non supportée: ${decoded['version']}',
      );
    }

    final title = decoded['title'];
    final rawSections = decoded['sections'];

    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Titre de payload invalide.');
    }
    if (rawSections is! List) {
      throw const FormatException('Sections de payload invalides.');
    }

    return CtPieceDisplayPayload(
      title: title,
      sections: rawSections
          .map(
            (item) => CtPieceDisplaySection.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
