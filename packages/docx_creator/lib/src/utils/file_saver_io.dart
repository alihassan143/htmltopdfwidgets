import 'dart:io';
import 'dart:typed_data';

/// IO implementation of FileSaver
class FileSaver {
  static Future<void> save(String filePath, Uint8List bytes) async {
    final file = File(filePath);
    await file.writeAsBytes(bytes);
  }
}
