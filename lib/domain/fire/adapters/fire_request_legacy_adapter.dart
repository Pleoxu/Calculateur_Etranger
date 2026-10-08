import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';

class FireRequestLegacyAdapter {
  const FireRequestLegacyAdapter();

  TirCompletInput toLegacy(FireRequest request) {
    final bool pieceIsUtm =
        request.piece.utmX != null && request.piece.utmY != null;

    return TirCompletInput(
      systeme: request.systeme,
      typeTir: request.typeTir,
      fusee: request.fusee,
      pieceUtm: pieceIsUtm,
      xPiece: request.piece.utmX,
      yPiece: request.piece.utmY,
      zPiece: request.piece.altitude,
      zone: request.piece.utmZone,
      latPiece: request.piece.latitude,
      lonPiece: request.piece.longitude,
      altPiece: request.piece.altitude,
      objectifMode: _toLegacyObjectifMode(request.target.mode),
      xObj: request.target.utmX,
      yObj: request.target.utmY,
      zObj: request.target.altitude,
      distanceObj: request.target.distanceM,
      azimutObj: request.target.azimutMil,
      altObj: request.target.altitude,
      latObj: request.target.latitude,
      lonObj: request.target.longitude,
      tirVertical: request.tirVertical,
      forcerCharge: request.forcerCharge,
      chargeForcee: request.chargeForcee,
      natureEnabled: request.doctrine.nature != FireNature.ponctuel,
      natureIdx: _toLegacyNatureIdx(request.doctrine.nature),
      longueurLineaire: request.doctrine.lineaire.longueurM,
      longueurZonale: request.doctrine.zonal.longueurM,
      profondeurZonale: request.doctrine.zonal.profondeurM,
      zonalMode: request.doctrine.zonal.zonalMode,
      isZonalPreset: request.doctrine.zonal.isZonalPreset,
      pointZonal: request.doctrine.zonal.pointZonal,
      azimutLargeurMil: request.doctrine.zonal.azimutLargeurMil,
      azimutProfondeurMil: request.doctrine.zonal.azimutProfondeurMil,
      pourcentageDebordement: request.doctrine.zonal.debordementPct,
      pourcentageRecouvrement: request.doctrine.zonal.recouvrementPct,
      nbCoups: request.doctrine.shotPlan.nbCoups,
      lineairePar: request.doctrine.shotPlan.par,
      salvesEnabled: request.salves.enabled,
      salvesPreferenceIdx: request.salves.preferenceIdx,
      lastSalveAroundPd: request.salves.lastSalveAroundPd,
      lineaireDepuisExtremite: request.doctrine.lineaire.referencePoint ==
          FireLinearReferencePoint.extremity,
      azimutLineaireMil: request.doctrine.lineaire.azimutLineaireMil,
      coupsParPieceByPiece: request.doctrine.shotPlan.coupsParPiece,
      linearFiringMode: _toLegacyLinearFiringMode(
        request.doctrine.lineaire.firingMode,
      ),
      selectedLinearRoles: request.doctrine.lineaire.selectedRoles,
      masseEnabled: request.masseEnabled,
      carreaux: request.carreaux,
      tirSimilaire: request.tirSimilaire,
      simCarreaux: request.simCarreaux,
      tPrev: request.tPrev,
      tAct: request.tAct,
      v0Prev: request.v0Prev,
      meteo: request.meteo != null,
      meteoFileName: request.meteo?.fileName,
      meteoRows: request.meteo?.rows,
      meteoStationAltM: request.meteo?.stationAltM,
      autrePieces: request.supportPieces.isNotEmpty,
      piecesSoutien: request.supportPieces
          .map(
            (p) => PieceSoutienInput(
              nom: p.pieceId,
              azimutMil: p.azimutMil,
              distanceM: p.distanceM,
              zPS: p.zPS,
            ),
          )
          .toList(growable: false),
    );
  }

  ObjectifInputMode _toLegacyObjectifMode(FireTargetMode mode) {
    switch (mode) {
      case FireTargetMode.utm:
        return ObjectifInputMode.utm;
      case FireTargetMode.daz:
        return ObjectifInputMode.daz;
      case FireTargetMode.latLon:
        return ObjectifInputMode.lat;
    }
  }

  int _toLegacyNatureIdx(FireNature nature) {
    switch (nature) {
      case FireNature.ponctuel:
        return 0;
      case FireNature.lineaire:
        return 1;
      case FireNature.zonal:
        return 2;
    }
  }

  LinearFiringMode _toLegacyLinearFiringMode(FireLinearFiringMode mode) {
    switch (mode) {
      case FireLinearFiringMode.libre:
        return LinearFiringMode.libre;
      case FireLinearFiringMode.sectionWithPd:
        return LinearFiringMode.sectionWithPd;
      case FireLinearFiringMode.sectionWithoutPd:
        return LinearFiringMode.sectionWithoutPd;
      case FireLinearFiringMode.batteryWithPd:
        return LinearFiringMode.batteryWithPd;
    }
  }
}
