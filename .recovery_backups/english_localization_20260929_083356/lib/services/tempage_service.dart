// lib/services/tempage_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import 'secure_asset_resolver.dart';
import 'secure_table_service.dart';

class TempageResult {
  final int eventRefSeconds;
  final double dcfsSeconds;
  final double tempageNominalViserS;
  final double eclDzSeconds;
  final double tempageFinalS;

  final double corrVent;
  final double corrTb;
  final double corrDb;
  final double corrV0;
  final double corrMasse;
  final double corrRtc;
  final double corrDz;

  TempageResult({
    required this.eventRefSeconds,
    required this.dcfsSeconds,
    required this.tempageNominalViserS,
    required this.eclDzSeconds,
    required this.tempageFinalS,
    required this.corrVent,
    required this.corrTb,
    required this.corrDb,
    required this.corrV0,
    required this.corrMasse,
    required this.corrRtc,
    required this.corrDz,
  });
}

class TempageService {
  final SystemeArme systeme;
  final SecureTableService _secureTable;

  const TempageService({
    this.systeme = SystemeArme.caesar,
    SecureTableService secureTable = const SecureTableService(),
  }) : _secureTable = secureTable;

  Future<TempageResult> compute({
    required String typeAssets,
    required String charge,
    required bool tirMontagne,
    required double distanceCorrigeeM,
    required double porteeViserM,
    required double deniveleeM,
    required double ventLongKn,
    required bool ventArriere,
    required double dtbPercent,
    required double ddbPercent,
    required double deltaV0,
    required double tempMunitionC,
    double deltaMasseCarreaux = 0.0,
    TypeFusee fusee = TypeFusee.fuDeF2,
    bool appliquerCorrectionDenivelee = true,
    double? correctionDeniveleePar100mS,
  }) async {
    final canonicalType = _canonType(typeAssets);
    final bool isArt385 = canonicalType == 'OECL_ART385';
    final bool isFuchsia = isArt385 && fusee == TypeFusee.fuchsia;

    // ── Tempage de référence (distance corrigée) ─────────────────────────────
    //
    // ART385 / FUCHSIA : le tableau F ne contient que les données de la fusée
    // de référence FU DE F2. Pour FUCHSIA, le tempage nominal est lu dans le
    // tableau ECL (champ event_fuchsia_s), interpolé à la distance corrigée.
    //
    // Tous les autres cas (FU DE F2, ART392, APPUI, etc.) utilisent le tableau F.
    final double tCorr = isFuchsia
        ? await _tempageEcl(
            typeAssets,
            charge,
            distanceCorrigeeM,
            tirMontagne: tirMontagne,
          )
        : await _tempageF(
            typeAssets,
            charge,
            distanceCorrigeeM,
            tirMontagne: tirMontagne,
          );

    final eventRef = _roundToInt(tCorr);

    if (kDebugMode) {
      debugPrint(
        '[Tempage] dCorr=${distanceCorrigeeM.round()} '
        'source=${isFuchsia ? "ECL/FUCHSIA" : "F"} '
        'tCorr=${tCorr.toStringAsFixed(3)}s '
        'eventRef=$eventRef',
      );
    }

    // ── Coefficients J (sélection de la sous-table selon la fusée) ───────────
    final j = await _coeffsJ(typeAssets, charge, eventRef, fusee: fusee);

    final kVent = ventArriere ? j.ventPlus : j.ventMoins;
    final corrVent = ventLongKn.abs() * kVent;

    final kTb = dtbPercent >= 0 ? j.tempPlus : j.tempMoins;
    final corrTb = dtbPercent.abs() * kTb;

    final kDb = ddbPercent >= 0 ? j.pressionPlus : j.pressionMoins;
    final corrDb = ddbPercent.abs() * kDb;

    final kV0 = deltaV0 >= 0 ? j.v0Plus : j.v0Moins;
    final corrV0 = deltaV0.abs() * kV0;

    // ── Correction de masse ────────────────────────────────────────────────
    //
    // ART385 applique cette correction uniquement pour FUCHSIA. Le MO120,
    // lui, possède ses propres coefficients de masse dans les tables J MO et
    // applique donc la correction quelle que soit la fusée sélectionnée.
    // Pour les autres systèmes, le comportement historique reste inchangé.
    final bool appliqueCorrectionMasse =
        (isArt385 && fusee == TypeFusee.fuchsia) || systeme == SystemeArme.mo;
    double corrMasse = 0.0;
    if (appliqueCorrectionMasse && deltaMasseCarreaux != 0.0) {
      final kMasse = deltaMasseCarreaux < 0.0 ? j.masseMoins : j.massePlus;
      corrMasse = deltaMasseCarreaux.abs() * kMasse;
    }

    // ── Correction RTC / JBIS ────────────────────────────────────────────────
    //
    // ART385 intègre les corrections FU DE F2 / FUCHSIA directement dans
    // JTBL_V2 ; il ne possède donc pas de JBIS dédié.
    // OECL_ALL conserve également son comportement historique sans JBIS.
    // Le MO120 n’emploie pas de réducteur de traînée de culot dans ce flux et
    // ne possède pas de table Jbis : la correction RTC est non applicable.
    final bool utiliseRtc = systeme != SystemeArme.mo &&
        canonicalType != 'OECL_ART385' &&
        canonicalType != 'OECL_ALL';

    double corrRtc = 0.0;

    if (utiliseRtc) {
      final rtc = await _rtcJbis(typeAssets, charge, eventRef);
      corrRtc = _interpByTemp(rtc, tempMunitionC);
    } else if (kDebugMode) {
      debugPrint(
        '[TEMPAGE] RTC/JBIS ignoré pour $canonicalType '
        '(correction portée par JTBL ou non requise)',
      );
    }

    final dcfs = _round3(
      corrVent + corrTb + corrDb + corrV0 + corrMasse + corrRtc,
    );

    // ── Tempage nominal à la portée à viser ──────────────────────────────────
    //
    // Même logique de routage que pour tCorr : FUCHSIA lit l'ECL, les autres
    // lisent le tableau F.
    final double tViser = _round2(
      isFuchsia
          ? await _tempageEcl(
              typeAssets,
              charge,
              porteeViserM,
              tirMontagne: tirMontagne,
            )
          : await _tempageF(
              typeAssets,
              charge,
              porteeViserM,
              tirMontagne: tirMontagne,
            ),
    );

    // ── Correction de dénivelée ──────────────────────────────────────────────
    double corrDz = 0.0;

    if (correctionDeniveleePar100mS != null) {
      corrDz = _round3(correctionDeniveleePar100mS * (deniveleeM / 100.0));
    } else if (appliquerCorrectionDenivelee) {
      final per50 = await _eclEventPer50(
        typeAssets,
        charge,
        porteeViserM,
        tirMontagne: tirMontagne,
      );
      corrDz = _round3(per50 * (deniveleeM / 50.0));
    }

    final finalS = _round2(tViser + dcfs + corrDz);

    if (kDebugMode) {
      debugPrint(
        '[Tempage] J@$eventRef '
        'vent=${corrVent.toStringAsFixed(3)} '
        'tb=${corrTb.toStringAsFixed(3)} '
        'db=${corrDb.toStringAsFixed(3)} '
        'v0=${corrV0.toStringAsFixed(3)} '
        'masse=${corrMasse.toStringAsFixed(3)} '
        'rtc=${corrRtc.toStringAsFixed(3)} '
        'dcfs=${dcfs.toStringAsFixed(3)}',
      );

      debugPrint(
        '[Tempage] F(visée)=${tViser.toStringAsFixed(2)} '
        'ECLΔZ=${corrDz.toStringAsFixed(3)} '
        'final=${finalS.toStringAsFixed(2)}',
      );
    }

    return TempageResult(
      eventRefSeconds: eventRef,
      dcfsSeconds: dcfs,
      tempageNominalViserS: tViser,
      eclDzSeconds: corrDz,
      tempageFinalS: finalS,
      corrVent: _round3(corrVent),
      corrTb: _round3(corrTb),
      corrDb: _round3(corrDb),
      corrV0: _round3(corrV0),
      corrMasse: _round3(corrMasse),
      corrRtc: _round3(corrRtc),
      corrDz: _round3(corrDz),
    );
  }

