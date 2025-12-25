import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../docx_creator.dart';
import '../core/font_manager.dart';
import 'handlers/relationship_manager.dart';
import 'models/docx_relationship.dart';
import 'parsers/block_parser.dart';
import 'parsers/section_parser.dart';
import 'parsers/style_parser.dart';
import 'reader_context.dart';

/// Reads and parses existing .docx files.
///
/// This is the main entry point for loading DOCX documents. It uses a modular
/// architecture with separate parsers for different document components:
///
/// - [StyleParser] - Parses styles.xml
/// - [BlockParser] - Parses paragraphs, lists, and block elements
/// - [SectionParser] - Parses page layout, headers, and footers
/// - [RelationshipManager] - Manages document relationships
class DocxReader {
  /// Loads a .docx file from the file system.
  static Future<DocxBuiltDocument> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    return loadFromBytes(bytes);
  }

  /// Loads a .docx file from bytes.
  static Future<DocxBuiltDocument> loadFromBytes(Uint8List bytes) async {
    return _DocxReaderOrchestrator(bytes).read();
  }
}

/// Internal orchestrator that coordinates all parser modules.
class _DocxReaderOrchestrator {
  final ReaderContext context;

  // Module instances
  late final RelationshipManager _relationshipManager;
  late final StyleParser _styleParser;
  late final BlockParser _blockParser;
  late final SectionParser _sectionParser;

  _DocxReaderOrchestrator(Uint8List bytes)
      : context = ReaderContext(ZipDecoder().decodeBytes(bytes)) {
    _relationshipManager = RelationshipManager(context);
    _styleParser = StyleParser(context);
    _blockParser = BlockParser(context);
    _sectionParser = SectionParser(context);
  }

  Future<DocxBuiltDocument> read() async {
    // 1. Load content types and relationships
    _relationshipManager.loadContentTypes();
    _relationshipManager.loadDocumentRelationships();

    // 2. Load and parse styles BEFORE parsing document
    final stylesXml = context.readContent('word/styles.xml');
    if (stylesXml != null) {
      _styleParser.parse(stylesXml);
    }

    // 3. Parse theme (colors and fonts) from theme1.xml
    DocxThemeColors themeColors = const DocxThemeColors();
    DocxThemeFonts themeFonts = const DocxThemeFonts();
    final themeXml = context.readContent('word/theme/theme1.xml');
    if (themeXml != null) {
      final (colors, fonts) = ThemeParser.parse(themeXml);
      themeColors = colors;
      themeFonts = fonts;
    }

    // 4. Load and parse numbering for list detection
    final numberingXml = context.readContent('word/numbering.xml');
    context.numberingXml = numberingXml;

    // Parse numbering relationships for image bullets
    final numberingRelsXml =
        context.readContent('word/_rels/numbering.xml.rels');
    if (numberingRelsXml != null) {
      try {
        final relsDoc = XmlDocument.parse(numberingRelsXml);
        for (var rel in relsDoc.findAllElements('Relationship')) {
          final rId = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          final type = rel.getAttribute('Type');
          if (rId != null && target != null) {
            context.numberingRelationships[rId] = DocxRelationship(
              id: rId,
              type: type ?? '',
              target: target,
            );
          }
        }
      } catch (_) {}
    }

    if (numberingXml != null) {
      final numberingParser = NumberingParser(context);
      numberingParser.parse(numberingXml);
      // Store parsed numbering in context for use by block parser
      context.parsedNumberings = numberingParser.numberings;
    }

    // 5. Parse document content
    final documentFile = context.archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw Exception('Invalid docx file: missing word/document.xml');
    }

    final documentXml =
        XmlDocument.parse(utf8.decode(documentFile.content as List<int>));

    final body = documentXml.findAllElements('w:body').first;
    final elements = _blockParser.parseBody(body);

    // 6. Parse document background
    DocxColor? backgroundColor;
    final bgElem = documentXml.findAllElements('w:background').firstOrNull;
    if (bgElem != null) {
      final colorHex = bgElem.getAttribute('w:color');
      if (colorHex != null && colorHex != 'auto') {
        backgroundColor = DocxColor('#$colorHex');
      }
    }

    // 7. Parse section properties
    final section =
        _sectionParser.parse(body, backgroundColor: backgroundColor);

    // 8. Read fonts
    final fontTableXml = context.readContent('word/fontTable.xml');
    final fontTableRelsXml =
        context.readContent('word/_rels/fontTable.xml.rels');
    final fonts = _readFonts(fontTableXml, fontTableRelsXml);

