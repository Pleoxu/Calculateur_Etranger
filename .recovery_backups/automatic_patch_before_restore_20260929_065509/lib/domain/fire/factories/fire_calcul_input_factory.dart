import '../../../models/calcul_data.dart';
import '../models/tir_complet_input.dart';

class FireCalculInputFactory {
  const FireCalculInputFactory();

  CalculInput create(TirCompletInput input) {
    return createFromTirComplet(input);
  }

  static CalculInput createFromTirComplet(TirCompletInput input) {
    final effectiveMunition = input.munition ?? TypeMunition.oeF5Fr;
    final effectiveFusee = input.fusee ?? TypeFusee.values.first;

    return CalculInput(
      systeme: input.systeme,
      typeTir: input.typeTir,
      typeMunition: effectiveMunition,
      typeChargeCaesar: (input as dynamic).typeChargeCaesar,
      m252MunitionFamily: (input as dynamic).m252MunitionFamily,
      lrrMunitionFamily: (input as dynamic).lrrMunitionFamily,
      fusee: effectiveFusee,
      distanceM: input.distanceM ?? 0.0,
      deltaAltitudeM: (input as dynamic).deltaAltitudeM ?? 0.0,
      azimutObjectifMil: (input as dynamic).azimutObjectifMil ?? 0.0,
      carreaux: input.carreaux,
      chargeForcee: input.chargeForcee?.toString(),
      tirVertical: input.tirVertical,
      natureTir: input.natureTir ?? NatureTirSelection.standard,
      meteo:
          input.meteoRows?.isNotEmpty == true ? input.meteoRows!.first : null,
      meteoRows: input.meteoRows,
      pdX: input.pdX ?? 0.0,
      pdY: input.pdY ?? 0.0,
      pdZ: input.pdZ ?? 0.0,
      pdZone: (input as dynamic).pdZone,
      isUtmPd: (input as dynamic).isUtmPd ?? false,
      pdLatitudeDeg: (input as dynamic).pdLatitudeDeg,
      objX: (input as dynamic).objX ?? 0.0,
      objY: (input as dynamic).objY ?? 0.0,
      objZ: (input as dynamic).objZ ?? 0.0,
      isUtmObj: (input as dynamic).isUtmObj ?? false,
      objA: (input as dynamic).objA ?? 0.0,
      objD: (input as dynamic).objD ?? 0.0,
      objAlt: (input as dynamic).objAlt ?? 0.0,
      natureObjectif: (input as dynamic).natureObjectif,
      carreauxMasseObus: (input as dynamic).carreauxMasseObus,
      meteoOn: (input as dynamic).meteoOn ?? false,
      meteoStationAltM: input.meteoStationAltM ?? 0.0,
      niveauMeteoB: (input as dynamic).niveauMeteoB,
      meteoAzVentMil: (input as dynamic).meteoAzVentMil,
      meteoVKn: (input as dynamic).meteoVKn,
      metTempPercent: (input as dynamic).metTempPercent,
      metPressPercent: (input as dynamic).metPressPercent,
      tirMontagne: (input as dynamic).tirMontagne ?? false,
      simCarreaux: input.simCarreaux?.toDouble() ?? 0.0,
      simFusee: (input as dynamic).simFusee?.toDouble() ?? 0.0,
      simTempActC: (input as dynamic).simTempActC,
      simTempPrevC: (input as dynamic).simTempPrevC,
      simV0Prev: (input as dynamic).simV0Prev,
      autresPieces: (input as dynamic).autresPieces,
    );
  }
}
