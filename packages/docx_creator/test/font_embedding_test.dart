import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
// Note: importing internal implementation details for testing if needed,
// but DocxExporter is public. FontManager is public?
// I added FontManager to core, exported in docx_creator.dart?
// Need to check export status. I'll rely on generic import.
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Font Embedding', () {
    test('Exports docx with embedded fonts and verifies structure', () async {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.text('Hello', fontFamily: 'TestFont'),
      ]);

      final exporter = DocxExporter();

      // Create dummy font data (at least 32 bytes to test full XOR)
      final fontData = Uint8List.fromList(List.generate(50, (i) => i));
      // Expected fontKey/GUID will be generated.
      // We can't easily predict the GUID unless we mock Uuid or check the created file.

      exporter.fontManager.addFont('TestFont', fontData);

      final bytes = await exporter.exportToBytes(doc);

      // Verify ZIP structure
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Check [Content_Types].xml
      final contentTypes = archive.findFile('[Content_Types].xml');
      expect(contentTypes, isNotNull);
      final ctXml = XmlDocument.parse(utf8.decode(contentTypes!.content));
      final hasOdttf = ctXml.findAllElements('Default').any((e) =>
          e.getAttribute('Extension') == 'odttf' &&
          e.getAttribute('ContentType') ==
              'application/vnd.openxmlformats-package.obfuscated-font');
      expect(hasOdttf, isTrue, reason: 'odttf content type missing');

      // 2. Find font file in word/fonts/
      final fontFiles = archive.files
          .where((f) =>
              f.name.startsWith('word/fonts/') && f.name.endsWith('.odttf'))
          .toList();
      expect(fontFiles.length, 1);
      final fontFile = fontFiles.first;

      // 3. Verify XOR obfuscation
      // We need the key. The key is in valid characters of the filename without extension?
      // filename: word/fonts/{GUID}.odttf
      final filename = fontFile.name; // word/fonts/{GUID}.odttf
      final keyString =
          filename.split('/').last.split('.').first; // {GUID} or just GUID?
      // addFont generates GUID.
      // Filename usage: `word/fonts/${font.obfuscationKey}.odttf`
      // fontKey in XML: `{${font.obfuscationKey}}`

      // So keyString is the standard GUID string.

      // Re-implement XOR logic to verify
      final obfuscated = fontFile.content;
      expect(obfuscated.length, fontData.length);

      // De-obfuscate to check matches original
      // Logic helper:
      Uint8List parseGuid(String guid) {
        final clean = guid.replaceAll(RegExp(r'[{}-]'), '');
        final bytes = Uint8List(16);
        // Mixed endian
        bytes[3] = int.parse(clean.substring(0, 2), radix: 16);
        bytes[2] = int.parse(clean.substring(2, 4), radix: 16);
        bytes[1] = int.parse(clean.substring(4, 6), radix: 16);
        bytes[0] = int.parse(clean.substring(6, 8), radix: 16);
        bytes[5] = int.parse(clean.substring(8, 10), radix: 16);
        bytes[4] = int.parse(clean.substring(10, 12), radix: 16);
        bytes[7] = int.parse(clean.substring(12, 14), radix: 16);
        bytes[6] = int.parse(clean.substring(14, 16), radix: 16);
        for (var i = 0; i < 8; i++) {
          bytes[8 + i] = int.parse(
              clean.substring(16 + (i * 2), 16 + (i * 2) + 2),
              radix: 16);
        }
        return bytes;
      }

      final keyBytes = parseGuid(keyString);
      final deobfuscated = Uint8List.fromList(obfuscated);
      for (var i = 0; i < 32 && i < deobfuscated.length; i++) {
        deobfuscated[i] = deobfuscated[i] ^ keyBytes[15 - (i % 16)];
      }

      expect(deobfuscated, equals(fontData),
          reason: 'Obfuscation check failed');

      // 4. Verify word/fontTable.xml
      final fontTable = archive.findFile('word/fontTable.xml');
      expect(fontTable, isNotNull);
      final ftXml = XmlDocument.parse(utf8.decode(fontTable!.content));
      final testFontEl = ftXml
          .findAllElements('w:font')
          .firstWhere((e) => e.getAttribute('w:name') == 'TestFont');
      expect(testFontEl, isNotNull);
      final embedEl = testFontEl.findAllElements('w:embedRegular').first;
      expect(embedEl.getAttribute('w:fontKey'), '{$keyString}');
      final rId = embedEl.getAttribute('r:id'); // e.g. rIdFont0

      // 5. Verify word/_rels/fontTable.xml.rels
      final ftRels = archive.findFile('word/_rels/fontTable.xml.rels');
      expect(ftRels, isNotNull);
      final ftrXml = XmlDocument.parse(utf8.decode(ftRels!.content));
      final rel = ftrXml
          .findAllElements('Relationship')
          .firstWhere((e) => e.getAttribute('Id') == rId);
      expect(rel.getAttribute('Target'), 'fonts/$keyString.odttf');
    });

    test('Round-trip font embedding', () async {
      final exporter = DocxExporter();
      final fontData =
          Uint8List.fromList(List.generate(50, (i) => i)); // Dummy data

      final doc1 = DocxBuiltDocument(elements: [DocxParagraph.text('Verify')]);
      // Manually register font or use builder if available?
      // DocxBuiltDocument constructor allows fonts.
      // But we can't easily modify DocxBuiltDocument fonts after creation unless we copy.
      // Or use DocxExporter to add fonts for first export.

      exporter.fontManager.addFont('RoundTripFont', fontData);

      final bytes = await exporter.exportToBytes(doc1);

      // Read back
      final doc2 = await DocxReader.loadFromBytes(bytes);

      expect(doc2.fonts.length, 1);
      final font = doc2.fonts.first;

      expect(font.familyName, 'RoundTripFont');
      expect(font.bytes, equals(fontData)); // De-obfuscation check
      expect(font.obfuscationKey, isNotEmpty);
    });
  });
}