  /// Assemble un résultat de tempage MO120 OECL à partir de composantes
  /// temporelles déjà calculées ailleurs.
  ///
  /// Cette méthode ne lit aucune table balistique et ne déduit aucune
  /// correction : elle sert uniquement à transporter proprement les
  /// composantes vers [TempageResult] / l'UI sans utiliser des zéros
  /// artificiels.
  TempageResult assembleMo120Oecl({
    required double tempageNominalS,
    required double corrVentS,
    required double corrTbS,
    required double corrDbS,
    required double corrV0S,
    double corrMasseS = 0.0,
    double corrMunitionS = 0.0,
    required double corrDeniveleeS,
  }) {
    final double dcfs =
        corrVentS + corrTbS + corrDbS + corrV0S + corrMasseS + corrMunitionS;

    final double finalS = tempageNominalS + dcfs + corrDeniveleeS;

    return TempageResult(
      eventRefSeconds: _roundToInt(tempageNominalS),
      dcfsSeconds: dcfs,
      tempageNominalViserS: tempageNominalS,
      eclDzSeconds: corrDeniveleeS,
      tempageFinalS: finalS,
      corrVent: corrVentS,
      corrTb: corrTbS,
      corrDb: corrDbS,
      corrV0: corrV0S,
      corrMasse: corrMasseS,
      corrRtc: corrMunitionS,
      corrDz: corrDeniveleeS,
    );
  }

  Future<Uint8List> _loadSecureCompressedEncrypted(String encryptedPath) async {
    final bytes = await NativeSecureAssets.decryptAsset(encryptedPath);

    if (kDebugMode) {
      debugPrint('[SECURE] AES OK $encryptedPath systeme=$systeme');
    }

    return bytes;
  }

  String _encryptedTablePath({
    required String famille,
    required String type,
    required String charge,
    required String extension,
  }) {
    return _secureTable.encryptedPath(
      systeme: systeme,
      famille: famille,
      typeTir: _canonType(type),
      charge: charge.trim().toUpperCase(),
      extension: extension,
    );
  }

