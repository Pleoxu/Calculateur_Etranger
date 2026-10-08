enum FirePlanKind {
  ponctuel,
  lineaire,
  zonal;

  // ---------------------------------------------------------------------------
  // Helpers métier
  // ---------------------------------------------------------------------------

  bool get isPonctuel => this == FirePlanKind.ponctuel;
  bool get isLineaire => this == FirePlanKind.lineaire;
  bool get isZonal => this == FirePlanKind.zonal;

  bool get isNature => isLineaire || isZonal;

  // ---------------------------------------------------------------------------
  // Compat legacy (à supprimer en fin de migration)
  // ---------------------------------------------------------------------------

  String get legacyPa {
    switch (this) {
      case FirePlanKind.ponctuel:
        return 'PR';
      case FirePlanKind.lineaire:
        return 'LINEAIRE';
      case FirePlanKind.zonal:
        return 'ZONAL';
    }
  }

  // ---------------------------------------------------------------------------
  // Factory depuis ancien système (natureIdx)
  // ---------------------------------------------------------------------------

  static FirePlanKind fromNatureIdx(int? natureIdx, {required bool enabled}) {
    if (!enabled) return FirePlanKind.ponctuel;

    switch (natureIdx) {
      case 1:
        return FirePlanKind.lineaire;
      case 2:
        return FirePlanKind.zonal;
      default:
        return FirePlanKind.ponctuel;
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing (utile si persistence / debug / JSON)
  // ---------------------------------------------------------------------------

  static FirePlanKind fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'LINEAIRE':
        return FirePlanKind.lineaire;
      case 'ZONAL':
        return FirePlanKind.zonal;
      case 'PR':
      default:
        return FirePlanKind.ponctuel;
    }
  }

  String get nameUpper {
    switch (this) {
      case FirePlanKind.ponctuel:
        return 'PONCTUEL';
      case FirePlanKind.lineaire:
        return 'LINEAIRE';
      case FirePlanKind.zonal:
        return 'ZONAL';
    }
  }
}
