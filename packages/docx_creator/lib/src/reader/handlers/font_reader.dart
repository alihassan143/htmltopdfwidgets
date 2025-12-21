import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/font_manager.dart';
import '../reader_context.dart';

/// Reads and parses embedded fonts from fontTable.xml.
class FontReader {
  final ReaderContext context;

  FontReader(this.context);

  /// Read embedded fonts from fontTable.xml.
  List<EmbeddedFont> read(String? fontTableXml, String? fontTableRelsXml) {
    if (fontTableXml == null || fontTableRelsXml == null) return [];

    final fonts = <EmbeddedFont>[];

    try {
      final ftXml = XmlDocument.parse(fontTableXml);
      final ftrXml = XmlDocument.parse(fontTableRelsXml);

      // Parse relationships
      final rels = <String, String>{}; // Id -> Target
      for (var rel in ftrXml.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) rels[id] = target;
      }

      // Parse fonts
      for (var fontElem in ftXml.findAllElements('w:font')) {
        final name = fontElem.getAttribute('w:name');
        if (name == null) continue;

        // Check for embedded regular
        final embed = fontElem.findAllElements('w:embedRegular').firstOrNull;
        if (embed != null) {
          final id = embed.getAttribute('r:id');
          final key = embed.getAttribute('w:fontKey'); // {GUID}

          if (id != null && key != null && rels.containsKey(id)) {
            String target = rels[id]!;

            // Locate file in archive
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
