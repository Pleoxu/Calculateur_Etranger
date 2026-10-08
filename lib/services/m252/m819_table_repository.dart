import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';

import 'm819_profile.dart';
import 'm819_table_codec.dart';

typedef M819AssetDecryptor = Future<Uint8List> Function(String assetPath);

/// Loads the six inseparable RP M819 / M772 tables of one charge profile.
class M819TableRepository {
  M819TableRepository({
    this.profile = M819Profiles.m819M772Ch3,
    M819AssetDecryptor? decryptAsset,
  }) : _decryptAsset = decryptAsset ?? NativeSecureAssets.decryptAsset;

  final M819Profile profile;
  final M819AssetDecryptor _decryptAsset;
  Future<M819ReferenceTables>? _loadFuture;

  Future<M819ReferenceTables> load() => _loadFuture ??= _load();

  void clearCache() => _loadFuture = null;

  Future<M819ReferenceTables> _load() async {
    final payloads = await Future.wait<Uint8List>([
      for (final id in const <String>['A', 'B', 'C', 'D', 'E', 'F'])
        _loadCompressed(profile.encryptedPath(id)),
    ]);
    return M819ReferenceTables(
      wind: M252TableCodec.decodeWind(payloads[0]),
      airDensity: M252TableCodec.decodeAirDensity(payloads[1]),
      powderTemperature: M252TableCodec.decodePowderTemperature(payloads[2]),
      trajectory: M819TableCodec.decodeTrajectory(payloads[3]),
      effects: M819TableCodec.decodeEffects(payloads[4]),
      fuzeFactors: M819TableCodec.decodeFuzeFactors(payloads[5]),
    );
  }

  Future<Uint8List> _loadCompressed(String assetPath) async {
    final encrypted = await _decryptAsset(assetPath);
    try {
      return Uint8List.fromList(gzip.decode(encrypted));
    } on Object catch (error) {
      throw FormatException(
        'M819 secure asset is not a valid gzip payload ($assetPath): $error',
      );
    }
  }
}