  /// Calcul spécifique aux projectiles à dépotage (BONUS).
  ///
  /// Contrairement à [compute], la valeur d'entrée des tableaux J/Jbis n'est
  /// pas le temps de vol du tableau F : c'est le temps nominal de dépotage
  /// fourni par le DSPD à la distance topographique.
  ///
  /// Les coefficients J sont interpolés au temps d'entrée continu (ex. 48.56 s)
  /// afin de ne pas introduire les arrondis intermédiaires de l'exercice papier.
  /// Le temps nominal final et la correction de dénivelée sont eux aussi fournis
  /// par le DSPD à la portée à viser.
  Future<TempageResult> computeDepotage({
    required String typeAssets,
    required String charge,
    required double tempsEntreeS,
    required double tempsNominalViserS,
    required double correctionDeniveleePar100mS,
    required double deniveleeM,
    required double ventLongKn,
    required bool ventArriere,
    required double dtbPercent,
    required double ddbPercent,
    required double deltaV0,
    required double tempMunitionC,
  }) async {
    final j = await _coeffsJInterpolated(typeAssets, charge, tempsEntreeS);

    final kVent = ventArriere ? j.ventPlus : j.ventMoins;
    final corrVent = ventLongKn.abs() * kVent;

    final kTb = dtbPercent >= 0 ? j.tempPlus : j.tempMoins;
    final corrTb = dtbPercent.abs() * kTb;

    final kDb = ddbPercent >= 0 ? j.pressionPlus : j.pressionMoins;
    final corrDb = ddbPercent.abs() * kDb;

    final kV0 = deltaV0 >= 0 ? j.v0Plus : j.v0Moins;
    final corrV0 = deltaV0.abs() * kV0;

    final rtcByTemp = await _rtcJbisInterpolated(
      typeAssets,
      charge,
      tempsEntreeS,
    );
    final corrRtc = _interpByTemp(rtcByTemp, tempMunitionC);

    // Pas d'arrondis intermédiaires : l'application conserve les valeurs
    // interpolées continues. Les arrondis de l'exercice restent uniquement
    // des valeurs de comparaison.
    final dcfs = corrVent + corrTb + corrDb + corrV0 + corrRtc;

    final corrDz = correctionDeniveleePar100mS * (deniveleeM.abs() / 100.0);

    final finalS = tempsNominalViserS + dcfs + corrDz;

    final eventRef = _roundToInt(tempsEntreeS);

    if (kDebugMode) {
      debugPrint(
        '[Tempage BONUS] DSPD entrée=${tempsEntreeS.toStringAsFixed(3)}s '
        'J/Jbis interpolés autour de $eventRef s',
      );
      debugPrint(
        '[Tempage BONUS] '
        'vent=${corrVent.toStringAsFixed(3)} '
        'tb=${corrTb.toStringAsFixed(3)} '
        'db=${corrDb.toStringAsFixed(3)} '
        'v0=${corrV0.toStringAsFixed(3)} '
        'rtc=${corrRtc.toStringAsFixed(3)} '
        'dcfs=${dcfs.toStringAsFixed(3)}',
      );
      debugPrint(
        '[Tempage BONUS] DSPD(visée)=${tempsNominalViserS.toStringAsFixed(3)} '
        'kDz/100m=${correctionDeniveleePar100mS.toStringAsFixed(3)} '
        'ΔZ=${deniveleeM.toStringAsFixed(1)}m '
        'corrDz=${corrDz.toStringAsFixed(3)} '
        'final=${finalS.toStringAsFixed(3)}',
      );
    }

    return TempageResult(
      eventRefSeconds: eventRef,
      dcfsSeconds: dcfs,
      tempageNominalViserS: tempsNominalViserS,
      eclDzSeconds: corrDz,
      tempageFinalS: finalS,
      corrVent: corrVent,
      corrTb: corrTb,
      corrDb: corrDb,
      corrV0: corrV0,
      corrMasse: 0.0,
      corrRtc: corrRtc,
      corrDz: corrDz,
    );
  }

  Future<double> _tempageF(
    String type,
    String charge,
    double distance, {
    required bool tirMontagne,
  }) async {
    final rows = await _loadF(type, charge);

    final pts = rows
        .where((r) => r.tirMontagne == tirMontagne)
        .map((r) => _Pt(r.distanceM, r.tempageS))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return _interp(pts, distance) ?? 0.0;
  }

  /// Retourne le tempage nominal FUCHSIA interpolé depuis le tableau ECL
  /// (champ de tempage ECL de l'ECLTBL_V2).
  ///
  /// N'est appelé que pour ART385 avec la fusée FUCHSIA.
  /// Pour les tables ECL V1 (qui ne contiennent pas ce champ), une exception
  /// est levée afin de signaler explicitement l'incompatibilité de version.
  Future<double> _tempageEcl(
    String type,
    String charge,
    double distance, {
    required bool tirMontagne,
  }) async {
    final rows = await _loadEcl(type, charge);

    final pts = rows
        .where((r) => r.tirMontagne == tirMontagne && r.tempageS != null)
        .map((r) => _Pt(r.porteeM, r.tempageS!))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    if (pts.isEmpty) {
      throw StateError(
        'Aucune ligne ECL avec tempage ECL disponible '
        'pour type=${_canonType(type)} charge=$charge '
        'tirMontagne=$tirMontagne. '
        'Vérifiez que le fichier ECL est au format ECLTBL_V2.',
      );
    }

    return _interp(pts, distance) ?? 0.0;
  }

