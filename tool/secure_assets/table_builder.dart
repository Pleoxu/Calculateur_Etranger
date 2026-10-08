import 'dart:io';

abstract class TableBuilder {
  bool supports(File file);

  Future<Map<String, dynamic>> build(File file, Directory outputDir);
}
