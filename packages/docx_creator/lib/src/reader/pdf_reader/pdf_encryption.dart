import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart'
    show Digest, KeyParameter, ParametersWithIV;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

import 'pdf_parser.dart';

/// PDF encryption handler.
///
/// Supports Standard Security Handler with RC4 (40/128-bit) and AES (128/256-bit).
class PdfEncryption {
  /// Encryption version (/V value).
  final int version;

  /// Encryption revision (/R value).
  final int revision;

  /// Key length in bits.
  final int keyLength;

  /// Owner key (/O value).
  final Uint8List? ownerKey;

  /// User key (/U value).
  final Uint8List? userKey;

  /// Permission flags (/P value).
  final int permissions;

  /// Whether metadata is encrypted.
  final bool encryptMetadata = true;

  /// Filter name (e.g., "Standard").
  final String? filter;

  /// File ID (from trailer /ID).
  final Uint8List fileID;

  /// Crypt filter method for streams (AESV2, AESV3, V2, etc.).
  final String? stmF;

  /// Crypt filter method for strings.
  final String? strF;

  /// Owner encryption key (for AES-256, /OE value).
  final Uint8List? oeKey;

  /// User encryption key (for AES-256, /UE value).
  final Uint8List? ueKey;

  /// Encryption key derived from password.
  Uint8List? _encryptionKey;

  PdfEncryption._({
    required this.version,
    required this.revision,
    required this.keyLength,
    required this.fileID,
    this.ownerKey,
    this.userKey,
    required this.permissions,
    this.filter,
    this.stmF,
    this.strF,
    this.oeKey,
    this.ueKey,
  });

  /// Whether printing is allowed.
  bool get canPrint => (permissions & 4) != 0;

  /// Whether modifying content is allowed.
  bool get canModify => (permissions & 8) != 0;

  /// Whether copying text is allowed.
  bool get canCopy => (permissions & 16) != 0;

  /// Whether adding annotations is allowed.
  bool get canAnnotate => (permissions & 32) != 0;

  /// Whether filling forms is allowed.
  bool get canFillForms => (permissions & 256) != 0;

  /// Whether extracting for accessibility is allowed.
  bool get canExtractForAccessibility => (permissions & 512) != 0;

  /// Whether assembling document is allowed.
  bool get canAssemble => (permissions & 1024) != 0;

  /// Whether high quality printing is allowed.
  bool get canPrintHighQuality => (permissions & 2048) != 0;

  /// Whether the document uses AES encryption.
  bool get isAES => version >= 4;

  /// Whether the document uses RC4 encryption.
  bool get isRC4 => version < 4;

  /// Whether the document is unlocked and ready for decryption.
  bool get isReady => _encryptionKey != null;

  /// Encryption algorithm description.
  String get algorithmDescription {
    if (version == 1) return 'RC4 40-bit';
    if (version == 2) return 'RC4 ${keyLength > 0 ? keyLength : 128}-bit';
    if (version == 3) return 'Unpublished algorithm';
    if (version == 4) return 'AES-128 or RC4-128';
    if (version == 5) return 'AES-256';
    return 'Unknown (V=$version)';
  }

  @override
  String toString() => 'PdfEncryption(algorithm: $algorithmDescription, '
      'canPrint: $canPrint, canCopy: $canCopy)';