  Future<_JCoeffs> _coeffsJInterpolated(
    String type,
    String charge,
    double eventSeconds,
  ) async {
    final rows = await _loadJ(type, charge);

    if (rows.isEmpty) {
      return const _JCoeffs.zero();
    }

    rows.sort((a, b) => a.tempageS.compareTo(b.tempageS));

    if (eventSeconds <= rows.first.tempageS) {
      return _jCoeffsFromRow(rows.first);
    }

    if (eventSeconds >= rows.last.tempageS) {
      return _jCoeffsFromRow(rows.last);
    }

    for (var i = 1; i < rows.length; i++) {
      final b = rows[i];

      if (eventSeconds <= b.tempageS) {
        final a = rows[i - 1];
        final span = b.tempageS - a.tempageS;

        if (span == 0.0) {
          return _jCoeffsFromRow(a);
        }

        final u = (eventSeconds - a.tempageS) / span;

        double lerp(double x0, double x1) => x0 + (x1 - x0) * u;

        return _JCoeffs(
          v0Moins: lerp(a.correctionV0Moins, b.correctionV0Moins),
          v0Plus: lerp(a.correctionV0Plus, b.correctionV0Plus),
          ventMoins: lerp(a.correctionVentMoins, b.correctionVentMoins),
          ventPlus: lerp(a.correctionVentPlus, b.correctionVentPlus),
          tempMoins: lerp(a.correctionTempMoins, b.correctionTempMoins),
          tempPlus: lerp(a.correctionTempPlus, b.correctionTempPlus),
          pressionMoins: lerp(
            a.correctionPressionMoins,
            b.correctionPressionMoins,
          ),
          pressionPlus: lerp(
            a.correctionPressionPlus,
            b.correctionPressionPlus,
          ),
          masseMoins: lerp(a.correctionMasseMoins, b.correctionMasseMoins),
          massePlus: lerp(a.correctionMassePlus, b.correctionMassePlus),
        );
      }
    }

    return _jCoeffsFromRow(rows.last);
  }

  _JCoeffs _jCoeffsFromRow(_JRow row) {
    return _JCoeffs(
      v0Moins: row.correctionV0Moins,
      v0Plus: row.correctionV0Plus,
      ventMoins: row.correctionVentMoins,
      ventPlus: row.correctionVentPlus,
      tempMoins: row.correctionTempMoins,
      tempPlus: row.correctionTempPlus,
      pressionMoins: row.correctionPressionMoins,
      pressionPlus: row.correctionPressionPlus,
      masseMoins: row.correctionMasseMoins,
      massePlus: row.correctionMassePlus,
    );
  }

  Future<Map<double, double>> _rtcJbisInterpolated(
    String type,
    String charge,
    double eventSeconds,
  ) async {
    final rows = await _loadJbis(type, charge);

    if (rows.isEmpty) {
      return const <double, double>{};
    }

    rows.sort((a, b) => a.tempageS.compareTo(b.tempageS));

    if (eventSeconds <= rows.first.tempageS) {
      return Map<double, double>.from(rows.first.corrByTemp);
    }

    if (eventSeconds >= rows.last.tempageS) {
      return Map<double, double>.from(rows.last.corrByTemp);
    }

    for (var i = 1; i < rows.length; i++) {
      final b = rows[i];

      if (eventSeconds <= b.tempageS) {
        final a = rows[i - 1];
        final span = b.tempageS - a.tempageS;

        if (span == 0.0) {
          return Map<double, double>.from(a.corrByTemp);
        }

        final u = (eventSeconds - a.tempageS) / span;
        final keys = <double>{...a.corrByTemp.keys, ...b.corrByTemp.keys};
        final out = <double, double>{};

        for (final key in keys) {
          final va = a.corrByTemp[key];
          final vb = b.corrByTemp[key];

          if (va != null && vb != null) {
            out[key] = va + (vb - va) * u;
          } else if (va != null) {
            out[key] = va;
          } else if (vb != null) {
            out[key] = vb;
          }
        }

        return out;
      }
    }

    return Map<double, double>.from(rows.last.corrByTemp);
  }

  Future<_JCoeffs> _coeffsJ(
    String type,
    String charge,
    int eventRef, {
    required TypeFusee fusee,
  }) async {
    final rows = await _loadJ(type, charge, fusee: fusee);

    if (rows.isEmpty) {
      return const _JCoeffs.zero();
    }

    final row = rows.reduce(
      (a, b) => (a.tempageS - eventRef).abs() <= (b.tempageS - eventRef).abs()
          ? a
          : b,
    );

    return _JCoeffs(
      v0Moins: row.correctionV0Moins,
      v0Plus: row.correctionV0Plus,
      ventMoins: row.correctionVentMoins,
      ventPlus: row.correctionVentPlus,
      tempMoins: row.correctionTempMoins,
      tempPlus: row.correctionTempPlus,
      pressionMoins: row.correctionPressionMoins,
      pressionPlus: row.correctionPressionPlus,
      masseMoins: row.correctionMasseMoins,
      massePlus: row.correctionMassePlus,
    );
  }

  Future<Map<double, double>> _rtcJbis(
    String type,
    String charge,
    int eventRef,
  ) async {
    final rows = await _loadJbis(type, charge);

    if (rows.isEmpty) {
      return const <double, double>{};
    }

    final row = rows.reduce(
      (a, b) => (a.tempageS - eventRef).abs() <= (b.tempageS - eventRef).abs()
          ? a
          : b,
    );

    return row.corrByTemp;
  }

  Future<double> _eclEventPer50(
    String type,
    String charge,
    double distance, {
    required bool tirMontagne,
  }) async {
    final rows = await _loadEcl(type, charge);

    final pts = rows
        .where(
          (r) => r.tirMontagne == tirMontagne && r.corrTempageS != null,
        )
        .map((r) => _Pt(r.porteeM, r.corrTempageS!))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return _interp(pts, distance) ?? 0.0;
  }

