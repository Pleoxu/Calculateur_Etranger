import '../services/selection_charge_service.dart';

class TableauGMeta {
  final String typeTir;
  final String charge;
  final String tableau;
  final String designation;

  const TableauGMeta({
    required this.typeTir,
    required this.charge,
    required this.tableau,
    required this.designation,
  });

  factory TableauGMeta.fromJson(Map<String, dynamic> json) {
    return TableauGMeta(
      typeTir: json['typeTir'] as String? ?? '',
      charge: json['charge'] as String? ?? '',
      tableau: json['tableau'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
    );
  }
}

class TableauGRow implements SelectionChargeDataRow {
  static const double distanceEpsilon = 1e-9;

  @override
  final double distance;

  final double hausse;
  final double ecartProbablePortee;
  final double ecartProbableDirection;
  final double ecartProbableHauteurEclatement;
  final double ecartProbableDelaiEclatement;
  final double ecartProbablePorteeEclatement;
  final double angleChute;
  final double cotangenteAngleChute;
  final double vitesseRestante;
  final double fleche;
  final double correctionComplementSiteAnglePlus;
  final double correctionComplementSiteAngleMoins;
  final bool tirMontagne;

  const TableauGRow({
    required this.distance,
    required this.hausse,
    required this.ecartProbablePortee,
    required this.ecartProbableDirection,
    required this.ecartProbableHauteurEclatement,
    required this.ecartProbableDelaiEclatement,
    required this.ecartProbablePorteeEclatement,
    required this.angleChute,
    required this.cotangenteAngleChute,
    required this.vitesseRestante,
    required this.fleche,
    required this.correctionComplementSiteAnglePlus,
    required this.correctionComplementSiteAngleMoins,
    required this.tirMontagne,
  });

  factory TableauGRow.fromJson(Map<String, dynamic> json) {
    double number(String primaryKey, [String? legacyKey]) {
      final value =
          json[primaryKey] ?? (legacyKey == null ? null : json[legacyKey]);
      return (value as num?)?.toDouble() ?? 0.0;
    }

    return TableauGRow(
      distance: number('distance'),
      hausse: number('hausse', 'hausseTables'),
      ecartProbablePortee: number('ecartProbablePortee'),
      ecartProbableDirection: number('ecartProbableDirection'),
      ecartProbableHauteurEclatement: number('ecartProbableHauteurEclatement'),
      ecartProbableDelaiEclatement: number('ecartProbableDelaiEclatement'),
      ecartProbablePorteeEclatement: number('ecartProbablePorteeEclatement'),
      angleChute: number('angleChute'),
      cotangenteAngleChute: number('cotangenteAngleChute'),
      vitesseRestante: number('vitesseRestante'),
      fleche: number('fleche'),
      correctionComplementSiteAnglePlus: number(
        'correctionComplementSiteAnglePlus',
        'correctionSitePlus1Mil',
      ),
      correctionComplementSiteAngleMoins: number(
        'correctionComplementSiteAngleMoins',
        'correctionSiteMoins1Mil',
      ),
      tirMontagne: json['tirMontagne'] as bool? ?? false,
    );
  }

  @override
  double get criterionValue => ecartProbablePortee;

  @override
  bool get alternateBranch => tirMontagne;
}

class TableauGTable implements SelectionChargeDataTable<TableauGRow> {
  final TableauGMeta meta;

  @override
  final List<TableauGRow> rows;

  const TableauGTable({required this.meta, required this.rows});

  factory TableauGTable.fromJson(Map<String, dynamic> json) {
    final metaJson = Map<String, dynamic>.from(
      json['meta'] as Map? ?? const {},
    );

    final rowsJson = json['rows'] as List? ?? const [];

    final parsedRows = rowsJson
        .map(
          (item) =>
              TableauGRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    return TableauGTable(
      meta: TableauGMeta.fromJson(metaJson),
      rows: List<TableauGRow>.unmodifiable(parsedRows),
    );
  }

  TableauGRow? exactDistance(double distance) {
    for (final row in rows) {
      if ((row.distance - distance).abs() <= TableauGRow.distanceEpsilon) {
        return row;
      }
    }
    return null;
  }
}
