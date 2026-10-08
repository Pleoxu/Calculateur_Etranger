import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

import 'm252_profile.dart';
import 'm252_table_codec.dart';

typedef M252AssetDecryptor = Future<Uint8List> Function(String assetPath);

/// Loads the five tables belonging to one immutable M252 profile.
///
/// The default is the qualified Part-6 / CH3 profile. Assets always reside
/// below `foreign/m252/profiles/<profile>/`; a repository cannot mix tables
/// from different M252 reference sets.
class M252TableRepository {
  M252TableRepository({
    this.profile = M252Profiles.m821M734Ch3,
    M252AssetDecryptor? decryptAsset,
  }) : _decryptAsset = decryptAsset ?? NativeSecureAssets.decryptAsset;

  /// Compatibility paths for tests and callers using the default CH3 profile.
  static const String windPath =
      'assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/A/A.aebtl.gz.enc';
  static const String airDensityPath =
      'assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/B/B.bebtl.gz.enc';
  static const String powderTemperaturePath =
      'assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/C/C_CH3.cebtl.gz.enc';
  static const String trajectoryPath =
      'assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/D/D_CH3.debtl.gz.enc';
  static const String dispersionPath =
      'assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/E/E_CH3.eebtl.gz.enc';

  final M252Profile profile;
  final M252AssetDecryptor _decryptAsset;
  Future<M252ReferenceTables>? _loadFuture;

  Future<M252ReferenceTables> load() {
    return _loadFuture ??= _load();
  }

  void clearCache() {
    _loadFuture = null;
  }

  Future<M252ReferenceTables> _load() async {
    if (!profile.runtimeQualified) {
      throw UnsupportedError(
        'M252 profile ${profile.id} is staged but not qualified for runtime use.',
      );
    }
    final payloads = await Future.wait<Uint8List>([
      _loadCompressed(profile.encryptedPath('A')),
      _loadCompressed(profile.encryptedPath('B')),
      _loadCompressed(profile.encryptedPath('C')),
      _loadCompressed(profile.encryptedPath('D')),
      _loadCompressed(profile.encryptedPath('E')),
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