    // 9. Gather raw XML strings for preservation
    final settingsXml = context.readContent('word/settings.xml');
    final contentTypesXml = context.readContent('[Content_Types].xml');
    final rootRelsXml = context.readContent('_rels/.rels');
    final headerBgXml = context.readContent('word/header_bg.xml');
    final headerBgRelsXml =
        context.readContent('word/_rels/header_bg.xml.rels');

    // 10. Read footnotes and endnotes
    final footnotesXml = context.readContent('word/footnotes.xml');
    final endnotesXml = context.readContent('word/endnotes.xml');

    List<DocxFootnote>? footnotes;
    if (footnotesXml != null) {
      footnotes = _parseFootnotes(footnotesXml);
    }

    List<DocxEndnote>? endnotes;
    if (endnotesXml != null) {
      endnotes = _parseEndnotes(endnotesXml);
    }

    // 11. Build DocxTheme from parsed style and theme data
    final theme = _styleParser.buildTheme(
      colors: themeColors,
      fonts: themeFonts,
    );

    return DocxBuiltDocument(
      elements: elements,
      section: section,
      stylesXml: stylesXml,
      rootRelsXml: rootRelsXml,
      numberingXml: numberingXml,
      settingsXml: settingsXml,
      fontTableXml: fontTableXml,
      contentTypesXml: contentTypesXml,
      headerBgXml: headerBgXml,
      headerBgRelsXml: headerBgRelsXml,
      footnotesXml: footnotesXml,
      endnotesXml: endnotesXml,
      fonts: fonts,
      footnotes: footnotes,
      endnotes: endnotes,
      theme: theme,
      themeXml: themeXml,
    );
  }

  List<DocxFootnote> _parseFootnotes(String xml) {
    final results = <DocxFootnote>[];
    try {
      final doc = XmlDocument.parse(xml);
      for (var elem in doc.findAllElements('w:footnote')) {
        final id = int.tryParse(elem.getAttribute('w:id') ?? '');
        if (id != null) {
          // Parse content blocks (paragraphs etc) inside the footnote
          final content = _blockParser.parseBlocks(elem.children);
          results.add(DocxFootnote(
            footnoteId: id,
            content: content.whereType<DocxBlock>().toList(),
          ));
        }
      }
    } catch (e) {
      // Ignore parsing errors, fallback to raw XML
    }
    return results;
  }

  List<DocxEndnote> _parseEndnotes(String xml) {
    final results = <DocxEndnote>[];
    try {
      final doc = XmlDocument.parse(xml);
      for (var elem in doc.findAllElements('w:endnote')) {
        final id = int.tryParse(elem.getAttribute('w:id') ?? '');
        if (id != null) {
          // Parse content blocks (paragraphs etc) inside the endnote
          final content = _blockParser.parseBlocks(elem.children);
          results.add(DocxEndnote(
            endnoteId: id,
            content: content.whereType<DocxBlock>().toList(),
          ));
        }
      }
    } catch (e) {
      // Ignore parsing errors, fallback to raw XML
    }
    return results;
  }

  List<EmbeddedFont> _readFonts(
      String? fontTableXml, String? fontTableRelsXml) {
    if (fontTableXml == null || fontTableRelsXml == null) return [];

    final fonts = <EmbeddedFont>[];
    try {
      final ftXml = XmlDocument.parse(fontTableXml);
      final ftrXml = XmlDocument.parse(fontTableRelsXml);

      // Parse relationships
      final rels = <String, String>{};
      for (var rel in ftrXml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) rels[id] = target;
      }

      // Parse fonts
      for (var fontElem in ftXml.findAllElements('w:font')) {
        final name = fontElem.getAttribute('w:name');
        if (name == null) continue;

        final embed = fontElem.findAllElements('w:embedRegular').firstOrNull;
        if (embed != null) {
          final id = embed.getAttribute('r:id');
          final key = embed.getAttribute('w:fontKey');

          if (id != null && key != null && rels.containsKey(id)) {
            String target = rels[id]!;
            ArchiveFile? file;
            if (target.startsWith('/')) {
              target = target.substring(1);
              file = context.archive.findFile(target);
            } else {
              file = context.archive.findFile('word/$target');
            }

            if (file != null) {
              String cleanKey = key.replaceAll(RegExp(r'[{}]'), '');
              fonts.add(EmbeddedFont.fromObfuscated(
                familyName: name,
                obfuscatedBytes: Uint8List.fromList(file.content as List<int>),
                obfuscationKey: cleanKey,
              ));
            }
          }
        }
      }
    } catch (_) {}

    return fonts;
  }
}