  Future<List<_FRow>> _loadF(String type, String charge) async {
    final encryptedPath = _encryptedTablePath(
      famille: 'F',
      type: type,
      charge: charge,
      extension: 'ftbl',
    );

    final compressed = await _loadSecureCompressedEncrypted(encryptedPath);
    final raw = Uint8List.fromList(gzip.decode(compressed));

    const headerSize = 9;
    const rowSize = 75;

    final bd = ByteData.sublistView(raw);
    final magic = String.fromCharCodes(raw.sublist(0, 4));

    if (magic != 'FTBL') {
      throw FormatException('Magic FTBL invalide : $magic');
    }

    final version = bd.getUint8(4);
    if (version != 1) {
      throw FormatException('Version FTBL invalide : $version');
    }

    final rowCount = bd.getUint32(5, Endian.little);
    final expected = headerSize + rowCount * rowSize;

    if (raw.length != expected) {
      throw FormatException(
        'FTBL taille invalide : '
        '${raw.length}/$expected',
      );
    }

    final rows = <_FRow>[];

    for (var i = 0; i < rowCount; i++) {
      final o = headerSize + i * rowSize;
      final distance = bd.getFloat32(o, Endian.little);
      final tempage = bd.getFloat32(o + 60, Endian.little);
      final flags = bd.getUint8(o + 68);

      rows.add(
        _FRow(
          distanceM: distance,
          tempageS: tempage,
          tirMontagne: (flags & 0x01) != 0,
        ),
      );
    }

    return rows;
  }

  Future<List<_JRow>> _loadJ(
    String type,
    String charge, {
    TypeFusee? fusee,
  }) async {
    final encryptedPath = _encryptedTablePath(
      famille: 'J',
      type: type,
      charge: charge,
      extension: 'jtbl',
    );

    final compressed = await _loadSecureCompressedEncrypted(encryptedPath);
    final raw = Uint8List.fromList(gzip.decode(compressed));
    final bd = ByteData.sublistView(raw);

    var o = 0;

    void requireBytes(int count, String what) {
      if (count < 0 || o + count > raw.length) {
        throw FormatException(
          'JTBL tronqué pendant la lecture de $what '
          '(offset=$o, besoin=$count, taille=${raw.length})',
        );
      }
    }

    String readMagic() {
      requireBytes(4, 'magic');
      final v = String.fromCharCodes(raw.sublist(o, o + 4));
      o += 4;
      return v;
    }

    int readU8() {
      requireBytes(1, 'uint8');
      return bd.getUint8(o++);
    }

    int readU32() {
      requireBytes(4, 'uint32');
      final v = bd.getUint32(o, Endian.little);
      o += 4;
      return v;
    }

    double readF32() {
      requireBytes(4, 'float32');
      final v = bd.getFloat32(o, Endian.little);
      o += 4;
      return v;
    }

    String readUtf8(int length) {
      requireBytes(length, 'nom sous-table');
      final bytes = raw.sublist(o, o + length);
      o += length;
      return utf8.decode(bytes, allowMalformed: false);
    }

    List<_JRow> readRows(int rowCount, String context) {
      const rowSize = 44;
      final requiredBytes = rowCount * rowSize;

      if (requiredBytes > raw.length - o) {
        throw FormatException(
          '$context tronqué : $rowCount ligne(s) exigent '
          '$requiredBytes octets, mais ${raw.length - o} restent disponibles',
        );
      }

      final rows = <_JRow>[];
      double? previousTempage;

      for (var i = 0; i < rowCount; i++) {
        final row = _JRow(
          tempageS: readF32(),
          correctionV0Moins: readF32(),
          correctionV0Plus: readF32(),
          correctionVentMoins: readF32(),
          correctionVentPlus: readF32(),
          correctionTempMoins: readF32(),
          correctionTempPlus: readF32(),
          correctionPressionMoins: readF32(),
          correctionPressionPlus: readF32(),
          correctionMasseMoins: readF32(),
          correctionMassePlus: readF32(),
        );

        final values = <double>[
          row.tempageS,
          row.correctionV0Moins,
          row.correctionV0Plus,
          row.correctionVentMoins,
          row.correctionVentPlus,
          row.correctionTempMoins,
          row.correctionTempPlus,
          row.correctionPressionMoins,
          row.correctionPressionPlus,
          row.correctionMasseMoins,
          row.correctionMassePlus,
        ];

        if (values.any((v) => !v.isFinite)) {
          throw FormatException(
            '$context contient une valeur non finie à la ligne $i',
          );
        }

        if (previousTempage != null && row.tempageS <= previousTempage) {
          throw FormatException(
            '$context : tempages non strictement croissants '
            'à la ligne $i (${row.tempageS} <= $previousTempage)',
          );
        }

        previousTempage = row.tempageS;
        rows.add(row);
      }

      return rows;
    }

    final magic = readMagic();
    if (magic != 'JTBL') {
      throw FormatException('Magic JTBL invalide : $magic');
    }

    final version = readU8();

    // JTBL V1 historique : une seule table, aucune notion de fusée.
    if (version == 1) {
      readU8(); // subtype historique
      final rowCount = readU32();
      final out = readRows(rowCount, 'JTBL_V1');

      if (o != raw.length) {
        throw FormatException(
          'JTBL_V1 contient ${raw.length - o} octet(s) résiduel(s)',
        );
      }

      return out;
    }

    if (version != 2) {
      throw FormatException('Version JTBL invalide : $version');
    }

    // JTBL V2 :
    // version, flags, nombreSousTables, reserved,
    // puis [longueurNom, nom UTF-8, nombreLignes, lignes].
    final flags = readU8();
    final subTableCount = readU8();
    final reserved = readU8();

    if (flags != 0) {
      throw FormatException('Flags JTBL_V2 non supportés : $flags');
    }

    if (reserved != 0) {
      throw FormatException('Reserved JTBL_V2 invalide : $reserved');
    }

    if (subTableCount < 1 || subTableCount > 2) {
      throw FormatException(
        'Nombre de sous-tables JTBL_V2 invalide : $subTableCount',
      );
    }

    final canonicalType = _canonType(type);
    final bool isArt385 = canonicalType == 'OECL_ART385';

    // ART385 possède deux sous-tables sélectionnées par fusée.
    // Les JTBL_V2 historiques (ART392, BONUS, etc.) restent mono-table
    // et sont encodés sous le nom DEFAULT.
    final String wanted = isArt385 ? _jtblSubTableForFusee(fusee) : 'DEFAULT';

    final List<String> canonicalOrder = isArt385
        ? const <String>['FU_DE_F2', 'FUCHSIA']
        : const <String>['DEFAULT'];

    final seen = <String>{};
    var previousCanonicalIndex = -1;
    List<_JRow>? selected;

    for (var tableIndex = 0; tableIndex < subTableCount; tableIndex++) {
      final nameLength = readU8();

      if (nameLength == 0) {
        throw FormatException(
          'Nom de sous-table JTBL_V2 vide à l\'index $tableIndex',
        );
      }

      final name = readUtf8(nameLength);

      if (!canonicalOrder.contains(name)) {
        throw FormatException('Sous-table JTBL_V2 inconnue : "$name"');
      }

      if (!seen.add(name)) {
        throw FormatException('Sous-table JTBL_V2 dupliquée : "$name"');
      }

      final canonicalIndex = canonicalOrder.indexOf(name);
      if (canonicalIndex <= previousCanonicalIndex) {
        throw FormatException('Ordre JTBL_V2 non canonique : "$name"');
      }
      previousCanonicalIndex = canonicalIndex;

      final rowCount = readU32();
      if (rowCount == 0) {
        throw FormatException('Sous-table JTBL_V2 "$name" vide');
      }

      final rows = readRows(rowCount, 'JTBL_V2/$name');

      if (name == wanted) {
        selected = rows;
      }
    }

    if (o != raw.length) {
      throw FormatException(
        'JTBL_V2 contient ${raw.length - o} octet(s) résiduel(s)',
      );
    }

    if (selected == null) {
      throw FormatException(
        'Sous-table JTBL_V2 "$wanted" absente '
        '(présentes : ${seen.join(", ")})',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[TEMPAGE] JTBL_V2 type=${_canonType(type)} '
        'charge=${charge.trim().toUpperCase()} fusee=$wanted '
        'rows=${selected.length}',
      );
    }

    return selected;
  }

