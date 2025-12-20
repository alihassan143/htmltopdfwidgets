/// Comprehensive Document Creator Example
///
/// Demonstrates all package capabilities with long, beautiful documents.
library;

import 'package:docx_creator/docx_creator.dart';

void main() async {
  print('🚀 Creating comprehensive document samples...\n');

  // ====================================================
  // 1. MANUAL DOCUMENT - Full API Showcase (10+ pages)
  // ====================================================
  await createManualDocument();

  // ====================================================
  // 2. MARKDOWN DOCUMENT - Parsed from Markdown
  // ====================================================
  await createMarkdownDocument();

  // ====================================================
  // 3. HTML DOCUMENT - Parsed from HTML
  // ====================================================
  await createHtmlDocument();

  print('\n🎉 All documents created successfully!');
}

Future<void> createManualDocument() async {
  print('📄 Creating manual_showcase.docx...');

  final doc = docx()
      // === PAGE 1: Title Page ===
      .section(
        header: DocxHeader.styled(
          'DOCX AI Creator',
          color: DocxColor.blue,
          bold: true,
        ),
        footer: DocxFooter.pageNumbers(),
      )
      .h1('Document Generation Made Easy')
      .p('')
      .paragraph(
        DocxParagraph(
          align: DocxAlign.center,
          children: [
            DocxText(
              'A Developer-First DOCX Library for Dart',
              fontSize: 16,
              color: DocxColor.gray,
            ),
          ],
        ),
      )
      .p('')
      .paragraph(
        DocxParagraph(
          align: DocxAlign.center,
          children: [
            DocxText('Version 1.0 | December 2024', color: DocxColor.lightGray),
          ],
        ),
      )
      .pageBreak()
      // === PAGE 2: Table of Contents ===
      .h1('Table of Contents')
      .p('')
      .numbered([
        'Text Formatting',
        'Color System',
        'Headings & Paragraphs',
        'Lists (Bullet & Numbered)',
        'Tables & Styling',
        'Headers & Footers',
        'Parsing (Markdown & HTML)',
        'Complete API Reference',
      ])
      .pageBreak()
      // === PAGE 3: Text Formatting ===
      .h1('1. Text Formatting')
      .p('The package supports comprehensive text formatting options:')
      .p('')
      .h2('Basic Formatting')
      .paragraph(
        DocxParagraph(
          children: [
            DocxText('Normal text, '),
            DocxText.bold('Bold text, '),
            DocxText.italic('Italic text, '),
            DocxText.boldItalic('Bold + Italic, '),
            DocxText.underline('Underlined text, '),
            DocxText.strike('Strikethrough text.'),
          ],
        ),
      )
      .p('')
      .h2('Advanced Formatting')
      .paragraph(
        DocxParagraph(
          children: [
            DocxText('Superscript: E = mc'),
            DocxText.superscript('2'),
            DocxText(', Subscript: H'),
            DocxText.subscript('2'),
            DocxText('O'),
          ],
        ),
      )
      .paragraph(
        DocxParagraph(
          children: [
            DocxText.allCaps('All Caps Text'),
            DocxText(', '),
            DocxText.smallCaps('Small Caps Text'),
          ],
        ),
      )
      .paragraph(
        DocxParagraph(
          children: [
            DocxText.code('inline_code()'),
            DocxText(' and '),
            DocxText.highlighted('highlighted text'),
          ],
        ),
      )
      .p('')
      .h2('Links')
      .paragraph(
        DocxParagraph(
          children: [
            DocxText('Visit '),
            DocxText.link('Dart Website', href: 'https://dart.dev'),
            DocxText(' for more information.'),
          ],
        ),
      )
      .pageBreak()
      // === PAGE 4: Color System ===
      .h1('2. Color System')
      .p('Use predefined colors or custom hex values:')
      .p('')
      .h2('Predefined Colors')
      .paragraph(
        DocxParagraph(
          children: [
            DocxText('Red ', color: DocxColor.red),
            DocxText('Blue ', color: DocxColor.blue),
            DocxText('Green ', color: DocxColor.green),
            DocxText('Orange ', color: DocxColor.orange),
            DocxText('Purple ', color: DocxColor.purple),
            DocxText('Gray ', color: DocxColor.gray),
          ],
        ),
      )
      .p('')
      .h2('Custom Hex Colors')
      .paragraph(
        DocxParagraph(
          children: [
            DocxText('Google Blue ', color: DocxColor('4285F4')),
            DocxText('Material Orange ', color: DocxColor('FF5722')),
            DocxText('Teal ', color: DocxColor('009688')),
            DocxText('Deep Purple ', color: DocxColor('673AB7')),
          ],
        ),
      )
      .p('')
      .h2('Brand Colors')
      .table([
        ['Brand', 'Primary Color', 'Hex Code'],
        ['Facebook', 'Blue', '#1877F2'],
        ['Twitter/X', 'Black', '#000000'],
        ['LinkedIn', 'Blue', '#0A66C2'],
        ['YouTube', 'Red', '#FF0000'],
        ['Spotify', 'Green', '#1DB954'],
      ], style: DocxTableStyle.professional)
      .pageBreak()
      // === PAGE 5: Headings ===
      .h1('3. Headings & Paragraphs')
      .p('Six levels of headings are supported:')
      .p('')
      .h1('Heading 1 - Main Title')
      .h2('Heading 2 - Section')
      .h3('Heading 3 - Subsection')
      .paragraph(DocxParagraph.heading4('Heading 4 - Minor Section'))
      .paragraph(DocxParagraph.heading5('Heading 5 - Subheading'))
      .paragraph(DocxParagraph.heading6('Heading 6 - Smallest'))
      .p('')
      .h2('Paragraph Styles')
      .quote(
        'This is a blockquote. Use it for important quotes or callouts. It automatically applies indentation and italic styling.',
      )
      .p('')
      .p('Code blocks are also supported:')
      .code(
        'void main() {\n  print("Hello, DOCX!");\n  final doc = docx().h1("Title").build();\n}',
      )
      .p('')
      .hr()
      .p('Horizontal rules separate content sections.')
      .pageBreak()
      // === PAGE 6: Lists ===
      .h1('4. Lists (Bullet & Numbered)')
      .p('')
      .h2('Bullet Lists')
      .bullet([
        'First bullet item',
        'Second bullet item',
        'Third bullet item with more text to show wrapping behavior',
        'Fourth item',
        'Fifth item',
      ])
      .p('')
      .h2('Numbered Lists')
      .numbered([
        'Step one: Initialize the document',
        'Step two: Add content using the fluent API',
        'Step three: Build the document',
        'Step four: Export to DOCX or HTML',
        'Step five: Share with your users',
      ])
      .p('')
      .h2('Mixed Content Example')
      .p('Here\'s how to combine different elements:')
      .bullet([
        'Introduction paragraph',
        'Setup requirements',
        'Implementation details',
      ])
      .p('Each step can have additional explanation text.')
      .pageBreak()
      // === PAGE 7-8: Tables ===
      .h1('5. Tables & Styling')
      .p('Tables support multiple styling options:')
      .p('')
      .h2('Grid Style (Default)')
      .table([
        ['Feature', 'Status', 'Notes'],
        ['Bold', '✓', 'Implemented'],
        ['Italic', '✓', 'Implemented'],
        ['Underline', '✓', 'Implemented'],
        ['Custom Colors', '✓', 'Hex support'],
      ], style: DocxTableStyle.grid)
      .p('')
      .h2('Zebra Style (Alternating Rows)')
      .table([
        ['Month', 'Revenue', 'Growth'],
        ['January', '\$10,000', '+5%'],
        ['February', '\$12,500', '+8%'],
        ['March', '\$15,000', '+12%'],
        ['April', '\$18,000', '+15%'],
        ['May', '\$22,000', '+20%'],
      ], style: DocxTableStyle.zebra)
      .pageBreak()
      .h2('Professional Style (Blue Header)')
      .table([
        ['Metric', 'Q1', 'Q2', 'Q3', 'Q4'],
        ['Sales', '1.2M', '1.5M', '1.8M', '2.1M'],
        ['Costs', '0.8M', '0.9M', '1.0M', '1.1M'],
        ['Profit', '0.4M', '0.6M', '0.8M', '1.0M'],
      ], style: DocxTableStyle.professional)
      .p('')
      .h2('Plain Style (No Borders)')
      .table([
        ['Name', 'Role'],
        ['Alice', 'Developer'],
        ['Bob', 'Designer'],
        ['Charlie', 'Manager'],
      ], style: DocxTableStyle.plain)
      .pageBreak()
      // === PAGE 9: Headers & Footers ===
      .h1('6. Headers & Footers')
      .p('The document you\'re reading demonstrates headers and footers.')
      .p('')
      .h2('Header Types')
      .bullet([
        'Simple text: DocxHeader.text("Title")',
        'Styled: DocxHeader.styled("Title", color: DocxColor.blue)',
        'Rich content: DocxHeader(children: [...])',
      ])
      .p('')
      .h2('Footer Types')
      .bullet([
        'Simple text: DocxFooter.text("© 2024")',
        'Page numbers: DocxFooter.pageNumbers()',
        'Styled: DocxFooter.styled("Confidential", color: DocxColor.gray)',
      ])
      .p('')
      .h2('Page Layout')
      .table([
        ['Property', 'Default', 'Options'],
        ['Orientation', 'Portrait', 'Portrait, Landscape'],
        ['Page Size', 'Letter', 'Letter, A4, Legal, Tabloid'],
        ['Margins', '1 inch', 'Customizable in twips'],
      ], style: DocxTableStyle.headerHighlight)
      .pageBreak()
      // === PAGE 10: Parsing ===
      .h1('7. Parsing Capabilities')
      .p('')
      .h2('Markdown Parsing')
      .code(
        'final nodes = DocxParser.fromMarkdown("""\n# Heading\nThis is **bold** and *italic*.\n- Bullet 1\n- Bullet 2\n""");',
      )
      .p('')
      .h2('HTML Parsing')
      .code(
        'final nodes = DocxParser.fromHtml("""\n<h1>Title</h1>\n<p><strong>Bold</strong> and <em>italic</em>.</p>\n""");',
      )
      .p('')
      .h2('Supported Tags')
      .table([
        ['Markdown', 'HTML', 'Result'],
        ['# Title', '<h1>Title</h1>', 'Heading 1'],
        ['**bold**', '<strong>bold</strong>', 'Bold text'],
        ['*italic*', '<em>italic</em>', 'Italic text'],
        ['- item', '<li>item</li>', 'List item'],
        ['`code`', '<code>code</code>', 'Inline code'],
        ['[link](url)', '<a href="...">link</a>', 'Hyperlink'],
      ], style: DocxTableStyle.zebra)
      .pageBreak()
      // === PAGE 11: API Reference ===
      .h1('8. Complete API Reference')
      .p('')
      .h2('Document Builder')
      .table([
        ['Method', 'Description'],
        ['.h1(text)', 'Add heading level 1'],
        ['.h2(text)', 'Add heading level 2'],
        ['.h3(text)', 'Add heading level 3'],
        ['.p(text)', 'Add paragraph'],
        ['.bullet([...])', 'Add bullet list'],
        ['.numbered([...])', 'Add numbered list'],
        ['.table(data)', 'Add table'],
        ['.quote(text)', 'Add blockquote'],
        ['.code(text)', 'Add code block'],
        ['.hr()', 'Add horizontal rule'],
        ['.pageBreak()', 'Add page break'],
        ['.section(...)', 'Set page properties'],
        ['.build()', 'Build document'],
      ], style: DocxTableStyle.headerHighlight)
      .p('')
      .h2('Export Options')
      .bullet([
        'DocxExporter().exportToFile(doc, "output.docx")',
        'DocxExporter().exportToBytes(doc)',
        'HtmlExporter().export(doc)',
      ])
      .p('')
      .p('Thank you for using docx_creator!')
      .build();

  await DocxExporter().exportToFile(doc, 'manual_showcase.docx');
  print('   ✓ Created manual_showcase.docx (11 pages)');
}

