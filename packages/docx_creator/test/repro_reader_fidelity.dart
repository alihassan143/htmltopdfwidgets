import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  test('DocxReader should preserve inline text properties during round-trip',
      () async {
    // 1. Create a document with various text effects
    final originalDoc = docx()
        .paragraph(DocxParagraph(children: [
          DocxText('Highlight', highlight: DocxHighlight.yellow),
          DocxText('Super', isSuperscript: true),
          DocxText('Sub', isSubscript: true),
          DocxText('Caps', isAllCaps: true),
          DocxText('SmallCaps', isSmallCaps: true),
          DocxText('DoubleStrike', isDoubleStrike: true),
        ]))
        .build();

    // 2. Export to bytes
    final bytes = await DocxExporter().exportToBytes(originalDoc);

    // 3. Read back
    final readDoc = await DocxReader.loadFromBytes(bytes);
    final paragraph = readDoc.elements.first as DocxParagraph;
    final runs = paragraph.children.cast<DocxText>().toList();

    // 4. Verify properties
    // Highlight
    expect(runs[0].content, 'Highlight');
    expect(runs[0].highlight, DocxHighlight.yellow,
        reason: 'Highlight should be preserved');

    // Superscript
    expect(runs[1].content, 'Super');
    expect(runs[1].isSuperscript, isTrue,
        reason: 'Superscript should be preserved');

    // Subscript
    expect(runs[2].content, 'Sub');
    expect(runs[2].isSubscript, isTrue,
        reason: 'Subscript should be preserved');

    // All Caps
    expect(runs[3].content, 'Caps');
    expect(runs[3].isAllCaps, isTrue, reason: 'All Caps should be preserved');

    // Small Caps
    expect(runs[4].content, 'SmallCaps');
    expect(runs[4].isSmallCaps, isTrue,
        reason: 'Small Caps should be preserved');

    // Double Strike
    expect(runs[5].content, 'DoubleStrike');
    expect(runs[5].isDoubleStrike, isTrue,
        reason: 'Double Strike should be preserved');
  });

  test('DocxReader should preserve paragraph alignment', () async {
    final originalDoc = docx()
        .p('Center', align: DocxAlign.center)
        .p('Right', align: DocxAlign.right)
        .build();

    final bytes = await DocxExporter().exportToBytes(originalDoc);
    final readDoc = await DocxReader.loadFromBytes(bytes);

    expect((readDoc.elements[0] as DocxParagraph).align, DocxAlign.center);
    expect((readDoc.elements[1] as DocxParagraph).align, DocxAlign.right);
  });
}
