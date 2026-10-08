import 'package:calculateur_etranger/models/calcul_data.dart';

/// Doctrine officielle : diamètre d'efficacité (en mètres)
/// AVANT application du recouvrement.
/// Caesar : 100 m — Mepac / MO-120 : 50 m
class EfficaciteSysteme {
  static double diametre(Systeme systeme) => systeme.diametreEfficaciteM;
}