Future<void> createMarkdownDocument() async {
  print('📝 Creating markdown_parsed.docx...');

  const markdown = '''
# Markdown Document Example

This document was generated by parsing **Markdown** content.

## Features Demonstrated

The following features are parsed from Markdown syntax:

### Text Formatting

This paragraph contains **bold text**, *italic text*, and `inline code`.

### Lists

Unordered list:
- First item
- Second item
- Third item
- Fourth item

Ordered list:
1. Step one
2. Step two
3. Step three
4. Step four

### Tables

| Name | Role | Department |
|------|------|------------|
| Alice | Developer | Engineering |
| Bob | Designer | Creative |
| Charlie | Manager | Operations |
| Diana | Analyst | Data |

### Blockquotes

> This is a blockquote. It can span multiple lines and is commonly used for citations or important notes.

### Code Blocks

```dart
void main() {
  final doc = docx()
    .h1('Title')
    .p('Content')
    .build();
}
```

## Conclusion

Markdown parsing makes it easy to convert existing content to DOCX format.
''';

  final elements = DocxParser.fromMarkdown(markdown);

  final builder = docx().section(
    header: DocxHeader.text('Markdown Example'),
    footer: DocxFooter.pageNumbers(),
  );

  for (var element in elements) {
    builder.add(element);
  }

  final doc = builder.build();
  await DocxExporter().exportToFile(doc, 'markdown_parsed.docx');
  print('   ✓ Created markdown_parsed.docx');
}