  String _jtblSubTableForFusee(TypeFusee? fusee) {
    return switch (fusee) {
      TypeFusee.fuchsia => 'FUCHSIA',
      TypeFusee.fuDeF2 => 'FU_DE_F2',

      // Cette fonction n'est utilisée que pour ART385.
      // Toute autre fusée est normalisée vers la référence FU DE F2.
      //
      // Les fusées MO120 sont listées ici uniquement pour rendre le switch
      // exhaustif ; elles ne doivent pas être routées vers ART385 en usage normal.
      TypeFusee.frappe ||
      TypeFusee.ralec ||
      TypeFusee.fuRalec120F4 ||
      TypeFusee.pdm557 ||
      TypeFusee.fr55B ||
      null =>
        'FU_DE_F2',
    };
  }

  Future<List<_JbisRow>> _loadJbis(String type, String charge) async {
    final t = _canonType(type);
    final ch = charge.trim().toUpperCase();

    // Convention historique conservée : JBIS_APPUI_CHx.jbistbl.gz.
    // Pour MO/MEPAC, le résolveur standard produirait MO_Jbis_APPUI_CHx,
    // alors que le lecteur attend JBIS_* ; on construit donc explicitement.
    final encryptedPath = switch (systeme) {
      SystemeArme.caesar =>
        'assets/secure_enc/tableaux/Jbis/JBIS_${t}_$ch.jbistbl.gz.enc',
      SystemeArme.mo =>
        'assets/secure_enc/tableaux/MO/Jbis/MO_JBIS_${t}_$ch.jbistbl.gz.enc',
      SystemeArme.mepac =>
        'assets/secure_enc/tableaux/MEPAC/Jbis/MEPAC_JBIS_${t}_$ch.jbistbl.gz.enc',
    };

    final compressed = await _loadSecureCompressedEncrypted(encryptedPath);
    final raw = Uint8List.fromList(gzip.decode(compressed));
    final bd = ByteData.sublistView(raw);

    var o = 0;

    String readMagic() {
      final v = String.fromCharCodes(raw.sublist(o, o + 4));
      o += 4;
      return v;
    }

    int readU8() => bd.getUint8(o++);

    int readI16() {
      final v = bd.getInt16(o, Endian.little);
      o += 2;
      return v;
    }

    int readU32() {
      final v = bd.getUint32(o, Endian.little);
      o += 4;
      return v;
    }

    double readF32() {
      final v = bd.getFloat32(o, Endian.little);
      o += 4;
      return v;
    }

    final magic = readMagic();
    if (magic != 'JBIS') {
      throw FormatException('Magic JBIS invalide : $magic');
    }

    final version = readU8();
    if (version != 1) {
      throw FormatException('Version JBIS invalide : $version');
    }

    final tempCount = readU8();
    final rows = readU32();

    final temps = <int>[];

    for (var i = 0; i < tempCount; i++) {
      temps.add(readI16());
    }

    final out = <_JbisRow>[];

    for (var r = 0; r < rows; r++) {
      final tempage = readF32();
      final values = <double, double>{};

      for (final temp in temps) {
        values[temp.toDouble()] = readF32();
      }

      out.add(_JbisRow(tempageS: tempage, corrByTemp: values));
    }

    return out;
  }

