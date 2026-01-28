import 'dart:typed_data';

/// Abstract class to load file bytes conditionally.
abstract class FileLoader {
  static FileLoader get instance {
    throw UnimplementedError('FileLoader is not implemented on this platform');
  }

  Future<Uint8List?> loadBytes(String path);
  Future<bool> exists(String path);
}
