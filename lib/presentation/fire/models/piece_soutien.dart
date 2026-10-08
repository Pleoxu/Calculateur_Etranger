// lib/presentation/fire/models/piece_soutien.dart

import 'package:calculateur_etranger/models/calcul_data.dart';

/// Représente un objectif secondaire assigné à une pièce.
class ObjectifSecondaire {
  final int index; // Index de l'objectif (OS1, OS2, ...)
  final double offsetM; // Offset en mètres
  final double x; // Coordonnée X (UTM)
  final double y; // Coordonnée Y (UTM)
  final double? z; // Coordonnée Z absolue (altitude) optionnelle
  final CalculResult? resultat; // Résultat balistique pour cet objectif

  const ObjectifSecondaire({
    required this.index,
    required this.offsetM,
    required this.x,
    required this.y,
    this.z,
    this.resultat,
  });

  ObjectifSecondaire copyWith({
    int? index,
    double? offsetM,
    double? x,
    double? y,
    double? z,
    CalculResult? resultat,
  }) {
    return ObjectifSecondaire(
      index: index ?? this.index,
      offsetM: offsetM ?? this.offsetM,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      resultat: resultat ?? this.resultat,
    );
  }
}

class PieceSoutien {
  String nom;

  // Données saisies par rapport à la PD.
  double distanceM;
  double azimutMil;

  /// Différence d'altitude de la PS par rapport à la PD.
  ///
  /// Convention :
  /// - valeur positive => PS au-dessus de la PD ;
  /// - valeur négative => PS au-dessous de la PD ;
  /// - 0 => même altitude que la PD.
  double deltaZPd;

  // Coordonnées absolues de la pièce (UTM).
  //
  // zPS reste conservé pour compatibilité avec le moteur actuel. À terme,
  // l'altitude absolue peut être reconstruite à l'entrée du calcul :
  // zPS = zPD + deltaZPd.
  double? xPS;
  double? yPS;
  double? zPS;

  // Résultat balistique pour cette pièce.
  CalculResult? resultat;

  // Tir linéaire / zonal : objectifs secondaires assignés à cette pièce.
  List<ObjectifSecondaire> objectifsSecondaires;

  // [DEPRECATED] Conservé pour compatibilité rétroactive.
  int? objectifIndex;
  double? offsetM;

  PieceSoutien({
    required this.nom,
    this.distanceM = 0.0,
    this.azimutMil = 0.0,
    this.deltaZPd = 0.0,
    this.xPS,
    this.yPS,
    this.zPS,
    this.resultat,
    this.objectifsSecondaires = const [],
    this.objectifIndex,
    this.offsetM,
  });

  PieceSoutien copyWith({
    String? nom,
    double? distanceM,
    double? azimutMil,
    double? deltaZPd,
    double? xPS,
    double? yPS,
    double? zPS,
    CalculResult? resultat,
    List<ObjectifSecondaire>? objectifsSecondaires,
    int? objectifIndex,
    double? offsetM,
  }) {
    return PieceSoutien(
      nom: nom ?? this.nom,
      distanceM: distanceM ?? this.distanceM,
      azimutMil: azimutMil ?? this.azimutMil,
      deltaZPd: deltaZPd ?? this.deltaZPd,
      xPS: xPS ?? this.xPS,
      yPS: yPS ?? this.yPS,
      zPS: zPS ?? this.zPS,
      resultat: resultat ?? this.resultat,
      objectifsSecondaires: objectifsSecondaires ?? this.objectifsSecondaires,
      objectifIndex: objectifIndex ?? this.objectifIndex,
      offsetM: offsetM ?? this.offsetM,
    );
  }

  /// Retourne le premier objectif secondaire pour compatibilité rétroactive.
  ObjectifSecondaire? get firstObjectifSecondaire =>
      objectifsSecondaires.isNotEmpty ? objectifsSecondaires.first : null;

  /// Retourne le nombre total d'objectifs secondaires.
  int get nbObjectifsSecondaires => objectifsSecondaires.length;

  /// Retourne le résultat du premier objectif secondaire pour compatibilité rétroactive.
  CalculResult? get firstObjectifResultat => firstObjectifSecondaire?.resultat;
}