  // ── _loadEcl : support ECLTBL V1 (historique) et V2 (nouveau format) ──────
  //
  // V1 (rowSize=13) : portee uint16 | hausse int32 | corrHausse int16
  //                   | corrEvent int16 | flags uint8 | reserved uint16
  //
  // V2 (rowSize=25) : portee*10 uint32 | hausse*100 int32
  //                   | eventFuchsia*100 int32 | corrHausse*100 int16
  //                   | corrEvent*100 int16 | dist1erDepotage uint32
  //                   | porteeNonFonctionnement uint32 | flags uint8
  //
  // Flags V2 :
  //   bit 0 (0x01) : tirMontagne
  //   bit 1 (0x02) : corrHausse est null
  //   bit 2 (0x04) : corrEvent est null
  Future<List<_EclRow>> _loadEcl(String type, String charge) async {
    final t = _canonType(type);
    final ch = charge.trim().toUpperCase();

    // Convention historique ECL conservée.
    final encryptedPath = switch (systeme) {
      SystemeArme.caesar =>
        'assets/secure_enc/tableaux/ECL/ECL_${t}_$ch.ecltbl.gz.enc',
      SystemeArme.mo =>
        'assets/secure_enc/tableaux/MO/ECL/MO_ECL_${t}_$ch.ecltbl.gz.enc',
      SystemeArme.mepac =>
        'assets/secure_enc/tableaux/MEPAC/ECL/MEPAC_ECL_${t}_$ch.ecltbl.gz.enc',
    };

    final compressed = await _loadSecureCompressedEncrypted(encryptedPath);
    final raw = Uint8List.fromList(gzip.decode(compressed));

    const headerSize = 9;

    final bd = ByteData.sublistView(raw);
    final magic = String.fromCharCodes(raw.sublist(0, 4));

    if (magic != 'ECLT') {
      throw FormatException('Magic ECLT invalide : $magic');
    }

    final version = bd.getUint8(4);
    final rowCount = bd.getUint32(5, Endian.little);

    // ── V1 : format historique (rowSize = 13) ──────────────────────────────
    if (version == 1) {
      const rowSize = 13;
      final expected = headerSize + rowCount * rowSize;

      if (raw.length != expected) {
        throw FormatException(
          'ECLT V1 taille invalide : ${raw.length}/$expected',
        );
      }

      final rows = <_EclRow>[];
      var o = headerSize;

      for (var i = 0; i < rowCount; i++) {
        final portee = bd.getUint16(o, Endian.little);
        o += 2;

        final hausse = bd.getInt32(o, Endian.little);
        o += 4;

        final corrHausse = bd.getInt16(o, Endian.little);
        o += 2;

        final corrEvent = bd.getInt16(o, Endian.little);
        o += 2;

        final flags = bd.getUint8(o);
        o += 1;

        o += 2; // reserved

        rows.add(
          _EclRow(
            formatVersion: 1,
            porteeM: portee.toDouble(),
            hausseMil: hausse / 100.0,
            tempageS: null, // absent en V1
            corrHausseMil: corrHausse / 100.0,
            corrTempageS: corrEvent / 100.0,
            tirMontagne: (flags & 0x01) != 0,
          ),
        );
      }

      return rows;
    }

    // ── V2 : nouveau format avec event_fuchsia_s (rowSize = 25) ───────────
    if (version == 2) {
      const rowSize = 25;
      const flagCorrHausseNull = 0x02;
      const flagCorrEventNull = 0x04;

      final expected = headerSize + rowCount * rowSize;

      if (raw.length != expected) {
        throw FormatException(
          'ECLT V2 taille invalide : ${raw.length}/$expected',
        );
      }

      final rows = <_EclRow>[];
      var o = headerSize;

      for (var i = 0; i < rowCount; i++) {
        final porteeRaw = bd.getUint32(o, Endian.little);
        o += 4;

        final hausseRaw = bd.getInt32(o, Endian.little);
        o += 4;

        final eventFuchsiaRaw = bd.getInt32(o, Endian.little);
        o += 4;

        final corrHausseStored = bd.getInt16(o, Endian.little);
        o += 2;

        final corrEventStored = bd.getInt16(o, Endian.little);
        o += 2;

        // distance_1er_depotage_m et portee_non_fonctionnement_m :
        // non utilisés par le service de tempage, lus pour avancer l'offset.
        o += 4; // distance_1er_depotage_m
        o += 4; // portee_non_fonctionnement_m

        final flags = bd.getUint8(o);
        o += 1;

        final corrHausseMil =
            (flags & flagCorrHausseNull) != 0 ? null : corrHausseStored / 100.0;

        final corrEventS =
            (flags & flagCorrEventNull) != 0 ? null : corrEventStored / 100.0;

        rows.add(
          _EclRow(
            formatVersion: 2,
            porteeM: porteeRaw / 10.0,
            hausseMil: hausseRaw / 100.0,
            tempageS: eventFuchsiaRaw / 100.0,
            corrHausseMil: corrHausseMil,
            corrTempageS: corrEventS,
            tirMontagne: (flags & 0x01) != 0,
          ),
        );
      }

      return rows;
    }

    throw FormatException('Version ECLT non supportée : $version');
  }

