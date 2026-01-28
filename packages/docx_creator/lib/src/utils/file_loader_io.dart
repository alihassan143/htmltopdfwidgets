import 'dart:io';
import 'dart:typed_data';

import 'file_loader.dart';

class FileLoaderImpl implements FileLoader {
  @override
  Future<Uint8List?> loadBytes(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<bool> exists(String path) async {
    return await File(path).exists();
  }
}

FileLoader getFileLoader() => FileLoaderImpl();
