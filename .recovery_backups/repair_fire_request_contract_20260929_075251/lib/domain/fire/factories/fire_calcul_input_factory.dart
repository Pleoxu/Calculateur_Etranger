// lib/domain/fire/factories/fire_calcul_input_factory.dart

import '../../../models/calcul_data.dart';
import '../models/tir_complet_input.dart';

class FireCalculInputFactory {
  const FireCalculInputFactory();

  CalculInput create(TirCompletInput input) {
    return createFromTirComplet(input);
  }

  static CalculInput createFromTirComplet(TirCompletInput input) {
    final effectiveMunition = input.munition ?? TypeMunition.oeF5Fr;
    final effectiveFusee = input.fusee;

    return CalculInput(
      systeme: input.systeme,
      typeTir: input.typeTir,
      typeMunition: effectiveMunition,
      typeChargeCaesar: input.typeChargeCaesar,
      m252MunitionFamily: input.m252MunitionFamily,
      lrrMunitionFamily: input.lrrMunitionFamily,
      fusee: effectiveFusee,
      distanceM: input.distanceM,
      deltaAltitudeM: input.deltaAltitudeM,
      azimutObjectifMil: input.azimutObjectifMil,
      carreaux: input.carreaux,
      chargeForcee: input.chargeForcee,
      tirVertical: input.tirVertical,
      natureTir: input.natureTir,
      meteo: input.meteo,
      meteoRows: input.meteoRows,
      pdX: input.pdX,
      pdY: input.pdY,
      pdZ: input.pdZ,
      pdZone: input.pdZone,
      isUtmPd: input.isUtmPd,
      pdLatitudeDeg: input.pdLatitudeDeg,
      objX: input.objX,
      objY: input.objY,
      objZ: input.objZ,
      isUtmObj: input.isUtmObj,
      objA: input.objA,
      objD: input.objD,
      objAlt: input.objAlt,
      natureObjectif: input.natureObjectif,
      carreauxMasseObus: input.carreauxMasseObus,
      meteoOn: input.meteoOn,
      meteoStationAltM: input.meteoStationAltM,
      niveauMeteoB: input.niveauMeteoB,
      meteoAzVentMil: input.meteoAzVentMil,
      meteoVKn: input.meteoVKn,
      metTempPercent: input.metTempPercent,
      metPressPercent: input.metPressPercent,
      tirMontagne: input.tirMontagne,
      simCarreaux: input.simCarreaux,
      simFusee:
          (input.simFusee is num) ? (input.simFusee as num).toDouble() : 0.0,
      simTempActC: input.simTempActC,
      simTempPrevC: input.simTempPrevC,
      simV0Prev: input.simV0Prev,
      autresPieces: input.autresPieces,
    );
  }
}