  String _canonType(String s) {
    final t = BallisticAssetContext.canonicalizeVariant(s).toUpperCase();

    // Les assets MO portent les types génériques APPUI / OECL, sans suffixe
    // de projectile ART390/ART392. La canonicalisation CAESAR ci-dessous
    // produirait par exemple MO_F_APPUI_ART390_CH7, qui n’existe pas ; le
    // chemin attendu est MO_F_APPUI_CH7 (et de même pour les familles J).
    if (systeme == SystemeArme.mo) {
      return switch (t) {
        'APPUI_ART390' || 'APPUI_ALL' => 'APPUI',
        'OECL_ART392' || 'OECL_ALL' => 'OECL',
        _ => t,
      };
    }

    switch (t) {
      case 'APPUI':
      case 'APPUI_ALL':
        return 'APPUI_ART390';

      case 'OECL':
      case 'OECL_ALL':
        return 'OECL_ART392';

      default:
        return t;
    }
  }

  double? _interp(List<_Pt> pts, double x) {
    if (pts.isEmpty) {
      return null;
    }

    if (x <= pts.first.x) {
      return pts.first.y;
    }

    if (x >= pts.last.x) {
      return pts.last.y;
    }

    for (var i = 1; i < pts.length; i++) {
      if (x <= pts[i].x) {
        final a = pts[i - 1];
        final b = pts[i];
        final u = (x - a.x) / (b.x - a.x);
        return a.y + (b.y - a.y) * u;
      }
    }

    return pts.last.y;
  }

  double _interpByTemp(Map<double, double> values, double tempC) {
    if (values.isEmpty) {
      return 0.0;
    }

    final keys = values.keys.toList()..sort();

    if (tempC <= keys.first) {
      return values[keys.first] ?? 0.0;
    }

    if (tempC >= keys.last) {
      return values[keys.last] ?? 0.0;
    }

    for (var i = 1; i < keys.length; i++) {
      if (tempC <= keys[i]) {
        final t0 = keys[i - 1];
        final t1 = keys[i];

        final v0 = values[t0] ?? 0.0;
        final v1 = values[t1] ?? v0;

        final u = (tempC - t0) / (t1 - t0);

        return v0 + (v1 - v0) * u;
      }
    }

    return 0.0;
  }

  int _roundToInt(double v) {
    return v >= 0 ? (v + 0.5).floor() : (v - 0.5).ceil();
  }

  double _round2(double v) {
    return (v * 100.0).roundToDouble() / 100.0;
  }

  double _round3(double v) {
    return (v * 1000.0).roundToDouble() / 1000.0;
  }
}

class _Pt {
  final double x;
  final double y;

  const _Pt(this.x, this.y);
}

class _FRow {
  final double distanceM;
  final double tempageS;
  final bool tirMontagne;

  const _FRow({
    required this.distanceM,
    required this.tempageS,
    required this.tirMontagne,
  });
}

class _JRow {
  final double tempageS;
  final double correctionV0Moins;
  final double correctionV0Plus;
  final double correctionVentMoins;
  final double correctionVentPlus;
  final double correctionTempMoins;
  final double correctionTempPlus;
  final double correctionPressionMoins;
  final double correctionPressionPlus;
  final double correctionMasseMoins;
  final double correctionMassePlus;

  const _JRow({
    required this.tempageS,
    required this.correctionV0Moins,
    required this.correctionV0Plus,
    required this.correctionVentMoins,
    required this.correctionVentPlus,
    required this.correctionTempMoins,
    required this.correctionTempPlus,
    required this.correctionPressionMoins,
    required this.correctionPressionPlus,
    required this.correctionMasseMoins,
    required this.correctionMassePlus,
  });
}

class _JbisRow {
  final double tempageS;
  final Map<double, double> corrByTemp;

  const _JbisRow({required this.tempageS, required this.corrByTemp});
}

// ── _EclRow : représentation interne unifiée V1 / V2 ─────────────────────────
//
// Les champs absents en V1 (eventFuchsiaS) sont null.
// Les champs marqués null en V2 via les flags (corrHausseMil, corrEventS)
// sont également null.
class _EclRow {
  /// Version du format binaire source (1 ou 2).
  final int formatVersion;

  final double porteeM;
  final double hausseMil;

  /// Tempage nominal FUCHSIA en secondes (ECLTBL_V2 uniquement, null en V1).
  final double? tempageS;

  /// Correction de hausse par +50 m d'éclairement (null si flag absent).
  final double? corrHausseMil;

  /// Correction d'événement par +50 m d'éclairement (null si flag absent).
  final double? corrTempageS;

  final bool tirMontagne;

  const _EclRow({
    required this.formatVersion,
    required this.porteeM,
    required this.hausseMil,
    required this.tempageS,
    required this.corrHausseMil,
    required this.corrTempageS,
    required this.tirMontagne,
  });
}

class _JCoeffs {
  final double v0Moins;
  final double v0Plus;
  final double ventMoins;
  final double ventPlus;
  final double tempMoins;
  final double tempPlus;
  final double pressionMoins;
  final double pressionPlus;
  final double masseMoins;
  final double massePlus;

  const _JCoeffs({
    required this.v0Moins,
    required this.v0Plus,
    required this.ventMoins,
    required this.ventPlus,
    required this.tempMoins,
    required this.tempPlus,
    required this.pressionMoins,
    required this.pressionPlus,
    required this.masseMoins,
    required this.massePlus,
  });

  const _JCoeffs.zero()
      : v0Moins = 0.0,
        v0Plus = 0.0,
        ventMoins = 0.0,
        ventPlus = 0.0,
        tempMoins = 0.0,
        tempPlus = 0.0,
        pressionMoins = 0.0,
        pressionPlus = 0.0,
        masseMoins = 0.0,
        massePlus = 0.0;
}