Future<void> createHtmlDocument() async {
  print('🌐 Creating html_parsed.docx...');

  const html = '''
<h1>HTML Document Example</h1>

<p>This document was generated by parsing <strong>HTML</strong> content.</p>

<h2>Text Formatting</h2>

<p>
  HTML supports <strong>bold</strong>, <em>italic</em>, 
  <u>underline</u>, and <del>strikethrough</del> text.
</p>

<p>
  You can also use <code>inline code</code>, 
  <sup>superscript</sup>, and <sub>subscript</sub>.
</p>

<h2>Lists</h2>

<h3>Unordered List</h3>
<ul>
  <li>HTML parsing</li>
  <li>CSS styles</li>
  <li>Rich content</li>
  <li>Easy conversion</li>
</ul>

<h3>Ordered List</h3>
<ol>
  <li>Parse HTML</li>
  <li>Convert to AST</li>
  <li>Export to DOCX</li>
  <li>Open in Word</li>
</ol>

<h2>Tables</h2>

<table>
  <tr>
    <th>Product</th>
    <th>Price</th>
    <th>Stock</th>
  </tr>
  <tr>
    <td>Widget A</td>
    <td>\$10.00</td>
    <td>In Stock</td>
  </tr>
  <tr>
    <td>Widget B</td>
    <td>\$15.00</td>
    <td>Low Stock</td>
  </tr>
  <tr>
    <td>Widget C</td>
    <td>\$20.00</td>
    <td>Out of Stock</td>
  </tr>
</table>

<h2>Blockquote</h2>

<blockquote>
  The best way to predict the future is to invent it.
  - Alan Kay
</blockquote>

<h2>Conclusion</h2>

<p>
  HTML parsing enables easy conversion of web content to Word documents.
</p>
''';

  final elements = DocxParser.fromHtml(html);

  final builder = docx().section(
    header: DocxHeader.styled('HTML Example', color: DocxColor('4285F4')),
    footer: DocxFooter.text('Generated from HTML'),
  );

  for (var element in elements) {
    builder.add(element);
  }

  final doc = builder.build();
  await DocxExporter().exportToFile(doc, 'html_parsed.docx');
  print('   ✓ Created html_parsed.docx');
}
