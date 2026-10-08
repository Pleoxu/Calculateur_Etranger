import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

import 'm252_table_codec.dart';

typedef M252AssetDecryptor = Future<Uint8List> Function(String assetPath);

/// Loads the validated M252 Part 6 / CH3 reference tables.
///
/// The source is shared by M821A1/M734 and M821A2/M734A1.
///
/// The M252 formats intentionally have their own namespace and codecs. They
/// must not be passed into the French BTBL/CTBL/DTBL/etc. readers.
class M252TableRepository {
  M252TableRepository({M252AssetDecryptor? decryptAsset})
    : _decryptAsset = decryptAsset ?? NativeSecureAssets.decryptAsset;

  static const String windPath =
      'assets/secure_enc/tableaux/foreign/m252/A/A.aebtl.gz.enc';
  static const String airDensityPath =
      'assets/secure_enc/tableaux/foreign/m252/B/B.bebtl.gz.enc';
  static const String powderTemperaturePath =
      'assets/secure_enc/tableaux/foreign/m252/C/C_CH3.cebtl.gz.enc';
  static const String trajectoryPath =
      'assets/secure_enc/tableaux/foreign/m252/D/D_CH3.debtl.gz.enc';
  static const String dispersionPath =
      'assets/secure_enc/tableaux/foreign/m252/E/E_CH3.eebtl.gz.enc';

  final M252AssetDecryptor _decryptAsset;
  Future<M252ReferenceTables>? _loadFuture;

  Future<M252ReferenceTables> load() {
    return _loadFuture ??= _load();
  }

  void clearCache() {
    _loadFuture = null;
  }

  Future<M252ReferenceTables> _load() async {
    final payloads = await Future.wait<Uint8List>([
      _loadCompressed(windPath),
      _loadCompressed(airDensityPath),
      _loadCompressed(powderTemperaturePath),
      _loadCompressed(trajectoryPath),
      _loadCompressed(dispersionPath),
    ]);

    return M252ReferenceTables(
      wind: M252TableCodec.decodeWind(payloads[0]),
      airDensity: M252TableCodec.decodeAirDensity(payloads[1]),
      powderTemperature: M252TableCodec.decodePowderTemperature(payloads[2]),
      trajectory: M252TableCodec.decodeTrajectory(payloads[3]),
      dispersion: M252TableCodec.decodeDispersion(payloads[4]),
    );
  }

  Future<Uint8List> _loadCompressed(String assetPath) async {
    final encrypted = await _decryptAsset(assetPath);
    try {
      return Uint8List.fromList(gzip.decode(encrypted));
    } on Object catch (error) {
      throw FormatException(
        'M252 secure asset is not a valid gzip payload ($assetPath): $error',
      );
    }
  }
}
