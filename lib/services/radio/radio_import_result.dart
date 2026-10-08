import 'package:calculateur_etranger/domain/radio/pd_position_state.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';

class RadioImportResult {
  final PdPositionState pd;
  final List<PieceSoutien> pieces;

  const RadioImportResult({required this.pd, required this.pieces});
}
