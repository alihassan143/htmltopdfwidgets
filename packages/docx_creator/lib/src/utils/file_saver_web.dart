import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Web implementation of FileSaver
class FileSaver {
  static Future<void> save(String filePath, Uint8List bytes) async {
    // Determine filename from path, default to 'document.docx'
    final filename = filePath.split('/').last.isEmpty
        ? 'document.docx'
        : filePath.split('/').last;

    String url = URL.createObjectURL(
      Blob(
        <JSUint8Array>[bytes.toJS].toJS,
        BlobPropertyBag(
            type:
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
      ),
    );

    Document htmlDocument = document;
    HTMLAnchorElement anchor =
        htmlDocument.createElement('a') as HTMLAnchorElement;
    anchor.href = url;
    anchor.style.display = filename;
    anchor.download = filename;
    document.body!.add(anchor);
    anchor.click();
    anchor.remove();
  }
}
