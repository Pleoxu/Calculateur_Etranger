// lib/presentation/fire/models/repartition_view_mode.dart

enum RepartitionViewMode { theorique, reelle, distribution }

extension RepartitionViewModeX on RepartitionViewMode {
  String get label {
    switch (this) {
      case RepartitionViewMode.theorique:
        return 'Théorique';
      case RepartitionViewMode.reelle:
        return 'Réel';
      case RepartitionViewMode.distribution:
        return 'Distribution';
    }
  }

  RepartitionViewMode get next {
    switch (this) {
      case RepartitionViewMode.theorique:
        return RepartitionViewMode.reelle;
      case RepartitionViewMode.reelle:
        return RepartitionViewMode.distribution;
      case RepartitionViewMode.distribution:
        return RepartitionViewMode.theorique;
    }
  }

  bool get isRealLike =>
      this == RepartitionViewMode.reelle ||
      this == RepartitionViewMode.distribution;

  bool get showsSpatialDistribution => this == RepartitionViewMode.distribution;

  /// Toujours false — le mode RED est désormais une page dédiée.
  bool get showsRed => false;
}