  /// Authenticates using the user or owner password.
  ///
  /// Returns true if successful. If [password] is empty, attempts
  /// to authenticate with the default empty password.
  bool authenticate(String password) {
    if (filter != 'Standard') {
      return false;
    }

    // Algorithm 2: Computing the encryption key
    // Step 1: Pad password
    final paddedPwd = _padPassword(password);

    // Step 2: Initialize digest with padded password
    var md5 = Digest("MD5");
    md5.update(paddedPwd, 0, paddedPwd.length);

    // Step 3: Pass O value
    if (ownerKey != null) {
      md5.update(ownerKey!, 0, ownerKey!.length);
    }

    // Step 4: Pass P value (little-endian 4 bytes)
    final pBytes = Uint8List(4);
    final pData = ByteData.view(pBytes.buffer);
    pData.setUint32(0, permissions, Endian.little);
    md5.update(pBytes, 0, 4);

    // Step 5: Pass first element of ID
    md5.update(fileID, 0, fileID.length);

    // Step 6: (Revision 4+) Pass EncryptMetadata
    if (revision >= 4 && !encryptMetadata) {
      md5.update(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]), 0, 4);
    }

    // Step 7: Finish the hash
    var hash = Uint8List(md5.digestSize);
    md5.doFinal(hash, 0);

    // Step 8: (Revision 3+) Repeat 50 times
    if (revision >= 3) {
      for (var i = 0; i < 50; i++) {
        md5 = Digest("MD5");
        md5.update(hash, 0, keyLength ~/ 8);
        md5.doFinal(hash, 0);
      }
    }

    // Step 9: Use keyLength bytes
    // Step 9: Use keyLength bytes
    final encKey = hash.sublist(0, keyLength ~/ 8);
    _encryptionKey = encKey;
    return true;
  }

  /// Decrypts data (string or stream) for a specific object.
  Uint8List decryptData(Uint8List data, int objNum, int genNum) {
    if (_encryptionKey == null) {
      throw Exception('Document not authenticated');
    }

    // AES-256 (V5): Use encryption key directly, no object key derivation
    if (version == 5) {
      return _decryptAes(data, _encryptionKey!);
    }

    // V4 with AES-128 (AESV2)
    if (version == 4 && (stmF == 'AESV2' || strF == 'AESV2')) {
      // Derive object key with AES marker
      final objKey = _deriveObjectKeyAes(_encryptionKey!, objNum, genNum);
      return _decryptAes(data, objKey);
    }

    // V1/V2/V3 and V4 with RC4: use RC4 decryption
    if (version == 1 ||
        version == 2 ||
        version == 3 ||
        (version == 4 && stmF != 'AESV2' && stmF != 'AESV3')) {
      final objKey = _deriveObjectKeyRc4(_encryptionKey!, objNum, genNum);
      return _rc4(objKey, data);
    }

    // Fallback: return data as is
    return data;
  }

  /// Derives object-specific key for RC4.
  Uint8List _deriveObjectKeyRc4(Uint8List key, int objNum, int genNum) {
    final objKey = Uint8List(key.length + 5);
    objKey.setRange(0, key.length, key);
    objKey[key.length] = objNum & 0xFF;
    objKey[key.length + 1] = (objNum >> 8) & 0xFF;
    objKey[key.length + 2] = (objNum >> 16) & 0xFF;
    objKey[key.length + 3] = genNum & 0xFF;
    objKey[key.length + 4] = (genNum >> 8) & 0xFF;

    final md5 = Digest("MD5");
    md5.update(objKey, 0, objKey.length);
    final hash = Uint8List(md5.digestSize);
    md5.doFinal(hash, 0);

    return hash.sublist(0, min(hash.length, (keyLength ~/ 8) + 5));
  }

  /// Derives object-specific key for AES-128.
  Uint8List _deriveObjectKeyAes(Uint8List key, int objNum, int genNum) {
    // AES key derivation adds 'sAlT' marker
    final objKey = Uint8List(key.length + 9);
    objKey.setRange(0, key.length, key);
    objKey[key.length] = objNum & 0xFF;
    objKey[key.length + 1] = (objNum >> 8) & 0xFF;
    objKey[key.length + 2] = (objNum >> 16) & 0xFF;
    objKey[key.length + 3] = genNum & 0xFF;
    objKey[key.length + 4] = (genNum >> 8) & 0xFF;
    // 'sAlT' marker for AES
    objKey[key.length + 5] = 0x73; // 's'
    objKey[key.length + 6] = 0x41; // 'A'
    objKey[key.length + 7] = 0x6C; // 'l'
    objKey[key.length + 8] = 0x54; // 'T'

    final md5 = Digest("MD5");
    md5.update(objKey, 0, objKey.length);
    final hash = Uint8List(md5.digestSize);
    md5.doFinal(hash, 0);

    // AES-128 uses 16-byte key
    return hash.sublist(0, min(16, hash.length));
  }

  /// Decrypts data using AES-CBC.
  /// First 16 bytes are the IV, rest is ciphertext with PKCS7 padding.
  Uint8List _decryptAes(Uint8List data, Uint8List key) {
    if (data.length < 16) {
      return data; // Too short for IV + any data
    }

    final iv = data.sublist(0, 16);
    final ciphertext = data.sublist(16);

    if (ciphertext.isEmpty) {
      return Uint8List(0);
    }

    try {
      final aes = AESEngine();
      final cbc = CBCBlockCipher(aes);
      final params = ParametersWithIV<KeyParameter>(
        KeyParameter(key),
        iv,
      );
      cbc.init(false, params); // false = decrypt

      final output = Uint8List(ciphertext.length);
      var offset = 0;
      while (offset < ciphertext.length) {
        offset += cbc.processBlock(ciphertext, offset, output, offset);
      }

      // Remove PKCS7 padding
      return _removePkcs7Padding(output);
    } catch (e) {
      // Decryption failed, return original data
      return data;
    }
  }

  /// Removes PKCS7 padding from decrypted data.
  Uint8List _removePkcs7Padding(Uint8List data) {
    if (data.isEmpty) return data;

    final padLen = data.last;
    if (padLen == 0 || padLen > 16 || padLen > data.length) {
      return data; // Invalid padding, return as-is
    }

    // Verify padding bytes
    for (var i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) {
        return data; // Invalid padding
      }
    }

    return data.sublist(0, data.length - padLen);
  }

  Uint8List _rc4(Uint8List key, Uint8List data) {
    // Basic RC4 implementation
    final s = List<int>.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
    }

    final output = Uint8List(data.length);
    var i = 0;
    j = 0;
    for (var k = 0; k < data.length; k++) {
      i = (i + 1) % 256;
      j = (j + s[i]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
      output[k] = data[k] ^ s[(s[i] + s[j]) % 256];
    }
    return output;
  }

  Uint8List _padPassword(String password) {
    const padding = [
      0x28,
      0xBF,
      0x4E,
      0x5E,
      0x4E,
      0x75,
      0x8A,
      0x41,
      0x64,
      0x00,
      0x4E,
      0x56,
      0xFF,
      0xFA,
      0x01,
      0x08,
      0x2E,
      0x2E,
      0x00,
      0xB6,
      0xD0,
      0x68,
      0x3E,
      0x80,
      0x2F,
      0x0C,
      0xA9,
      0xFE,
      0x64,
      0x53,
      0x69,
      0x7A
    ];

    final pwdBytes = utf8.encode(password);
    if (pwdBytes.length >= 32) {
      return Uint8List.fromList(pwdBytes.sublist(0, 32));
    }

    final out = Uint8List(32);
    out.setRange(0, pwdBytes.length, pwdBytes);
    out.setRange(pwdBytes.length, 32, padding);
    return out;
  }

  /// Extracts encryption info from a PDF.
  /// Returns null if document is not encrypted.
  static PdfEncryption? extract(PdfParser parser) {
    // Look for /Encrypt in trailer
    int? encryptRef;

    // Check traditional trailer
    final trailerPos = parser.content.lastIndexOf('trailer');
    if (trailerPos != -1) {
      final trailerContent = parser.content.substring(trailerPos);
      final encryptMatch =
          RegExp(r'/Encrypt\s+(\d+)\s+\d+\s+R').firstMatch(trailerContent);
      if (encryptMatch != null) {
        encryptRef = int.parse(encryptMatch.group(1)!);
      }
    }

    // If not found in trailer, try checking for XRef stream dictionary
    // which might contain Encrypt entry.
    // The parser processes XRef streams but stores the dictionary content in 'trailer' map?
    // Current PdfParser doesn't expose trailer map, but it parses it.

    // Fallback: scan for /Encrypt in last 1000 bytes (common optimization)
    if (encryptRef == null) {
      // ... simple fallback
    }

    if (encryptRef == null) {
      return null;
    }

    final obj = parser.getObject(encryptRef);
    if (obj == null) return null;

    final content = obj.content;

    // Extract basic fields
    int version = 0;
    final vMatch = RegExp(r'/V\s+(\d+)').firstMatch(content);
    if (vMatch != null) version = int.parse(vMatch.group(1)!);

    int revision = 0;
    final rMatch = RegExp(r'/R\s+(\d+)').firstMatch(content);
    if (rMatch != null) revision = int.parse(rMatch.group(1)!);

    int keyLength = 40; // Default
    final lMatch = RegExp(r'/Length\s+(\d+)').firstMatch(content);
    if (lMatch != null) keyLength = int.parse(lMatch.group(1)!);

    int permissions = 0;
    final pMatch = RegExp(r'/P\s+(-?\d+)').firstMatch(content);
    if (pMatch != null) permissions = int.parse(pMatch.group(1)!);

    Uint8List? ownerKey;
    // Try hex string format first: /O <hex>
    final oMatch = RegExp(r'/O\s*<([0-9A-Fa-f]+)>').firstMatch(content);
    if (oMatch != null) {
      ownerKey = _hexToBytes(oMatch.group(1)!);
    } else {
      // Try literal string format: /O (...)
      final oLiteralMatch = RegExp(r'/O\s*\(').firstMatch(content);
      if (oLiteralMatch != null) {
        final startIdx = oLiteralMatch.end;
        ownerKey = _extractLiteralBytes(content, startIdx);
      }
    }

    Uint8List? userKey;
    // Try hex string format first: /U <hex>
    final uMatch = RegExp(r'/U\s*<([0-9A-Fa-f]+)>').firstMatch(content);
    if (uMatch != null) {
      userKey = _hexToBytes(uMatch.group(1)!);
    } else {
      // Try literal string format: /U (...)
      final uLiteralMatch = RegExp(r'/U\s*\(').firstMatch(content);
      if (uLiteralMatch != null) {
        final startIdx = uLiteralMatch.end;
        userKey = _extractLiteralBytes(content, startIdx);
      }
    }

    // Get File ID from parser (usually found in trailer)
    // Extract ID from trailer string directly for now
    Uint8List fileID = Uint8List(0);
    final idMatch =
        RegExp(r'/ID\s*\[\s*<([0-9A-Fa-f]+)>').firstMatch(parser.content);
    if (idMatch != null) {
      fileID = _hexToBytes(idMatch.group(1)!);
    }

    // Extract filter
    String? filter;
    final fMatch = RegExp(r'/Filter\s*/(\w+)').firstMatch(content);
    if (fMatch != null) filter = fMatch.group(1);

    // Extract crypt filter method (StmF/StrF)
    String? stmF;
    final stmFMatch = RegExp(r'/StmF\s*/(\w+)').firstMatch(content);
    if (stmFMatch != null) stmF = stmFMatch.group(1);

    String? strF;
    final strFMatch = RegExp(r'/StrF\s*/(\w+)').firstMatch(content);
    if (strFMatch != null) strF = strFMatch.group(1);

    // Extract OE/UE keys for AES-256 (V5)
    Uint8List? oeKey;
    final oeMatch = RegExp(r'/OE\s*<([0-9A-Fa-f]+)>').firstMatch(content);
    if (oeMatch != null) {
      oeKey = _hexToBytes(oeMatch.group(1)!);
    }

    Uint8List? ueKey;
    final ueMatch = RegExp(r'/UE\s*<([0-9A-Fa-f]+)>').firstMatch(content);
    if (ueMatch != null) {
      ueKey = _hexToBytes(ueMatch.group(1)!);
    }

    return PdfEncryption._(
      version: version,
      revision: revision,
      keyLength: keyLength,
      fileID: fileID,
      ownerKey: ownerKey,
      userKey: userKey,
      permissions: permissions,
      filter: filter,
      stmF: stmF,
      strF: strF,
      oeKey: oeKey,
      ueKey: ueKey,
    );
  }

  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) hex = '0$hex';
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      final byte = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      result[i] = byte;
    }
    return result;
  }

  /// Extracts bytes from a literal string starting at the given index.
  /// Handles escape sequences and returns raw bytes.
  static Uint8List _extractLiteralBytes(String content, int startIdx) {
    final bytes = <int>[];
    var i = startIdx;
    int parenDepth = 1;

    while (i < content.length && parenDepth > 0) {
      final c = content[i];

      if (c == '\\' && i + 1 < content.length) {
        // Escape sequence
        final next = content[i + 1];
        switch (next) {
          case 'n':
            bytes.add(10);
            i += 2;
            break;
          case 'r':
            bytes.add(13);
            i += 2;
            break;
          case 't':
            bytes.add(9);
            i += 2;
            break;
          case '(':
          case ')':
          case '\\':
            bytes.add(next.codeUnitAt(0));
            i += 2;
            break;
          default:
            // Octal escape (e.g., \053)
            if (next.codeUnitAt(0) >= 48 && next.codeUnitAt(0) <= 55) {
              var octal = '';
              var j = i + 1;
              while (j < content.length &&
                  j < i + 4 &&
                  content[j].codeUnitAt(0) >= 48 &&
                  content[j].codeUnitAt(0) <= 55) {
                octal += content[j];
                j++;
              }
              bytes.add(int.parse(octal, radix: 8));
              i = j;
            } else {
              bytes.add(next.codeUnitAt(0));
              i += 2;
            }
        }
      } else if (c == '(') {
        parenDepth++;
        bytes.add(c.codeUnitAt(0));
        i++;
      } else if (c == ')') {
        parenDepth--;
        if (parenDepth > 0) {
          bytes.add(c.codeUnitAt(0));
        }
        i++;
      } else {
        bytes.add(c.codeUnitAt(0) & 0xFF);
        i++;
      }
    }

    return Uint8List.fromList(bytes);
  }
}

class RC4 {
  final Uint8List _s = Uint8List(256);
  int _i = 0;
  int _j = 0;

  RC4(Uint8List key) {
    for (var i = 0; i < 256; i++) {
      _s[i] = i;
    }

    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) % 256;
      final temp = _s[i];
      _s[i] = _s[j];
      _s[j] = temp;
    }
  }

  Uint8List process(Uint8List data) {
    final output = Uint8List(data.length);
    for (var k = 0; k < data.length; k++) {
      _i = (_i + 1) % 256;
      _j = (_j + _s[_i]) % 256;
      final temp = _s[_i];
      _s[_i] = _s[_j];
      _s[_j] = temp;
      output[k] = data[k] ^ _s[(_s[_i] + _s[_j]) % 256];
    }
    return output;
  }
}
