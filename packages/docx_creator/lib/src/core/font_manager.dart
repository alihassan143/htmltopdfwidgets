import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// Manages embedded fonts for the Docx document.
class FontManager {
  final Map<String, EmbeddedFont> _fonts = {};

  /// Registers a font file to be embedded.
  ///
  /// [familyName] is the name of the font (e.g., "Roboto").
  /// [bytes] is the raw font data.
  /// [type] is true for Regular, false/other for specialized?
  /// Actually, we register by family and specific style if needed.
  /// For now, we assume [bytes] is the Regular font for this family unless specified.
  ///
  /// Returns the relationship ID (rId) for the font or font key.
  void addFont(String familyName, Uint8List bytes) {
    if (!_fonts.containsKey(familyName)) {
      // Generate a unique obfuscation key
      // "The key is a 128-bit GUID..."
      // But XOR obfuscation uses the font key GUID from the ODTTF.
      // Wait, standard font obfuscation for Word:
      // "The obfuscation key is a GUID string representation of the font key."
      // We generate a GUID.
      final guid = const Uuid().v4();

      _fonts[familyName] = EmbeddedFont(
        familyName: familyName,
        bytes: bytes,
        obfuscationKey: guid,
      );
    }
  }

  /// Registers a pre-existing EmbeddedFont.
  void registerFont(EmbeddedFont font) {
    if (!_fonts.containsKey(font.familyName)) {
      _fonts[font.familyName] = font;
    }
  }

  /// Gets the list of registered fonts.
  List<EmbeddedFont> get fonts => _fonts.values.toList();
}

class EmbeddedFont {
  final String familyName;
  final Uint8List bytes;
  final String? preservedFilename;
  final String obfuscationKey; // Re-add this!

  EmbeddedFont({
    required this.familyName,
    required this.bytes,
    required this.obfuscationKey,
    this.preservedFilename,
  });

  /// Create from obfuscated data (de-obfuscates).
  factory EmbeddedFont.fromObfuscated({
    required String familyName,
    required Uint8List obfuscatedBytes,
    required String obfuscationKey,
    String? preservedFilename,
  }) {
    final keyBytes = _parseGuid(obfuscationKey);
    final data = Uint8List.fromList(obfuscatedBytes);
    for (var i = 0; i < 32 && i < data.length; i++) {
      data[i] = data[i] ^ keyBytes[15 - (i % 16)];
    }
    return EmbeddedFont(
      familyName: familyName,
      bytes: data,
      obfuscationKey: obfuscationKey,
      preservedFilename: preservedFilename,
    );
  }

  /// The algorithm:
  /// 1. Convert the GUID (obfuscationKey) to a byte array (16 bytes).
  ///    The GUID is in standard registry format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
  ///    Parts 1, 2, 3 are Little Endian. Parts 4, 5 are Big Endian (byte array).
  /// 2. XOR the first 32 bytes of the font data with the GUID key bytes.
  Uint8List get obfuscatedBytes {
    final keyBytes = _parseGuid(obfuscationKey);
    final data = Uint8List.fromList(bytes); // usage copy

    // XOR first 32 bytes
    for (var i = 0; i < 32 && i < data.length; i++) {
      // Reverse key bytes access! (i % 16 -> 15 - (i % 16))?
      // Checking open-source implementations (e.g. POI):
      // "XOR with the obfuscation key (reversed)"
      // "key[15 - (i % 16)]"
      data[i] = data[i] ^ keyBytes[15 - (i % 16)];
    }
    return data;
  }

  static Uint8List _parseGuid(String guid) {
    // Clean GUID
    final clean = guid.replaceAll(RegExp(r'[{}-]'), '');
    if (clean.length != 32) throw ArgumentError('Invalid GUID length');

    final bytes = Uint8List(16);

    // Part 1: 4 bytes (Little Endian)
    bytes[3] = int.parse(clean.substring(0, 2), radix: 16);
    bytes[2] = int.parse(clean.substring(2, 4), radix: 16);
    bytes[1] = int.parse(clean.substring(4, 6), radix: 16);
    bytes[0] = int.parse(clean.substring(6, 8), radix: 16);

    // Part 2: 2 bytes (Little Endian)
    bytes[5] = int.parse(clean.substring(8, 10), radix: 16);
    bytes[4] = int.parse(clean.substring(10, 12), radix: 16);

    // Part 3: 2 bytes (Little Endian)
    bytes[7] = int.parse(clean.substring(12, 14), radix: 16);
    bytes[6] = int.parse(clean.substring(14, 16), radix: 16);

    // Part 4 & 5: 8 bytes (Big Endian sequence)
    for (var i = 0; i < 8; i++) {
      bytes[8 + i] =
          int.parse(clean.substring(16 + (i * 2), 16 + (i * 2) + 2), radix: 16);
    }

    return bytes;
  }
}
