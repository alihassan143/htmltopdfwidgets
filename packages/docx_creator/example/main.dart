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

  final elements = await DocxParser.fromMarkdown(markdown);

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
<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>    body { font-family: Calibri, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
    h1 { font-size: 24pt; color: #2E74B5; }
    h2 { font-size: 18pt; color: #2E74B5; }
    h3 { font-size: 14pt; }
    table { border-collapse: collapse; width: 100%; margin: 1em 0; }
    td, th { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    ul, ol { margin: 1em 0; padding-left: 2em; }
    li { margin-bottom: 0.5em; }
    a { color: #0563C1; }
    img { max-width: 100%; height: auto; }
  </style>
</head><body>
<h1>Document Generation Made Easy</h1>
<p></p>
<p style="text-align: center"><span style="color: #808080;font-size: 16.0pt">A Developer-First DOCX Library for Dart</span></p>
<p></p>
<p style="text-align: center"><span style="color: #D3D3D3">Version 1.0 | December 2024</span></p>
<p></p>
<h1>Table of Contents</h1>
<p></p>
<ol><li>Text Formatting</li><li>Color System</li><li>Headings &amp; Paragraphs</li><li>Lists (Bullet &amp; Numbered)</li><li>Tables &amp; Styling</li><li>Headers &amp; Footers</li><li>Parsing (Markdown &amp; HTML)</li><li>Complete API Reference</li></ol>
<p></p>
<h1>1. Text Formatting</h1>
<p>The package supports comprehensive text formatting options:</p>
<p></p>
<h2>Basic Formatting</h2>
<p>Normal text, <strong>Bold text, </strong><em>Italic text, </em><em><strong>Bold + Italic, </strong></em><u>Underlined text, </u><del>Strikethrough text.</del></p>
<p></p>
<h2>Advanced Formatting</h2>
<p>Superscript: E = mc<sup>2</sup>, Subscript: H<sub>2</sub>O</p>
<p><span style="text-transform: uppercase">All Caps Text</span>, <span style="font-variant: small-caps">Small Caps Text</span></p>
<p><span style="font-family: 'Courier New';background-color: lightGray">inline_code()</span> and <span style="background-color: yellow">highlighted text</span></p>
<p></p>
<h2>Links</h2>
<p>Visit <a href="https://dart.dev"><span style="color: #0000FF"><u>Dart Website</u></span></a> for more information.</p>
<p></p>
<h1>2. Color System</h1>
<p>Use predefined colors or custom hex values:</p>
<p></p>
<h2>Predefined Colors</h2>
<p><span style="color: #FF0000">Red </span><span style="color: #0000FF">Blue </span><span style="color: #00FF00">Green </span><span style="color: #FFA500">Orange </span><span style="color: #800080">Purple </span><span style="color: #808080">Gray </span></p>
<p></p>
<h2>Custom Hex Colors</h2>
<p><span style="color: #4285F4">Google Blue </span><span style="color: #FF5722">Material Orange </span><span style="color: #009688">Teal </span><span style="color: #673AB7">Deep Purple </span></p>
<p></p>
<h2>Brand Colors</h2>
<table><tr><td style="background-color: #4472C4"><p><strong>Brand</strong></p></td><td style="background-color: #4472C4"><p><strong>Primary Color</strong></p></td><td style="background-color: #4472C4"><p><strong>Hex Code</strong></p></td></tr><tr><td><p>Facebook</p></td><td><p>Blue</p></td><td><p>#1877F2</p></td></tr><tr><td><p>Twitter/X</p></td><td><p>Black</p></td><td><p>#000000</p></td></tr><tr><td><p>LinkedIn</p></td><td><p>Blue</p></td><td><p>#0A66C2</p></td></tr><tr><td><p>YouTube</p></td><td><p>Red</p></td><td><p>#FF0000</p></td></tr><tr><td><p>Spotify</p></td><td><p>Green</p></td><td><p>#1DB954</p></td></tr></table>
<p></p>
<h1>3. Headings &amp; Paragraphs</h1>
<p>Six levels of headings are supported:</p>
<p></p>
<h1>Heading 1 - Main Title</h1>
<h2>Heading 2 - Section</h2>
<h3>Heading 3 - Subsection</h3>
<h4>Heading 4 - Minor Section</h4>
<h5>Heading 5 - Subheading</h5>
<h6>Heading 6 - Smallest</h6>
<p></p>
<h2>Paragraph Styles</h2>
<p style="margin-left: 36.0pt"><em>This is a blockquote. Use it for important quotes or callouts. It automatically applies indentation and italic styling.</em></p>
<p></p>
<p>Code blocks are also supported:</p>
<p style="background-color: #F5F5F5"><span style="font-family: 'Courier New';background-color: lightGray">void main() {
  print(&quot;Hello, DOCX!&quot;);
  final doc = docx().h1(&quot;Title&quot;).build();
}</span></p>
<p></p>
<p></p>
<p>Horizontal rules separate content sections.</p>
<p></p>
<h1>4. Lists (Bullet &amp; Numbered)</h1>
<p></p>
<h2>Bullet Lists</h2>
<ul><li>First bullet item</li><li>Second bullet item</li><li>Third bullet item with more text to show wrapping behavior</li><li>Fourth item</li><li>Fifth item</li></ul>
<p></p>
<h2>Numbered Lists</h2>
<ol><li>Step one: Initialize the document</li><li>Step two: Add content using the fluent API</li><li>Step three: Build the document</li><li>Step four: Export to DOCX or HTML</li><li>Step five: Share with your users</li></ol>
<p></p>
<h2>Mixed Content Example</h2>
<p>Here's how to combine different elements:</p>
<ul><li>Introduction paragraph</li><li>Setup requirements</li><li>Implementation details</li></ul>
<p>Each step can have additional explanation text.</p>
<p></p>
<h1>5. Tables &amp; Styling</h1>
<p>Tables support multiple styling options:</p>
<p></p>
<h2>Grid Style (Default)</h2>
<table><tr><td><p><strong>Feature</strong></p></td><td><p><strong>Status</strong></p></td><td><p><strong>Notes</strong></p></td></tr><tr><td><p>Bold</p></td><td><p>✓</p></td><td><p>Implemented</p></td></tr><tr><td><p>Italic</p></td><td><p>✓</p></td><td><p>Implemented</p></td></tr><tr><td><p>Underline</p></td><td><p>✓</p></td><td><p>Implemented</p></td></tr><tr><td><p>Custom Colors</p></td><td><p>✓</p></td><td><p>Hex support</p></td></tr></table>
<p></p>
<h2>Zebra Style (Alternating Rows)</h2>
<table><tr><td style="background-color: #E0E0E0"><p><strong>Month</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Revenue</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Growth</strong></p></td></tr><tr><td><p>January</p></td><td><p>\$10,000</p></td><td><p>+5%</p></td></tr><tr><td style="background-color: #F5F5F5"><p>February</p></td><td style="background-color: #F5F5F5"><p>\$12,500</p></td><td style="background-color: #F5F5F5"><p>+8%</p></td></tr><tr><td><p>March</p></td><td><p>\$15,000</p></td><td><p>+12%</p></td></tr><tr><td style="background-color: #F5F5F5"><p>April</p></td><td style="background-color: #F5F5F5"><p>\$18,000</p></td><td style="background-color: #F5F5F5"><p>+15%</p></td></tr><tr><td><p>May</p></td><td><p>\$22,000</p></td><td><p>+20%</p></td></tr></table>
<p></p>
<h2>Professional Style (Blue Header)</h2>
<table><tr><td style="background-color: #4472C4"><p><strong>Metric</strong></p></td><td style="background-color: #4472C4"><p><strong>Q1</strong></p></td><td style="background-color: #4472C4"><p><strong>Q2</strong></p></td><td style="background-color: #4472C4"><p><strong>Q3</strong></p></td><td style="background-color: #4472C4"><p><strong>Q4</strong></p></td></tr><tr><td><p>Sales</p></td><td><p>1.2M</p></td><td><p>1.5M</p></td><td><p>1.8M</p></td><td><p>2.1M</p></td></tr><tr><td><p>Costs</p></td><td><p>0.8M</p></td><td><p>0.9M</p></td><td><p>1.0M</p></td><td><p>1.1M</p></td></tr><tr><td><p>Profit</p></td><td><p>0.4M</p></td><td><p>0.6M</p></td><td><p>0.8M</p></td><td><p>1.0M</p></td></tr></table>
<p></p>
<h2>Plain Style (No Borders)</h2>
<table><tr><td><p><strong>Name</strong></p></td><td><p><strong>Role</strong></p></td></tr><tr><td><p>Alice</p></td><td><p>Developer</p></td></tr><tr><td><p>Bob</p></td><td><p>Designer</p></td></tr><tr><td><p>Charlie</p></td><td><p>Manager</p></td></tr></table>
<p></p>
<h1>6. Headers &amp; Footers</h1>
<p>The document you're reading demonstrates headers and footers.</p>
<p></p>
<h2>Header Types</h2>
<ul><li>Simple text: DocxHeader.text(&quot;Title&quot;)</li><li>Styled: DocxHeader.styled(&quot;Title&quot;, color: DocxColor.blue)</li><li>Rich content: DocxHeader(children: [...])</li></ul>
<p></p>
<h2>Footer Types</h2>
<ul><li>Simple text: DocxFooter.text(&quot;© 2024&quot;)</li><li>Page numbers: DocxFooter.pageNumbers()</li><li>Styled: DocxFooter.styled(&quot;Confidential&quot;, color: DocxColor.gray)</li></ul>
<p></p>
<h2>Page Layout</h2>
<table><tr><td style="background-color: #E0E0E0"><p><strong>Property</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Default</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Options</strong></p></td></tr><tr><td><p>Orientation</p></td><td><p>Portrait</p></td><td><p>Portrait, Landscape</p></td></tr><tr><td><p>Page Size</p></td><td><p>Letter</p></td><td><p>Letter, A4, Legal, Tabloid</p></td></tr><tr><td><p>Margins</p></td><td><p>1 inch</p></td><td><p>Customizable in twips</p></td></tr></table>
<p></p>
<h1>7. Parsing Capabilities</h1>
<p></p>
<h2>Markdown Parsing</h2>
<p style="background-color: #F5F5F5"><span style="font-family: 'Courier New';background-color: lightGray">final nodes = DocxParser.fromMarkdown(&quot;&quot;&quot;
# Heading
This is **bold** and *italic*.
- Bullet 1
- Bullet 2
&quot;&quot;&quot;);</span></p>
<p></p>
<h2>HTML Parsing</h2>
<p style="background-color: #F5F5F5"><span style="font-family: 'Courier New';background-color: lightGray">final nodes = DocxParser.fromHtml(&quot;&quot;&quot;
&lt;h1&gt;Title&lt;/h1&gt;
&lt;p&gt;&lt;strong&gt;Bold&lt;/strong&gt; and &lt;em&gt;italic&lt;/em&gt;.&lt;/p&gt;
&quot;&quot;&quot;);</span></p>
<p></p>
<h2>Supported Tags</h2>
<table><tr><td style="background-color: #E0E0E0"><p><strong>Markdown</strong></p></td><td style="background-color: #E0E0E0"><p><strong>HTML</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Result</strong></p></td></tr><tr><td><p># Title</p></td><td><p>&lt;h1&gt;Title&lt;/h1&gt;</p></td><td><p>Heading 1</p></td></tr><tr><td style="background-color: #F5F5F5"><p>**bold**</p></td><td style="background-color: #F5F5F5"><p>&lt;strong&gt;bold&lt;/strong&gt;</p></td><td style="background-color: #F5F5F5"><p>Bold text</p></td></tr><tr><td><p>*italic*</p></td><td><p>&lt;em&gt;italic&lt;/em&gt;</p></td><td><p>Italic text</p></td></tr><tr><td style="background-color: #F5F5F5"><p>- item</p></td><td style="background-color: #F5F5F5"><p>&lt;li&gt;item&lt;/li&gt;</p></td><td style="background-color: #F5F5F5"><p>List item</p></td></tr><tr><td><p>`code`</p></td><td><p>&lt;code&gt;code&lt;/code&gt;</p></td><td><p>Inline code</p></td></tr><tr><td style="background-color: #F5F5F5"><p>[link](url)</p></td><td style="background-color: #F5F5F5"><p>&lt;a href=&quot;...&quot;&gt;link&lt;/a&gt;</p></td><td style="background-color: #F5F5F5"><p>Hyperlink</p></td></tr></table>
<p></p>
<h1>8. Complete API Reference</h1>
<p></p>
<h2>Document Builder</h2>
<table><tr><td style="background-color: #E0E0E0"><p><strong>Method</strong></p></td><td style="background-color: #E0E0E0"><p><strong>Description</strong></p></td></tr><tr><td><p>.h1(text)</p></td><td><p>Add heading level 1</p></td></tr><tr><td><p>.h2(text)</p></td><td><p>Add heading level 2</p></td></tr><tr><td><p>.h3(text)</p></td><td><p>Add heading level 3</p></td></tr><tr><td><p>.p(text)</p></td><td><p>Add paragraph</p></td></tr><tr><td><p>.bullet([...])</p></td><td><p>Add bullet list</p></td></tr><tr><td><p>.numbered([...])</p></td><td><p>Add numbered list</p></td></tr><tr><td><p>.table(data)</p></td><td><p>Add table</p></td></tr><tr><td><p>.quote(text)</p></td><td><p>Add blockquote</p></td></tr><tr><td><p>.code(text)</p></td><td><p>Add code block</p></td></tr><tr><td><p>.hr()</p></td><td><p>Add horizontal rule</p></td></tr><tr><td><p>.pageBreak()</p></td><td><p>Add page break</p></td></tr><tr><td><p>.section(...)</p></td><td><p>Set page properties</p></td></tr><tr><td><p>.build()</p></td><td><p>Build document</p></td></tr></table>
<p></p>
<h2>Export Options</h2>
<ul><li>DocxExporter().exportToFile(doc, &quot;output.docx&quot;)</li><li>DocxExporter().exportToBytes(doc)</li><li>HtmlExporter().export(doc)</li></ul>
<p></p>
<p>Thank you for using docx_creator!</p>
</body></html>

''';

  final elements = await DocxParser.fromHtml(html);

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
