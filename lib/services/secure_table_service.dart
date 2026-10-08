import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

import 'secure_asset_resolver.dart';

class SecureTableService {
  final SecureAssetResolver resolver;

  const SecureTableService({this.resolver = const SecureAssetResolver()});

  String encryptedPath({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
    required String extension,
  }) {
    return 'assets/secure_enc/${resolver.encryptedAsset(systeme: systeme, famille: famille, typeTir: typeTir, charge: charge, extension: extension)}';
  }

  String clearPath({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
    required String extension,
  }) {
    return 'assets/secure/${resolver.clearAsset(systeme: systeme, famille: famille, typeTir: typeTir, charge: charge, extension: extension)}';
  }

  Future<Uint8List> loadDecompressed({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
    required String extension,
  }) async {
    final path = encryptedPath(
      systeme: systeme,
      famille: famille,
      typeTir: typeTir,
      charge: charge,
      extension: extension,
    );

    return loadDecompressedFromPath(path);
  }

  Future<Uint8List> loadDecompressedFromPath(String encryptedPath) async {
    final compressed = await NativeSecureAssets.decryptAsset(encryptedPath);
    return Uint8List.fromList(gzip.decode(compressed));
  }
}
