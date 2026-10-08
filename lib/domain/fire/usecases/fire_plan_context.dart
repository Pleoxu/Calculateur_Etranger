import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';

class FirePlanContext {
  final TirCompletInput input;

  final double prX;
  final double prY;
  final double azimutMil;

  final FirePlanKind kind;

  const FirePlanContext({
    required this.input,
    required this.prX,
    required this.prY,
    required this.azimutMil,
    required this.kind,
  });

  factory FirePlanContext.create({
    required TirCompletInput input,
    required double prX,
    required double prY,
    required double azimutMil,
  }) {
    return FirePlanContext(
      input: input,
      prX: prX,
      prY: prY,
      azimutMil: azimutMil,
      kind: _resolveKind(input),
    );
  }

  static FirePlanKind _resolveKind(TirCompletInput input) {
    if (input.natureEnabled && input.natureIdx == 1) {
      return FirePlanKind.lineaire;
    }
    if (input.natureEnabled && input.natureIdx == 2) {
      return FirePlanKind.zonal;
    }
    return FirePlanKind.ponctuel;
  }

  bool get isLineaire => kind.isLineaire;
  bool get isZonal => kind.isZonal;
  bool get isPonctuel => kind == FirePlanKind.ponctuel;

  bool get hasBattery => input.autrePieces && input.piecesSoutien.isNotEmpty;

  int get parLineaire => (input.lineairePar ?? 1).clamp(1, 12);
  int get par => isLineaire ? parLineaire : 1;

  double get pdX => input.xPiece ?? 0.0;
  double get pdY => input.yPiece ?? 0.0;

  double get azimutLineaireMil => input.azimutLineaireMil ?? azimutMil;

  bool get salvesEnabled => input.salvesEnabled;
  bool get natureEnabled => input.natureEnabled;

  bool get hasManualNbCoups => input.nbCoups != null && input.nbCoups! > 0;
  int? get nbCoups => input.nbCoups;

  Map<String, int> get rawCoupsMap =>
      input.coupsParPieceByPiece ?? const <String, int>{};

  bool get hasRawPieceWeights => rawCoupsMap.isNotEmpty;
}
