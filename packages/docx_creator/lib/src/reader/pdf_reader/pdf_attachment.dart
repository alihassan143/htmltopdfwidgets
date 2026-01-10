import 'dart:typed_data';

import 'pdf_parser.dart';

/// Represents an embedded file attachment in the PDF.
class PdfAttachment {
  final String filename;
  final Uint8List data;
  final String? description;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final String? mimeType;

  PdfAttachment({
    required this.filename,
    required this.data,
    this.description,
    this.creationDate,
    this.modificationDate,
    this.mimeType,
  });

  @override
  String toString() => 'PdfAttachment($filename, ${data.length} bytes)';
}

/// Helper to extract attachments.
class PdfAttachmentExtractor {
  final PdfParser _parser;
  PdfAttachmentExtractor(this._parser);

  List<PdfAttachment> extract() {
    final result = <PdfAttachment>[];

    // Get Catalog
    final catalogObj = _parser.getObject(_parser.rootRef);
    if (catalogObj == null) return result;

    // Get Names dictionary
    final namesMatch =
        RegExp(r'/Names\s+(\d+)\s+\d+\s+R').firstMatch(catalogObj.content);
    if (namesMatch == null) return result;

    final namesRef = int.parse(namesMatch.group(1)!);
    final namesObj = _parser.getObject(namesRef);
    if (namesObj == null) return result;

    // Get EmbeddedFiles name tree
    final efMatch = RegExp(r'/EmbeddedFiles\s+(\d+)\s+\d+\s+R')
        .firstMatch(namesObj.content);
    if (efMatch == null) return result;

    final efRef = int.parse(efMatch.group(1)!);
    _parseNameTree(efRef, result);

    return result;
  }

  void _parseNameTree(int ref, List<PdfAttachment> result) {
    final obj = _parser.getObject(ref);
    if (obj == null) return;

    // Check for Kids (Intermediate)
    final kidsMatch = RegExp(r'/Kids\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (kidsMatch != null) {
      final kidRefs =
          RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1)!);
      for (final kr in kidRefs) {
        _parseNameTree(int.parse(kr.group(1)!), result);
      }
      return;
    }

    // Check for Names (Leaf)
    // Names array format: [ string indirectRef string indirectRef ... ]
    final namesMatch = RegExp(r'/Names\s*\[([^\]]+)\]').firstMatch(obj.content);
    if (namesMatch != null) {
      final namesContent = namesMatch.group(1)!;
      final refs = RegExp(r'(\d+)\s+\d+\s+R').allMatches(namesContent);
      // In a Name tree leaf, we assume refs are the values (FileSpecs).
      // A more robust parser would check the key types, but looking for refs is usually enough for leaf nodes.
      for (final r in refs) {
        final fileSpecRef = int.parse(r.group(1)!);
        final attachment = _parseFileSpec(fileSpecRef);
        if (attachment != null) {
          result.add(attachment);
        }
      }
    }
  }

  PdfAttachment? _parseFileSpec(int ref) {
    final obj = _parser.getObject(ref);
    if (obj == null) return null;

    // Get Filename (/F or /UF)
    String filename = 'unknown';
    final ufMatch = RegExp(r'/UF\s*\(([^)]+)\)').firstMatch(obj.content);
    if (ufMatch != null) {
      filename = ufMatch.group(1)!;
    } else {
      final fMatch = RegExp(r'/F\s*\(([^)]+)\)').firstMatch(obj.content);
      if (fMatch != null) filename = fMatch.group(1)!;
    }

    // Get EF dictionary
    final efMatch = RegExp(r'/EF\s*<<([^>]+)>>').firstMatch(obj.content);
    if (efMatch == null) return null; // No embedded file stream

    final efContent = efMatch.group(1)!;
    // Look for /F key pointing to stream
    final streamRefMatch =
        RegExp(r'/F\s+(\d+)\s+\d+\s+R').firstMatch(efContent);
    if (streamRefMatch == null) return null;

    final streamRef = int.parse(streamRefMatch.group(1)!);
    final streamData =
        _parser.getStreamContent(streamRef); // returns String (latin1)

    if (streamData != null) {
      return PdfAttachment(
        filename: filename,
        data: Uint8List.fromList(streamData.codeUnits),
      );
    }
    return null;
  }
}
