import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../../../docx_creator.dart';

/// Parses numbering definitions from numbering.xml.
class NumberingParser {
  final ReaderContext context;

  /// Parsed abstract numbering definitions.
  final Map<int, List<DocxNumberingLevel>> _abstractNums = {};

  /// Parsed numbering instances.
  final Map<int, DocxNumberingDef> _numberings = {};

  /// Parsed picture bullet definitions (numPicBulletId -> rId).
  final Map<int, String> _pictureBullets = {};

  NumberingParser(this.context);

  /// Gets parsed numbering definitions.
  Map<int, DocxNumberingDef> get numberings => Map.unmodifiable(_numberings);

  /// Gets parsed picture bullets.
  Map<int, String> get pictureBullets => Map.unmodifiable(_pictureBullets);

  /// Parse numbering.xml content.
  void parse(String xmlContent) {
    try {
      final xml = XmlDocument.parse(xmlContent);

      // First pass: parse picture bullet definitions
      _parsePictureBullets(xml);

      // Second pass: parse abstract numbering definitions
      for (var abstractNum in xml.findAllElements('w:abstractNum')) {
        final abstractNumId =
            int.tryParse(abstractNum.getAttribute('w:abstractNumId') ?? '');
        if (abstractNumId == null) continue;

        final levels = <DocxNumberingLevel>[];
        for (var lvl in abstractNum.findAllElements('w:lvl')) {
          final level = _parseLevel(lvl);
          if (level != null) levels.add(level);
        }
        _abstractNums[abstractNumId] = levels;
      }

      // Third pass: parse numbering instances
      for (var num in xml.findAllElements('w:num')) {
        final numId = int.tryParse(num.getAttribute('w:numId') ?? '');
        if (numId == null) continue;

        final abstractNumIdRef =
            num.getElement('w:abstractNumId')?.getAttribute('w:val');
        final abstractNumId = int.tryParse(abstractNumIdRef ?? '');
        if (abstractNumId == null) continue;

        _numberings[numId] = DocxNumberingDef(
          abstractNumId: abstractNumId,
          numId: numId,
          levels: _abstractNums[abstractNumId] ?? [],
        );
      }
    } catch (e) {}
  }

  /// Parse picture bullet definitions from w:numPicBullet elements.
  void _parsePictureBullets(XmlDocument xml) {
    for (var picBullet in xml.findAllElements('w:numPicBullet')) {
      final id = int.tryParse(picBullet.getAttribute('w:numPicBulletId') ?? '');
      if (id == null) continue;

      // Find the image relationship ID
      // Path: w:numPicBullet -> w:pict -> v:shape -> v:imagedata[@r:id]
      final pict = picBullet.getElement('w:pict');
      if (pict == null) continue;

      final shape = pict.getElement('v:shape');
      if (shape == null) continue;

      final imageData = shape.getElement('v:imagedata');
      if (imageData == null) continue;

      final rId = imageData.getAttribute('r:id');
      if (rId != null) {
        _pictureBullets[id] = rId;
        context.pictureBullets[id] = rId;
      }
    }
  }

  DocxNumberingLevel? _parseLevel(XmlElement lvl) {
    final ilvl = int.tryParse(lvl.getAttribute('w:ilvl') ?? '');
    if (ilvl == null) return null;

    final numFmt =
        lvl.getElement('w:numFmt')?.getAttribute('w:val') ?? 'decimal';
    final lvlText = lvl.getElement('w:lvlText')?.getAttribute('w:val');
    final start =
        int.tryParse(lvl.getElement('w:start')?.getAttribute('w:val') ?? '1') ??
            1;

    // Parse indentation
    int? indentLeft;
    int? hanging;
    final pPr = lvl.getElement('w:pPr');
    if (pPr != null) {
      final ind = pPr.getElement('w:ind');
      if (ind != null) {
        indentLeft = int.tryParse(ind.getAttribute('w:left') ?? '');
        hanging = int.tryParse(ind.getAttribute('w:hanging') ?? '');
      }
    }

    // Parse bullet character
    String? bulletChar;
    String? bulletFont;
    // Parse numbering properties (color, font, etc.)
    String? themeColor;
    String? themeTint;
    String? themeShade;
    String? themeFont;

    final rPr = lvl.getElement('w:rPr');
    if (rPr != null) {
      // Parse Fonts
      final rFonts = rPr.getElement('w:rFonts');
      if (rFonts != null) {
        if (numFmt == 'bullet') {
          bulletFont =
              rFonts.getAttribute('w:ascii') ?? rFonts.getAttribute('w:hAnsi');
        }
        themeFont = rFonts.getAttribute('w:asciiTheme') ??
            rFonts.getAttribute('w:hAnsiTheme');
      }

      // Parse Color
      final colorElem = rPr.getElement('w:color');
      if (colorElem != null) {
        themeColor = colorElem.getAttribute('w:themeColor');
        themeTint = colorElem.getAttribute('w:themeTint');
        themeShade = colorElem.getAttribute('w:themeShade');
      }
    }

    if (numFmt == 'bullet') {
      bulletChar = lvlText;
    }

    // Parse picture bullet reference
    int? picBulletId;
    Uint8List? picBulletImage;
    final lvlPicBulletId = lvl.getElement('w:lvlPicBulletId');
    if (lvlPicBulletId != null) {
      picBulletId = int.tryParse(lvlPicBulletId.getAttribute('w:val') ?? '');

      // Resolve the image bytes if possible
      if (picBulletId != null) {
        final rId = _pictureBullets[picBulletId];
        if (rId != null) {
          final rel = context.numberingRelationships[rId];
          if (rel != null) {
            // Read image from word/media/...
            // Handle both relative paths (media/...) and absolute paths
            final target = rel.target;
            final imagePath = target.startsWith('media/')
                ? 'word/$target'
                : target.startsWith('/word/')
                    ? target.substring(1)
                    : 'word/$target';
            picBulletImage = context.readBytes(imagePath);
          }
        }
      }
    }

    return DocxNumberingLevel(
      level: ilvl,
      numFmt: numFmt,
      lvlText: lvlText,
      start: start,
      indentLeft: indentLeft,
      hanging: hanging,
      bulletChar: bulletChar,
      bulletFont: bulletFont,
      themeFont: themeFont,
      themeColor: themeColor,
      themeTint: themeTint,
      themeShade: themeShade,
      picBulletId: picBulletId,
      picBulletImage: picBulletImage,
    );
  }

  /// Gets the numbering definition for a numId.
  DocxNumberingDef? getNumbering(int numId) => _numberings[numId];

  /// Gets the level definition for a numbering.
  DocxNumberingLevel? getLevel(int numId, int ilvl) {
    final def = _numberings[numId];
    if (def == null) return null;
    return def.levels.where((l) => l.level == ilvl).firstOrNull;
  }
}
