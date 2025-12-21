/// Comprehensive HTML Parser Example
///
/// This example demonstrates ALL features of parsing HTML to DOCX
/// using the DocxParser.fromHtml() method.
///
/// Run with: dart run example/html_parser_example.dart
library;

import 'package:docx_creator/docx_creator.dart';

Future<void> main() async {
  print('='.padRight(60, '='));
  print('DocxCreator - HTML Parser Complete Example');
  print('='.padRight(60, '='));

  // ============================================================
  // Comprehensive HTML with ALL supported features
  // ============================================================

  const htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    .highlight { background-color: yellow; }
    .important { color: red; font-weight: bold; }
    .code-block { background-color: #f5f5f5; font-family: monospace; }
    .center { text-align: center; }
    .blue-bg { background-color: #E0F0FF; }
  </style>
</head>
<body>

<!-- HEADINGS -->
<h1>HTML to DOCX - Complete Feature Demo</h1>
<h2>All Supported HTML Elements</h2>
<h3>Section 1: Text Formatting</h3>
<h4>Subsection 1.1</h4>
<h5>Detail Level</h5>
<h6>Smallest Heading</h6>

<!-- PARAGRAPHS -->
<p>This is a simple paragraph. Paragraphs are the basic building blocks of documents.</p>

<p>
  Multiple sentences in one paragraph. The HTML parser correctly handles
  whitespace and line breaks within paragraph tags, combining them into
  proper Word paragraphs.
</p>

<!-- TEXT FORMATTING -->
<h3>Text Formatting</h3>

<p>
  <b>Bold text</b> and <strong>strong text</strong> both work.
  <i>Italic text</i> and <em>emphasized text</em> are supported.
  <u>Underlined text</u> for emphasis.
  <s>Strikethrough text</s> and <del>deleted text</del>.
  <mark>Marked/highlighted text</mark> stands out.
</p>

<p>
  Combined formatting: <b><i>bold italic</i></b>,
  <strong><u>strong underline</u></strong>,
  <b><i><u>all three combined</u></i></b>.
</p>

<!-- COLORS -->
<h3>Colors - CSS Named Colors</h3>

<p>
  <span style="color: red;">Red text</span>,
  <span style="color: blue;">Blue text</span>,
  <span style="color: green;">Green text</span>,
  <span style="color: #FF6600;">Custom orange (#FF6600)</span>,
  <span style="color: dodgerblue;">DodgerBlue</span>,
  <span style="color: mediumvioletred;">MediumVioletRed</span>,
  <span style="color: darkolivegreen;">DarkOliveGreen</span>,
  <span style="color: papayawhip;">PapayaWhip</span>.
</p>

<p>
  Background colors:
  <span style="background-color: yellow;">Yellow background</span>,
  <span style="background-color: lightgray; color: black;">Light gray</span>,
  <span style="background-color: #000000; color: white;">White on black</span>,
  <span style="background-color: ghostwhite; color: dodgerblue;">GhostWhite + DodgerBlue</span>.
</p>

<!-- FONT SIZES -->
<h3>Font Sizes</h3>

<p>
  <span style="font-size: 8px;">8px text</span>,
  <span style="font-size: 12px;">12px text</span>,
  <span style="font-size: 16px;">16px text</span>,
  <span style="font-size: 24px;">24px text</span>,
  <span style="font-size: 32px;">32px text</span>.
</p>

<!-- SUPERSCRIPT AND SUBSCRIPT -->
<h3>Superscript and Subscript</h3>

<p>
  Einstein's equation: E=mc<sup>2</sup><br>
  Water molecule: H<sub>2</sub>O<br>
  Quadratic: x<sup>2</sup> + 2x + 1 = 0<br>
  Chemical: CO<sub>2</sub> + H<sub>2</sub>O → H<sub>2</sub>CO<sub>3</sub>
</p>

<!-- TEXT ALIGNMENT -->
<h3>Text Alignment</h3>

<p style="text-align: left;">Left aligned paragraph (default).</p>
<p style="text-align: center;">Center aligned paragraph.</p>
<p style="text-align: right;">Right aligned paragraph.</p>
<p style="text-align: justify;">
  Justified paragraph. This text is stretched to fill the entire width
  of the line by adjusting the spacing between words. This is commonly
  used in newspapers, books, and formal documents for a clean appearance.
</p>

<!-- LISTS -->
<h3>Unordered Lists (Bullets)</h3>

<ul>
  <li>First bullet item</li>
  <li>Second bullet item</li>
  <li>Third bullet item with <b>bold</b> and <i>italic</i> text</li>
  <li>Fourth item with <a href="https://google.com">a link</a></li>
</ul>

<h3>Ordered Lists (Numbered)</h3>

<ol>
  <li>First numbered item</li>
  <li>Second numbered item</li>
  <li>Third numbered item</li>
</ol>

<h3>Nested Lists</h3>

<ul>
  <li>Level 1 - Item A
    <ul>
      <li>Level 2 - Item A.1
        <ul>
          <li>Level 3 - Item A.1.a</li>
          <li>Level 3 - Item A.1.b</li>
        </ul>
      </li>
      <li>Level 2 - Item A.2</li>
    </ul>
  </li>
  <li>Level 1 - Item B</li>
  <li>Level 1 - Item C
    <ol>
      <li>Numbered sub-item 1</li>
      <li>Numbered sub-item 2</li>
    </ol>
  </li>
</ul>

<!-- TABLES -->
<h3>Simple Table</h3>

<table border="1">
  <tr>
    <th>Header 1</th>
    <th>Header 2</th>
    <th>Header 3</th>
  </tr>
  <tr>
    <td>Row 1, Cell 1</td>
    <td>Row 1, Cell 2</td>
    <td>Row 1, Cell 3</td>
  </tr>
  <tr>
    <td>Row 2, Cell 1</td>
    <td>Row 2, Cell 2</td>
    <td>Row 2, Cell 3</td>
  </tr>
</table>

<h3>Styled Table with CSS</h3>

<table border="1" style="width: 100%;">
  <tr style="background-color: #4472C4; color: white;">
    <th>Product</th>
    <th>Price</th>
    <th>Stock</th>
  </tr>
  <tr>
    <td>Widget A</td>
    <td style="background-color: #E2EFDA;">\$19.99</td>
    <td>150</td>
  </tr>
  <tr>
    <td>Widget B</td>
    <td style="background-color: #E2EFDA;">\$29.99</td>
    <td>75</td>
  </tr>
  <tr>
    <td><b>Total</b></td>
    <td style="background-color: #FFF2CC;"><b>\$49.98</b></td>
    <td><b>225</b></td>
  </tr>
</table>

<!-- LINKS -->
<h3>Hyperlinks</h3>

<p>
  Visit <a href="https://www.google.com">Google</a> for search,
  <a href="https://github.com">GitHub</a> for code,
  or <a href="https://flutter.dev">Flutter</a> for mobile development.
</p>

<p>
  Email link: <a href="mailto:example@example.com">example@example.com</a>
</p>

<!-- CODE -->
<h3>Code Elements</h3>

<p>
  Inline code: <code>print("Hello, World!");</code> is a simple statement.
</p>

<p>
  Variable names like <code>myVariable</code> and functions like
  <code>calculateTotal()</code> should use code formatting.
</p>

<pre><code>// Multi-line code block
void main() {
  final message = "Hello from HTML!";
  print(message);
  
  for (var i = 0; i < 5; i++) {
    print("Iteration: \$i");
  }
}</code></pre>

<h3>Syntax Highlighted Code Block</h3>

<pre style="background-color: #1e1e1e;"><code style="color: #9cdcfe;">
<span style="color: #569cd6;">class</span> <span style="color: #4ec9b0;">Person</span> {
  <span style="color: #569cd6;">final</span> <span style="color: #4ec9b0;">String</span> name;
  <span style="color: #569cd6;">final</span> <span style="color: #4ec9b0;">int</span> age;
  
  <span style="color: #4ec9b0;">Person</span>(<span style="color: #569cd6;">this</span>.name, <span style="color: #569cd6;">this</span>.age);
  
  <span style="color: #569cd6;">void</span> <span style="color: #dcdcaa;">greet</span>() {
    <span style="color: #dcdcaa;">print</span>(<span style="color: #ce9178;">'Hello, I am \$name'</span>);
  }
}
</code></pre>

<!-- BLOCKQUOTES -->
<h3>Blockquotes</h3>

<blockquote>
  This is a blockquote. It's commonly used to highlight quotes,
  important notes, or referenced text from other sources.
</blockquote>

<blockquote style="border-left: 4px solid #4472C4; padding-left: 16px;">
  <p><b>Note:</b> Styled blockquote with a left border.</p>
  <p>This creates a visually distinct callout section.</p>
</blockquote>

<!-- HORIZONTAL RULE -->
<h3>Horizontal Rules</h3>

<p>Content above the horizontal rule.</p>
<hr>
<p>Content below the horizontal rule.</p>

<!-- LINE BREAKS -->
<h3>Line Breaks</h3>

<p>
  First line<br>
  Second line<br>
  Third line
</p>

<!-- DIVS WITH STYLING -->
<h3>Styled Divs</h3>

<div style="background-color: #E0F0FF; padding: 10px; border: 1px solid #4472C4;">
  <p><b>Info Box</b></p>
  <p>This is a styled div that acts as an information box.</p>
</div>

<div style="background-color: #FFF0F0; padding: 10px; border: 1px solid #C44444;">
  <p><b>Warning Box</b></p>
  <p style="color: #C44444;">This is a warning message with red styling.</p>
</div>

<!-- CSS CLASSES -->
<h3>CSS Classes</h3>

<p class="highlight">This paragraph uses the .highlight class for yellow background.</p>
<p class="important">This paragraph uses the .important class for red bold text.</p>
<p class="center">This paragraph uses the .center class for center alignment.</p>

<!-- CHECKBOXES -->
<h3>Checkboxes</h3>

<p>[ ] Unchecked checkbox item</p>
<p>[x] Checked checkbox item</p>
<p>[ ] Another unchecked item</p>
<p>[x] Another checked item</p>

<!-- COMBINED COMPLEX EXAMPLE -->
<h3>Complex Combined Example</h3>

<div style="background-color: #f9f9f9; padding: 15px;">
  <h4 style="color: #333;">Project Status Report</h4>
  <table border="1" style="width: 100%;">
    <tr style="background-color: #333; color: white;">
      <th>Task</th>
      <th>Status</th>
      <th>Owner</th>
    </tr>
    <tr>
      <td><b>Design Phase</b></td>
      <td style="background-color: #90EE90;">Complete</td>
      <td>Alice</td>
    </tr>
    <tr>
      <td><b>Development</b></td>
      <td style="background-color: #FFD700;">In Progress</td>
      <td>Bob</td>
    </tr>
    <tr>
      <td><b>Testing</b></td>
      <td style="background-color: #FFB6C1;">Pending</td>
      <td>Charlie</td>
    </tr>
  </table>
  <p style="margin-top: 10px;">
    <i>Last updated: December 2024</i>
  </p>
</div>

</body>
</html>
''';

  print('\n📝 Parsing comprehensive HTML content...');

  // Parse HTML to DocxNodes
  final nodes = await DocxParser.fromHtml(htmlContent);

  print('✅ Parsed ${nodes.length} document elements');

  // Create document and export
  final doc = DocxBuiltDocument(elements: nodes);
  final exporter = DocxExporter();
  await exporter.exportToFile(doc, 'html_parser_complete.docx');

  print('✅ Created: html_parser_complete.docx');

  print('\nFeatures demonstrated:');
  print('  • Headings (h1-h6)');
  print('  • Paragraphs with text');
  print('  • Bold, italic, underline, strikethrough');
  print('  • Mark/highlight');
  print('  • All 141 CSS named colors');
  print('  • Custom hex colors');
  print('  • Background colors');
  print('  • Font sizes');
  print('  • Superscript and subscript');
  print('  • Text alignment (left, center, right, justify)');
  print('  • Unordered lists (bullets)');
  print('  • Ordered lists (numbers)');
  print('  • Nested lists (multi-level)');
  print('  • Simple and styled tables');
  print('  • Hyperlinks');
  print('  • Inline code');
  print('  • Code blocks (pre/code)');
  print('  • Syntax highlighted code');
  print('  • Blockquotes');
  print('  • Horizontal rules');
  print('  • Line breaks');
  print('  • Styled divs');
  print('  • CSS classes (<style> block)');
  print('  • Checkboxes [ ] and [x]');
  print('  • Complex nested structures');
}
