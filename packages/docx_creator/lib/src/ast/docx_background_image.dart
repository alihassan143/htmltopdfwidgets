import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Fill mode for background images on document pages.
///
/// Controls how the background image is sized and positioned to fill the page.
///
/// ## Example
/// ```dart
/// DocxBackgroundImage(
///   bytes: imageBytes,
///   extension: 'png',
///   fillMode: DocxBackgroundFillMode.stretch,
/// )
/// ```
enum DocxBackgroundFillMode {
  /// Tile/repeat the image across the page.
  ///
  /// Best for patterns and small repeating images.
  tile,

  /// Stretch the image to fill the entire page.
  ///
  /// May distort aspect ratio. Best for full-page backgrounds.
  stretch,

  /// Center the image on the page without scaling.
  ///
  /// Maintains original size. Best for logos and watermarks.
  center,

  /// Scale the image to fit within the page while maintaining aspect ratio.
  ///
  /// May leave empty space on edges. Best for photos.
  fit,
}

/// A background image for document pages.
///
/// Use [DocxBackgroundImage] to set an image as the background for all pages
/// in a document section. Supports various fill modes for different effects.
///
/// ## Basic Usage
/// ```dart
/// final background = DocxBackgroundImage(
///   bytes: await File('background.png').readAsBytes(),
///   extension: 'png',
/// );
///
/// docx()
///   .section(backgroundImage: background)
///   .h1('Title')
///   .build();
/// ```
///
/// ## From URL
/// ```dart
/// final background = await DocxBackgroundImage.fromUrl(
///   'https://example.com/background.jpg',
/// );
/// ```
///
/// ## Watermark
/// ```dart
/// final watermark = await DocxBackgroundImage.watermark(
///   bytes: logoBytes,
///   extension: 'png',
/// );
/// ```
class DocxBackgroundImage {
  /// Raw image bytes (PNG, JPEG, GIF, BMP, or TIFF).
  final Uint8List bytes;

  /// Image file extension without dot (e.g., 'png', 'jpeg', 'gif').
  final String extension;

  /// How the image fills the page background.
  final DocxBackgroundFillMode fillMode;

  /// Opacity of the background image (0.0 = transparent, 1.0 = opaque).
  ///
  /// Lower values are useful for watermarks that shouldn't obscure content.
  final double opacity;

  // Internal: Relationship ID set by exporter
  String? _relationshipId;

  /// Creates a background image for document pages.
  ///
  /// - [bytes]: Raw image data as a [Uint8List].
  /// - [extension]: Image format ('png', 'jpeg', 'gif', 'bmp', 'tiff').
  /// - [fillMode]: How the image fills the page (default: [DocxBackgroundFillMode.stretch]).
  /// - [opacity]: Image opacity from 0.0 to 1.0 (default: 1.0).
  DocxBackgroundImage({
    required this.bytes,
    required this.extension,
    this.fillMode = DocxBackgroundFillMode.stretch,
    this.opacity = 1.0,
  }) : assert(
          opacity >= 0.0 && opacity <= 1.0,
          'Opacity must be between 0.0 and 1.0',
        );

  /// Creates a background image from a URL.
  ///
  /// Automatically detects the image extension from the URL or Content-Type.
  ///
  /// ```dart
  /// final bg = await DocxBackgroundImage.fromUrl(
  ///   'https://picsum.photos/800/600',
  ///   fillMode: DocxBackgroundFillMode.stretch,
  /// );
  /// ```
  static Future<DocxBackgroundImage> fromUrl(
    String url, {
    DocxBackgroundFillMode fillMode = DocxBackgroundFillMode.stretch,
    double opacity = 1.0,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load image from URL: ${response.statusCode}');
    }

    // Detect extension from URL or Content-Type
    String ext = _detectExtension(url, response.headers['content-type']);

    return DocxBackgroundImage(
      bytes: response.bodyBytes,
      extension: ext,
      fillMode: fillMode,
      opacity: opacity,
    );
  }

