import 'package:flutter/services.dart';

/// Loads embedded fonts from DOCX files.
class EmbeddedFontLoader {
  static final Map<String, bool> _loadedFonts = {};

  /// Load an embedded font for use in the document.
  ///
  /// DOCX files may contain obfuscated fonts (per OOXML spec).
  /// This method handles deobfuscation if necessary.
  static Future<void> loadFont(
    String familyName,
    Uint8List fontData, {
    String? obfuscationKey,
  }) async {
    // Skip if already loaded
    if (_loadedFonts.containsKey(familyName)) return;

    Uint8List fontBytes = fontData;

    // Handle obfuscated fonts (OOXML uses GUID-based XOR for first 32 bytes)
    if (obfuscationKey != null && obfuscationKey.isNotEmpty) {
      fontBytes = _deobfuscateFont(fontData, obfuscationKey);
    }

    try {
      // Load font using FontLoader
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
      _loadedFonts[familyName] = true;
    } catch (e) {
      // Font loading failed - likely invalid font data
      _loadedFonts[familyName] = false;
    }
  }

  /// Check if a font family has been loaded.
  static bool isFontLoaded(String familyName) {
    return _loadedFonts[familyName] ?? false;
  }

  /// Clear loaded fonts cache.
  static void clearCache() {
    _loadedFonts.clear();
  }

  /// Deobfuscate a font using the OOXML algorithm.
  ///
  /// OOXML fonts are obfuscated by XOR-ing the first 32 bytes
  /// with a key derived from the GUID.
  static Uint8List _deobfuscateFont(Uint8List data, String guidKey) {
    if (data.length < 32) return data;

    final key = _parseGuidToBytes(guidKey);
    if (key.isEmpty) return data;

    final result = Uint8List.fromList(data);

    // XOR first 32 bytes with the key
    for (int i = 0; i < 32; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }

    return result;
  }

  /// Parse a GUID string to bytes for deobfuscation.
  static Uint8List _parseGuidToBytes(String guid) {
    // Remove hyphens and braces from GUID
    final cleanGuid = guid
        .replaceAll('-', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .toUpperCase();

    if (cleanGuid.length != 32) return Uint8List(0);

    // Parse hex string to bytes (Big Endian initial parse)
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      final hex = cleanGuid.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(hex, radix: 16);
    }

    // Apply Little Endian swapping for the first 3 components (Data1, Data2, Data3)
    // as per Microsoft GUID spec used in OOXML obfuscation.
    // GUID Structure: {D1-D2-D3-D4-D5}
    // D1 (4 bytes): Swap
    _swap(bytes, 0, 3);
    _swap(bytes, 1, 2);
    // D2 (2 bytes): Swap
    _swap(bytes, 4, 5);
    // D3 (2 bytes): Swap
    _swap(bytes, 6, 7);
    // D4, D5 (8 bytes): Keep Big Endian

    return bytes;
  }

  static void _swap(Uint8List list, int i, int j) {
    final temp = list[i];
    list[i] = list[j];
    list[j] = temp;
  }
}
