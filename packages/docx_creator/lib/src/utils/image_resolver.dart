import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Result of an image resolution.
class ImageResult {
  final Uint8List bytes;
  final String extension;
  final double width;
  final double height;
  final String altText;

  const ImageResult({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
    required this.altText,
  });
}

/// Utility to resolve images from various sources (URL, Base64, File).
class ImageResolver {
  ImageResolver._();

  static const double _defaultWidth = 200.0;
  static const double _defaultHeight = 150.0;

  /// Resolves an image from a source string.
  ///
  /// [source] can be:
  /// - Base64 data URI: `data:image/png;base64,...`
  /// - Remote URL: `http://...`, `https://...`
  /// - Local File Path: `/path/to/image.png` (if accessible)
  static Future<ImageResult?> resolve(
    String source, {
    double? width,
    double? height,
    String? alt,
  }) async {
    if (source.isEmpty) return null;

    Uint8List? bytes;
    String extension = 'png';

    try {
      if (source.startsWith('data:image/')) {
        // Handle Base64
        final regex = RegExp(r'data:image/(\w+);base64,(.+)');
        final match = regex.firstMatch(source);
        if (match != null) {
          extension = match.group(1)!;
          final base64Data = match.group(2)!;
          bytes = base64Decode(base64Data);
        }
      } else if (source.startsWith('http://') ||
          source.startsWith('https://')) {
        // Handle Remote URL
        final response = await http.get(Uri.parse(source)).timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
          extension =
              _getImageExtension(source, response.headers['content-type']);
        }
      } else {
        // Handle Local File
        final file = File(source);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          extension = _getImageExtension(source, null);
        }
      }
    } catch (e) {
      // Log error or ignore? For now, we return null to allow fallback.
      // print('DocxCreator ImageResolver Error: $e');
    }

    if (bytes == null) return null;

    return ImageResult(
      bytes: bytes,
      extension: extension,
      width: width ??
          _parseDimension(null) ??
          _defaultWidth, // _parseDimension handles px suffix if needed
      height: height ?? _parseDimension(null) ?? _defaultHeight,
      altText: alt ?? 'Image',
    );
  }

  static double? _parseDimension(String? value) {
    if (value == null) return null;
    final cleaned =
        value.replaceAll(RegExp(r'px\s*$', caseSensitive: false), '').trim();
    return double.tryParse(cleaned);
  }

  static String _getImageExtension(String url, String? contentType) {
    // Try to get extension from URL/Path
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.png')) return 'png';
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'jpeg';
      if (path.endsWith('.gif')) return 'gif';
      if (path.endsWith('.bmp')) return 'bmp';
      if (path.endsWith('.webp')) return 'webp';
      if (path.endsWith('.tiff') || path.endsWith('.tif')) return 'tiff';
    } catch (_) {}

    // Try to get from content-type
    if (contentType != null) {
      if (contentType.contains('png')) return 'png';
      if (contentType.contains('jpeg') || contentType.contains('jpg'))
        return 'jpeg';
      if (contentType.contains('gif')) return 'gif';
      if (contentType.contains('bmp')) return 'bmp';
      if (contentType.contains('webp')) return 'webp';
      if (contentType.contains('tiff')) return 'tiff';
    }

    // Default
    return 'png';
  }
}