  /// Creates a centered watermark with low opacity.
  ///
  /// Perfect for logos, stamps, or "CONFIDENTIAL" marks.
  ///
  /// ```dart
  /// final watermark = DocxBackgroundImage.watermark(
  ///   bytes: logoBytes,
  ///   extension: 'png',
  ///   opacity: 0.1, // Very subtle
  /// );
  /// ```
  factory DocxBackgroundImage.watermark({
    required Uint8List bytes,
    required String extension,
    double opacity = 0.15,
  }) {
    return DocxBackgroundImage(
      bytes: bytes,
      extension: extension,
      fillMode: DocxBackgroundFillMode.center,
      opacity: opacity,
    );
  }

  /// Creates a watermark from a URL.
  ///
  /// ```dart
  /// final watermark = await DocxBackgroundImage.watermarkFromUrl(
  ///   'https://example.com/logo.png',
  ///   opacity: 0.2,
  /// );
  /// ```
  static Future<DocxBackgroundImage> watermarkFromUrl(
    String url, {
    double opacity = 0.15,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load image from URL: ${response.statusCode}');
    }

    String ext = _detectExtension(url, response.headers['content-type']);

    return DocxBackgroundImage(
      bytes: response.bodyBytes,
      extension: ext,
      fillMode: DocxBackgroundFillMode.center,
      opacity: opacity,
    );
  }

  /// Creates a tiled pattern background.
  ///
  /// ```dart
  /// final pattern = DocxBackgroundImage.tiled(
  ///   bytes: patternBytes,
  ///   extension: 'png',
  /// );
  /// ```
  factory DocxBackgroundImage.tiled({
    required Uint8List bytes,
    required String extension,
    double opacity = 1.0,
  }) {
    return DocxBackgroundImage(
      bytes: bytes,
      extension: extension,
      fillMode: DocxBackgroundFillMode.tile,
      opacity: opacity,
    );
  }

  /// Detects image extension from URL path or Content-Type header.
  static String _detectExtension(String url, String? contentType) {
    // Try URL extension first
    final urlExt = p.extension(Uri.parse(url).path).replaceFirst('.', '');
    if (_isValidImageExt(urlExt)) {
      return urlExt;
    }

    // Fall back to Content-Type
    if (contentType != null) {
      if (contentType.contains('png')) return 'png';
      if (contentType.contains('jpeg') || contentType.contains('jpg')) {
        return 'jpeg';
      }
      if (contentType.contains('gif')) return 'gif';
      if (contentType.contains('bmp')) return 'bmp';
      if (contentType.contains('tiff')) return 'tiff';
    }

    // Default to jpeg (most common for web images)
    return 'jpeg';
  }

  static bool _isValidImageExt(String ext) {
    return ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'tif'].contains(
      ext.toLowerCase(),
    );
  }

  /// Sets the relationship ID for DOCX export.
  void setRelationshipId(String rId) {
    _relationshipId = rId;
  }

  /// Gets the relationship ID (set by exporter).
  String? get relationshipId => _relationshipId;

  /// Normalized extension for content types.
  String get normalizedExtension {
    final ext = extension.toLowerCase();
    if (ext == 'jpg') return 'jpeg';
    if (ext == 'tif') return 'tiff';
    return ext;
  }

  /// MIME content type for the image.
  String get contentType {
    switch (normalizedExtension) {
      case 'png':
        return 'image/png';
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
        return 'image/tiff';
      default:
        return 'image/png';
    }
  }

  /// VML fill type value for the fill mode.
  String get vmlFillType {
    switch (fillMode) {
      case DocxBackgroundFillMode.tile:
        return 'tile';
      case DocxBackgroundFillMode.stretch:
        return 'frame';
      case DocxBackgroundFillMode.center:
        return 'frame';
      case DocxBackgroundFillMode.fit:
        return 'frame';
    }
  }
}
