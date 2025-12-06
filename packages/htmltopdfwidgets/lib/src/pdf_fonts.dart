import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:pdf/widgets.dart';

class PdfFonts {
  static Future<Font> amiri() async {
    final uri = Uri.parse('package:htmltopdfwidgets/fonts/Amiri-Regular.ttf');
    final resolved = await Isolate.resolvePackageUri(uri);
    if (resolved == null) {
      throw Exception('Could not resolve package URI: $uri');
    }
    final bytes = await File.fromUri(resolved).readAsBytes();
    return Font.ttf(bytes.buffer.asByteData());
  }

  static Future<Font> notoColorEmoji() async {
    final uri = Uri.parse('package:htmltopdfwidgets/fonts/NotoColorEmoji.ttf');
    final resolved = await Isolate.resolvePackageUri(uri);
    if (resolved == null) {
      throw Exception('Could not resolve package URI: $uri');
    }
    final bytes = await File.fromUri(resolved).readAsBytes();
    return Font.ttf(bytes.buffer.asByteData());
  }
}
