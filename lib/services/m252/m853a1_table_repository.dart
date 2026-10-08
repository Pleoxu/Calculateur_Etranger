import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';

import 'm853a1_profile.dart';
import 'm853a1_table_codec.dart';

typedef M853A1AssetDecryptor = Future<Uint8List> Function(String assetPath);

/// Loads the six inseparable RP M853A1 / M772 tables of one charge profile.
class M853A1TableRepository {
  M853A1TableRepository({
    this.profile = M853A1Profiles.m853a1M772Ch3,
    M853A1AssetDecryptor? decryptAsset,
  }) : _decryptAsset = decryptAsset ?? NativeSecureAssets.decryptAsset;

  final M853A1Profile profile;
  final M853A1AssetDecryptor _decryptAsset;
  Future<M853A1ReferenceTables>? _loadFuture;

  Future<M853A1ReferenceTables> load() => _loadFuture ??= _load();

  void clearCache() => _loadFuture = null;

  Future<M853A1ReferenceTables> _load() async {
    final payloads = await Future.wait<Uint8List>([
      for (final id in const <String>['A', 'B', 'C', 'D', 'E', 'F'])
        _loadCompressed(profile.encryptedPath(id)),
    ]);
    return M853A1ReferenceTables(
      wind: M252TableCodec.decodeWind(payloads[0]),
      airDensity: M252TableCodec.decodeAirDensity(payloads[1]),
      powderTemperature: M252TableCodec.decodePowderTemperature(payloads[2]),
      trajectory: M853A1TableCodec.decodeTrajectory(payloads[3]),
      effects: M853A1TableCodec.decodeEffects(payloads[4]),
      fuzeFactors: M853A1TableCodec.decodeFuzeFactors(payloads[5]),
    );
  }

  Future<Uint8List> _loadCompressed(String assetPath) async {
    final encrypted = await _decryptAsset(assetPath);
    try {
      return Uint8List.fromList(gzip.decode(encrypted));
    } on Object catch (error) {
      throw FormatException(
        'M853A1 secure asset is not a valid gzip payload ($assetPath): $error',
      );
    }
  }
}
