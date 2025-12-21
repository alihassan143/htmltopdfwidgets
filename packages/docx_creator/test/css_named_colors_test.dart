import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('CSS Named Color Support', () {
    test('Complex CSS color names from user test scenario', () async {
      final testHtml = '''
        <p><span style="color: dodgerblue; background-color: ghostwhite;">Complex Colors</span></p>
        <p><span style="color: mediumvioletred;">Another Test</span></p>
        <p><span style="color: darkolivegreen;">Final Test</span></p>
      ''';

      final nodes = await DocxParser.fromHtml(testHtml);

      expect(nodes.length, 3);

      // First paragraph: dodgerblue on ghostwhite
      final p1 = nodes[0] as DocxParagraph;
      final t1 = p1.children.first as DocxText;
      expect(t1.content, 'Complex Colors');
      expect(t1.color?.hex, '1E90FF', reason: 'dodgerblue = 1E90FF');
      expect(t1.shadingFill, 'F8F8FF', reason: 'ghostwhite = F8F8FF');

      // Second paragraph: mediumvioletred
      final p2 = nodes[1] as DocxParagraph;
      final t2 = p2.children.first as DocxText;
      expect(t2.content, 'Another Test');
      expect(t2.color?.hex, 'C71585', reason: 'mediumvioletred = C71585');

      // Third paragraph: darkolivegreen
      final p3 = nodes[2] as DocxParagraph;
      final t3 = p3.children.first as DocxText;
      expect(t3.content, 'Final Test');
      expect(t3.color?.hex, '556B2F', reason: 'darkolivegreen = 556B2F');
    });

    test('Grey/Gray spelling variations', () async {
      final greyVariations = [
        ('grey', '808080'),
        ('gray', '808080'),
        ('darkgrey', 'A9A9A9'),
        ('darkgray', 'A9A9A9'),
        ('lightgrey', 'D3D3D3'),
        ('lightgray', 'D3D3D3'),
        ('dimgrey', '696969'),
        ('dimgray', '696969'),
        ('slategrey', '708090'),
        ('slategray', '708090'),
      ];

      for (final (colorName, expectedHex) in greyVariations) {
        final html = '<p style="color: $colorName;">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, expectedHex,
            reason: '$colorName should be $expectedHex');
      }
    });

    test('All basic CSS colors', () async {
      final basicColors = {
        'black': '000000',
        'white': 'FFFFFF',
        'red': 'FF0000',
        'green': '008000',
        'blue': '0000FF',
        'yellow': 'FFFF00',
        'cyan': '00FFFF',
        'magenta': 'FF00FF',
        'aqua': '00FFFF',
        'fuchsia': 'FF00FF',
        'lime': '00FF00',
        'maroon': '800000',
        'navy': '000080',
        'olive': '808000',
        'purple': '800080',
        'silver': 'C0C0C0',
        'teal': '008080',
      };

      for (final entry in basicColors.entries) {
        final html = '<p style="color: ${entry.key};">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, entry.value,
            reason: '${entry.key} should be ${entry.value}');
      }
    });

    test('Extended blue colors', () async {
      final blueColors = {
        'powderblue': 'B0E0E6',
        'lightblue': 'ADD8E6',
        'lightskyblue': '87CEFA',
        'skyblue': '87CEEB',
        'deepskyblue': '00BFFF',
        'dodgerblue': '1E90FF',
        'cornflowerblue': '6495ED',
        'steelblue': '4682B4',
        'royalblue': '4169E1',
        'mediumblue': '0000CD',
        'darkblue': '00008B',
        'midnightblue': '191970',
      };

      for (final entry in blueColors.entries) {
        final html = '<p style="color: ${entry.key};">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, entry.value,
            reason: '${entry.key} should be ${entry.value}');
      }
    });

    test('Extended green colors', () async {
      final greenColors = {
        'darkgreen': '006400',
        'darkolivegreen': '556B2F',
        'forestgreen': '228B22',
        'seagreen': '2E8B57',
        'olivedrab': '6B8E23',
        'mediumseagreen': '3CB371',
        'limegreen': '32CD32',
        'springgreen': '00FF7F',
        'chartreuse': '7FFF00',
        'lightgreen': '90EE90',
        'palegreen': '98FB98',
      };

      for (final entry in greenColors.entries) {
        final html = '<p style="color: ${entry.key};">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, entry.value,
            reason: '${entry.key} should be ${entry.value}');
      }
    });

    test('Extended purple/violet colors', () async {
      final purpleColors = {
        'lavender': 'E6E6FA',
        'plum': 'DDA0DD',
        'violet': 'EE82EE',
        'orchid': 'DA70D6',
        'mediumorchid': 'BA55D3',
        'mediumpurple': '9370DB',
        'rebeccapurple': '663399',
        'blueviolet': '8A2BE2',
        'darkviolet': '9400D3',
        'darkorchid': '9932CC',
        'darkmagenta': '8B008B',
        'indigo': '4B0082',
        'slateblue': '6A5ACD',
        'darkslateblue': '483D8B',
        'mediumslateblue': '7B68EE',
      };

      for (final entry in purpleColors.entries) {
        final html = '<p style="color: ${entry.key};">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, entry.value,
            reason: '${entry.key} should be ${entry.value}');
      }
    });

    test('White-ish colors', () async {
      final whiteColors = {
        'snow': 'FFFAFA',
        'honeydew': 'F0FFF0',
        'mintcream': 'F5FFFA',
        'azure': 'F0FFFF',
        'aliceblue': 'F0F8FF',
        'ghostwhite': 'F8F8FF',
        'whitesmoke': 'F5F5F5',
        'seashell': 'FFF5EE',
        'beige': 'F5F5DC',
        'oldlace': 'FDF5E6',
        'floralwhite': 'FFFAF0',
        'ivory': 'FFFFF0',
        'antiquewhite': 'FAEBD7',
        'linen': 'FAF0E6',
        'lavenderblush': 'FFF0F5',
        'mistyrose': 'FFE4E1',
        'papayawhip': 'FFEFD5',
      };

      for (final entry in whiteColors.entries) {
        final html = '<p style="color: ${entry.key};">Test</p>';
        final nodes = await DocxParser.fromHtml(html);
        final text = (nodes.first as DocxParagraph).children.first as DocxText;
        expect(text.color?.hex, entry.value,
            reason: '${entry.key} should be ${entry.value}');
      }
    });

    test('Transparent color returns null', () async {
      final html = '<p style="color: transparent;">Test</p>';
      final nodes = await DocxParser.fromHtml(html);
      final text = (nodes.first as DocxParagraph).children.first as DocxText;
      // Transparent should not apply a color, defaults to black
      expect(text.color?.hex, '000000');
    });

    test('Case insensitivity', () async {
      // The colors should work regardless of case (lowercased internally)
      final html = '<p style="color: DodgerBlue;">Test</p>';
      final nodes = await DocxParser.fromHtml(html);
      final text = (nodes.first as DocxParagraph).children.first as DocxText;
      expect(text.color?.hex, '1E90FF');
    });
  });
}
