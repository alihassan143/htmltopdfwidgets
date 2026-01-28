import 'dart:typed_data';

import 'file_loader.dart';

class FileLoaderImpl implements FileLoader {
  @override
  Future<Uint8List?> loadBytes(String path) async {
    // Web cannot load arbitrary files from disk path
    return null;
  }

  @override
  Future<bool> exists(String path) async {
    return false;
  }
}

FileLoader getFileLoader() => FileLoaderImpl();
