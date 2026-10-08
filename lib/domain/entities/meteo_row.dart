// lib/domain/entities/meteo_row.dart

/// Représente une ligne météo unifiée (METCM ou MET B)
/// Les valeurs sont toujours en pourcentages (‰) après parsing
class MeteoRow {
  /// Numéro de ligne (00-15)
  final int level;

  /// Direction du vent en millièmes (ex: 4800 mils)
  final int azimutMils;

  /// Vitesse du vent en nœuds
  final int vKn;

  /// Température en ‰ (ex: 987 = 98.7% de T_OACI)
  final int tempPermil;

  /// Pression en ‰ (ex: 1011 = 101.1% de P_OACI)
  final int pressPermil;

  /// Type de source ("METCM" ou "METB")
  final String sourceType;

  const MeteoRow({
    required this.level,
    required this.azimutMils,
    required this.vKn,
    required this.tempPermil,
    required this.pressPermil,
    required this.sourceType,
  });

  /// Direction du vent en millièmes (alias pour compatibilité)
  int get azMil => azimutMils;

  /// Température en pourcentage (ex: 98.7%)
  double get tempPercent => tempPermil / 10.0;

  /// Pression en pourcentage (ex: 101.1%)
  double get pressPercent => pressPermil / 10.0;

  @override
  String toString() {
    return 'MeteoRow(level: $level, az: $azMil mil, v: $vKn kn, '
        'T: $tempPercent%, P: $pressPercent%, source: $sourceType)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteoRow &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          azimutMils == other.azimutMils &&
          vKn == other.vKn &&
          tempPermil == other.tempPermil &&
          pressPermil == other.pressPermil &&
          sourceType == other.sourceType;

  @override
  int get hashCode =>
      level.hashCode ^
      azimutMils.hashCode ^
      vKn.hashCode ^
      tempPermil.hashCode ^
      pressPermil.hashCode ^
      sourceType.hashCode;
}
