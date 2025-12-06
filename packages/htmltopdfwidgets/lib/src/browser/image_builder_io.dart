import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'css_style.dart';
import 'render_node.dart';

/// Maps ObjectFit enum to pdf BoxFit
pw.BoxFit _mapObjectFit(ObjectFit? objectFit) {
  switch (objectFit) {
    case ObjectFit.contain:
      return pw.BoxFit.contain;
    case ObjectFit.cover:
      return pw.BoxFit.cover;
    case ObjectFit.fill:
      return pw.BoxFit.fill;
    case ObjectFit.fitWidth:
      return pw.BoxFit.fitWidth;
    case ObjectFit.fitHeight:
      return pw.BoxFit.fitHeight;
    case ObjectFit.none:
      return pw.BoxFit.none;
    case ObjectFit.scaleDown:
      return pw.BoxFit.scaleDown;
    default:
      return pw.BoxFit.contain;
  }
}

/// Builds an image widget for IO platforms (mobile, desktop).
/// Supports Base64, Network, and Local File images.
/// Enhanced with object-fit, border-radius, and styling support.
Future<pw.Widget> buildImage(RenderNode node) async {
  final src = node.attributes['src'];
  final alt = node.attributes['alt'] ?? 'Image';

  if (src == null || src.isEmpty) {
    return pw.Container(
      width: node.style.width ?? 100,
      height: node.style.height ?? 100,
      margin: node.style.margin ?? const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: node.style.borderRadius != null
            ? pw.BorderRadius.circular(node.style.borderRadius!)
            : null,
      ),
      child: pw.Center(
        child: pw.Text(
          alt,
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
        ),
      ),
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
    } else {
      // Local file
      final file = File(src);
      if (await file.exists()) {
        imageBytes = await file.readAsBytes();
      }
    }

    if (imageBytes != null) {
      final boxFit = _mapObjectFit(node.style.objectFit);

      // Build decoration if needed
      pw.BoxDecoration? decoration;
      if (node.style.border != null || node.style.borderRadius != null) {
        decoration = pw.BoxDecoration(
          border: node.style.border,
          borderRadius: node.style.borderRadius != null
              ? pw.BorderRadius.circular(node.style.borderRadius!)
              : null,
        );
      }

      return pw.Container(
        width: node.style.width,
        height: node.style.height,
        margin: node.style.margin ?? const pw.EdgeInsets.only(bottom: 8),
        decoration: decoration,
        child: pw.ClipRRect(
          horizontalRadius: node.style.borderRadius ?? 0,
          verticalRadius: node.style.borderRadius ?? 0,
          child: pw.Image(pw.MemoryImage(imageBytes), fit: boxFit),
        ),
      );
    }
  } catch (e) {
    // Ignore error
  }

  // Error fallback with alt text
  return pw.Container(
    width: node.style.width ?? 100,
    height: node.style.height ?? 50,
    margin: node.style.margin ?? const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey200,
      borderRadius: node.style.borderRadius != null
          ? pw.BorderRadius.circular(node.style.borderRadius!)
          : null,
    ),
    child: pw.Center(
      child: pw.Text(
        '$alt (Error)',
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
      ),
    ),
  );
}
