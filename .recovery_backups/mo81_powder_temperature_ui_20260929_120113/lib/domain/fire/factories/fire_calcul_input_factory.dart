import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/services/fire_geometry_resolver.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class FireCalculInputFactory {
  const FireCalculInputFactory();

  /// Convertit la demande typée du domaine en entrée du moteur balistique
  /// historique. Les coordonnées et la DAZ sont déjà normalisées par
  /// [FireGeometryResolver] : le moteur reçoit donc toujours une géométrie
  /// cohérente, quel que soit le mode de saisie UI.
  CalculInput create({
    required FireRequest request,
    required FireGeometryResult geometry,
  }) {
    final effectiveMunition = request.typeMunition ??
        munitionParDefautPour(
          systeme: request.systeme,
          typeTir: request.typeTir,
        ) ??
        TypeMunition.oeF5Fr;

    final effectiveFusee = request.fusee ??
        fuseeCompatibilityPour(
          systeme: request.systeme,
          typeTir: request.typeTir,
          munition: effectiveMunition,
        ).reference;

    final pieceAltitudeM = request.piece.altitude ?? 0.0;
    final targetAltitudeM = request.target.altitude ?? pieceAltitudeM;
    final meteoRows = request.meteo?.rows ?? const <MeteoRow>[];

    return CalculInput(
      systeme: request.systeme,
      typeTir: request.typeTir,
      typeMunition: effectiveMunition,
      typeChargeCaesar: request.typeChargeCaesar,
      m252MunitionFamily: request.m252MunitionFamily,
      fusee: effectiveFusee,
      distanceM: geometry.distanceTopo,
      deltaAltitudeM: targetAltitudeM - pieceAltitudeM,
      azimutObjectifMil: geometry.azimutMil,
      carreaux: request.carreaux,
      chargeForcee: request.chargeForceeStr ?? request.chargeForcee?.toString(),
      tirVertical: request.tirVertical,
      natureTir: _natureTirSelection(request),
      meteo: meteoRows.isEmpty ? null : meteoRows.first,
      meteoRows: request.meteo == null ? null : meteoRows,
      pdX: geometry.pdX,
      pdY: geometry.pdY,
      pdZ: pieceAltitudeM,
      pdZone: request.piece.utmZone ?? '',
      isUtmPd: request.piece.utmX != null && request.piece.utmY != null,
      pdLatitudeDeg: geometry.latitudeDeg,
      objX: geometry.objXfinal,
      objY: geometry.objYfinal,
      objZ: targetAltitudeM,
      isUtmObj: request.target.mode != FireTargetMode.daz,
      objA: geometry.azimutMil,
      objD: geometry.distanceTopo,
      objAlt: targetAltitudeM,
      natureObjectif: _natureObjectif(request.doctrine.nature),
      carreauxMasseObus: request.carreaux,
      meteoOn: request.meteo != null,
      meteoStationAltM: request.meteo?.stationAltM ?? 0.0,
      // Sans ligne météo résolue, les services historiques utilisent le niveau
      // doctrinal 5. Les lignes présentes remplacent ensuite ce niveau.
      niveauMeteoB: 5,
      tirMontagne: false,
      simCarreaux: request.simCarreaux.toDouble(),
      // L'ancien moteur attend un scalaire mais le nouveau contrat transporte
      // une TypeFusee. Le champ historique n'est plus une source de calcul.
      simFusee: 0.0,
      simTempActC: request.tAct ?? 0.0,
      simTempPrevC: request.tPrev ?? 0.0,
      simV0Prev: request.v0Prev ?? 0.0,
      autresPieces: request.supportPieces,
    );
  }

  NatureTirSelection _natureTirSelection(FireRequest request) {
    final doctrine = request.doctrine;
    final zonal = doctrine.zonal;
    final lineaire = doctrine.lineaire;

    return NatureTirSelection(
      enabled: doctrine.nature != FireNature.ponctuel,
      nature: _natureTirType(doctrine.nature),
      nbCoups: doctrine.shotPlan.nbCoups,
      longueurM: lineaire.longueurM,
      longueurZonaleM: zonal.longueurM,
      profondeurM: zonal.profondeurM,
      pointApplicationLineaire: _pointApplicationLineaire(
        lineaire.referencePoint,
      ),
      pointZonal: zonal.pointZonal,
      zonalMode: zonal.zonalMode,
      lineairePar: doctrine.shotPlan.par,
      azimutMil: lineaire.azimutLineaireMil,
      azimutLargeurMil: zonal.azimutLargeurMil,
      azimutProfondeurMil: zonal.azimutProfondeurMil,
      pourcentageDebordement: zonal.debordementPct,
      pourcentageRecouvrement: zonal.recouvrementPct,
      salvesEnabled: request.salves.enabled,
      salvesPreferenceIdx: request.salves.preferenceIdx,
      lastSalveAroundPd: request.salves.lastSalveAroundPd,
    );
  }

  NatureTirType _natureTirType(FireNature nature) {
    switch (nature) {
      case FireNature.ponctuel:
        return NatureTirType.ponctuel;
      case FireNature.lineaire:
        return NatureTirType.lineaire;
      case FireNature.zonal:
        return NatureTirType.zonal;
    }
  }

  NatureObjectif _natureObjectif(FireNature nature) {
    switch (nature) {
      case FireNature.ponctuel:
        return NatureObjectif.ponctuel;
      case FireNature.lineaire:
        return NatureObjectif.lineaire;
      case FireNature.zonal:
        return NatureObjectif.surface;
    }
  }

  PointApplicationLineaire? _pointApplicationLineaire(
    FireLinearReferencePoint? reference,
  ) {
    switch (reference) {
      case FireLinearReferencePoint.left:
        return PointApplicationLineaire.gauche;
      case FireLinearReferencePoint.right:
        return PointApplicationLineaire.droite;
      case FireLinearReferencePoint.extremity:
        return PointApplicationLineaire.extremite;
      case FireLinearReferencePoint.center:
        return PointApplicationLineaire.centre;
      case null:
        return null;
    }
  }
}
