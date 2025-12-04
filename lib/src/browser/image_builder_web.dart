import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'render_node.dart';

/// Builds an image widget for Web platforms.
/// Supports Base64 and Network images.
Future<pw.Widget> buildImage(RenderNode node) async {
  final src = node.attributes['src'];
  if (src == null || src.isEmpty) {
    return pw.Container(
      width: node.style.width ?? 100,
      height: node.style.height ?? 100,
      color: PdfColors.grey300,
      child: pw.Center(child: pw.Text('Image: No Source')),
    );
  }

  try {
    Uint8List? imageBytes;

    if (src.startsWith('data:image/')) {
      final components = src.split(',');
      if (components.length > 1) {
        final base64Encoded = components.last;
        imageBytes = base64Decode(base64Encoded);
      }
    } else if (src.startsWith('http')) {
      final response = await http.get(Uri.parse(src));
      if (response.statusCode == 200) {
        imageBytes = response.bodyBytes;
      }
    }
    // No local file support on web

    if (imageBytes != null) {
      return pw.Container(
        width: node.style.width,
        height: node.style.height,
        child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
      );
    }
  } catch (e) {
    // Ignore error
  }

  return pw.Container(
    width: node.style.width ?? 100,
    height: node.style.height ?? 100,
    color: PdfColors.grey300,
    child: pw.Center(child: pw.Text('Image Error')),
  );
}
