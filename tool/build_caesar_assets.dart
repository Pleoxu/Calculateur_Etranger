import 'dart:convert';
import 'dart:io';

import 'secure_assets/builders/btbl_builder.dart';
import 'secure_assets/builders/ctbl_builder.dart';
import 'secure_assets/builders/dtbl_builder.dart';
import 'secure_assets/builders/dspd_builder.dart';
import 'secure_assets/builders/ecl_builder.dart';
import 'secure_assets/builders/etbl_builder.dart';
import 'secure_assets/builders/f3tbl_builder.dart';
import 'secure_assets/builders/ftbl_builder.dart';
import 'secure_assets/builders/gtbl_builder.dart';
import 'secure_assets/builders/htbl_builder.dart';
import 'secure_assets/builders/itbl_builder.dart';
import 'secure_assets/builders/jbistbl_builder.dart';
import 'secure_assets/builders/jtbl_builder.dart';
import 'secure_assets/foreign/profile_asset_pipeline.dart';
import 'secure_assets/table_builder.dart';

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var clean = false;

  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--project':
        if (i + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++i]);
      case '--clean':
        clean = true;
      case '--help':
      case '-h':
        stdout.writeln(
          'Usage: dart run tool/build_caesar_assets.dart '
          '[--project PATH] [--clean]',
        );
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[i]}');
    }
  }

  project = Directory(project.absolute.path);

  final builders = <TableBuilder>[
    BtblBuilder(),
    CtblBuilder(),
    DtblBuilder(),
    DspdBuilder(),
    EtblBuilder(),
    EclBuilder(),
    FtblBuilder(),
    F3tblBuilder(),
    GtblBuilder(),
    HtblBuilder(),
    ItblBuilder(),
    JtblBuilder(),
    JbistblBuilder(),
  ];

  final pipeline = ForeignProfileAssetPipeline(
    systemSlug: 'caesar',
    platformLabel: 'CAESAR',
    project: project,
    builders: builders,
  );

  final entries = await pipeline.buildAll(clean: clean);
  final clearRoot = Directory('${project.path}/assets/secure');
  await clearRoot.create(recursive: true);

  final fragment = File(
    '${clearRoot.path}/manifest_foreign_caesar_profiles.json',
  );
  await fragment.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
    flush: true,
  );

  stdout.writeln('CAESAR profile assets built: ${entries.length}');
  stdout.writeln('Manifest fragment: ${fragment.path}');
  stdout.writeln(
    'Next: dart run tool/merge_encrypt_caesar_assets.dart '
    '--fragment ${fragment.uri.pathSegments.last}',
  );
}
