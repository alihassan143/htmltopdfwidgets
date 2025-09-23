/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';

import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:htmltopdfwidgets/src/extension/color_extension.dart';
import 'package:test/test.dart';

late Document pdf;
late Document marDownPdf;

void main() {
  const htmlText = '''  <h1>Heading Example</h1>
  <p>This is a paragraph.</p>
  <img src="image.jpg" alt="Example Image" />
  <blockquote>This is a quote.</blockquote>
  <ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
  </ul>
  <table>
  <tr>
    <th>Company</th>
    <th>Contact</th>
    <th>Country</th>
  </tr>
  <tr>
    <td>Alfreds Futterkiste</td>
    <td>Maria Anders</td>
    <td>Germany</td>
  </tr>
  <tr>
    <td>Centro comercial Moctezuma</td>
    <td>Francisco Chang</td>
    <td>Mexico</td>
  </tr>
</table>''';
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
    marDownPdf = Document();
  });

  test('convertion_test', () async {
    List<Widget> widgets = await HTMLToPdf().convert(htmlText);
    pdf.addPage(MultiPage(
        maxPages: 200,
        build: (context) {
          return widgets;
        }));
  });

  test('heading_custom_style_applied', () async {
    const html = '<h1>Hello</h1><h2>World</h2>';
    final tagStyle = HtmlTagStyle(
      h1Style: const TextStyle(color: PdfColors.red),
      h2Style: const TextStyle(color: PdfColors.green),
    );
    final widgets = await HTMLToPdf().convert(html, tagStyle: tagStyle);
    expect(widgets.whereType<SizedBox>().length, greaterThanOrEqualTo(2));
  });

  test('heading_default_style_fallback', () async {
    const html = '<h3>Text</h3>';
    final widgets = await HTMLToPdf().convert(html);
    expect(widgets.isNotEmpty, true);
  });

  test('h1 color from HtmlTagStyle is applied to root TextSpan', () async {
    const html = '<h1>Title</h1>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h1Style: TextStyle(color: PdfColors.red)),
    );
    final sizedBox = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sizedBox.child as Padding;
    final rich = padded.child as RichText;
    final span = rich.text as TextSpan;
    expect(span.style?.color, equals(PdfColors.red));
  });

  test('h1 default font-size is applied (32)', () async {
    const html = '<h1>Size</h1>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(32));
  });

  test('h1 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h1>Size</h1>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h1Style: TextStyle(fontSize: 40)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(40));
  });

  test('h2 default font-size is applied (28)', () async {
    const html = '<h2>Size</h2>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(28));
  });

  test('h2 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h2>Size</h2>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h2Style: TextStyle(fontSize: 36)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(36));
  });

  test('h3 default font-size is applied (20)', () async {
    const html = '<h3>Size</h3>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(20));
  });

  test('h3 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h3>Size</h3>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h3Style: TextStyle(fontSize: 30)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(30));
  });

  test('h4 default font-size is applied (17)', () async {
    const html = '<h4>Size</h4>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(17));
  });

  test('h4 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h4>Size</h4>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h4Style: TextStyle(fontSize: 26)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(26));
  });

  test('h5 default font-size is applied (14)', () async {
    const html = '<h5>Size</h5>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(14));
  });

  test('h5 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h5>Size</h5>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h5Style: TextStyle(fontSize: 22)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(22));
  });

  test('h6 default font-size is applied (10)', () async {
    const html = '<h6>Size</h6>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(10));
  });

  test('h6 font-size from HtmlTagStyle overrides default', () async {
    const html = '<h6>Size</h6>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h6Style: TextStyle(fontSize: 18)),
    );
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    final span = (padded.child as RichText).text as TextSpan;
    expect(span.style?.fontSize, equals(18));
  });

  test('inline span color overrides heading color for that span', () async {
    const html = '<h1><span style="color:#00FF00">X</span>Y</h1>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(h1Style: TextStyle(color: PdfColors.red)),
    );
    final sizedBox = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sizedBox.child as Padding;
    final rich = padded.child as RichText;
    final span = rich.text as TextSpan;
    // Root heading color remains red
    expect(span.style?.color, equals(PdfColors.red));
    // First child created from <span> should carry green color
    final children = span.children!;
    final firstChild = children.first as TextSpan;
    expect(firstChild.style?.color,
        equals(ColorExtension.hexToPdfColor('#00FF00')));
  });

  test('inline span font-size is applied from CSS', () async {
    const html = '<p><span style="font-size:18px">Big</span> Small</p>';
    final widgets = await HTMLToPdf().convert(html);
    final wrap = widgets.firstWhere((w) => w is Wrap) as Wrap;
    final sized = wrap.children.first as SizedBox;
    final rich = sized.child as RichText;
    final root = rich.text as TextSpan;
    final first = root.children!.first as TextSpan;
    expect(first.style?.fontSize, equals(18));
  });

  test('paragraph margin-bottom applies as padding below paragraph', () async {
    const html = '<p style="margin-bottom:12px">Hello</p>';
    final widgets = await HTMLToPdf().convert(html);
    // Paragraph with margin-bottom returns top-level Padding wrapping Wrap
    final padded = widgets.firstWhere((w) => w is Padding) as Padding;
    expect((padded.padding as EdgeInsets).bottom, equals(12));
  });

  test('h2 padding-bottom applies below heading', () async {
    const html = '<h2 style="padding-bottom:8px">Head</h2>';
    final widgets = await HTMLToPdf().convert(html);
    final sized = widgets.firstWhere((w) => w is SizedBox) as SizedBox;
    final padded = sized.child as Padding;
    expect((padded.padding as EdgeInsets).bottom, equals(8));
  });

  test('ul margin-bottom applies padding below unordered list', () async {
    const html = '<ul style="margin-bottom:10px"><li>A</li><li>B</li></ul>';
    final widgets = await HTMLToPdf().convert(html);
    final padded = widgets.firstWhere((w) => w is Padding) as Padding;
    expect((padded.padding as EdgeInsets).bottom, equals(10));
  });

  test('ol padding-bottom applies padding below ordered list', () async {
    const html = '<ol style="padding-bottom:6px"><li>A</li><li>B</li></ol>';
    final widgets = await HTMLToPdf().convert(html);
    final padded = widgets.firstWhere((w) => w is Padding) as Padding;
    expect((padded.padding as EdgeInsets).bottom, equals(6));
  });

  test('global headingStyle is used when specific h styles are null', () async {
    const html = '<h1>A</h1><h3>B</h3>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle:
          const HtmlTagStyle(headingStyle: TextStyle(color: PdfColors.orange)),
    );
    final sized1 = widgets[0] as SizedBox;
    final span1 =
        ((sized1.child as Padding).child as RichText).text as TextSpan;
    expect(span1.style?.color, equals(PdfColors.orange));

    final sized2 = widgets[1] as SizedBox;
    final span2 =
        ((sized2.child as Padding).child as RichText).text as TextSpan;
    expect(span2.style?.color, equals(PdfColors.orange));
  });

  test('paragraphStyle is merged for paragraph text', () async {
    const html = '<p>Hello</p>';
    final widgets = await HTMLToPdf().convert(
      html,
      tagStyle: const HtmlTagStyle(
          paragraphStyle: TextStyle(color: PdfColors.purple)),
    );
    final wrap = widgets.firstWhere((w) => w is Wrap) as Wrap;
    final sized = wrap.children.first as SizedBox;
    final span = (sized.child as RichText).text as TextSpan;
    expect(span.children!.first is TextSpan, true);
    final first = span.children!.first as TextSpan;
    expect(first.style?.color, equals(PdfColors.purple));
  });

  const String markDown = """
# Basic Markdown Demo
---
The Basic Markdown Demo shows the effect of the four Markdown extension sets
on formatting basic and extended Markdown tags.

## Overview

The Dart [markdown](https://pub.dev/packages/markdown) package parses Markdown
into HTML. The flutter_markdown package builds on this package using the
abstract syntax tree generated by the parser to make a tree of widgets instead
of HTML elements.

The markdown package supports the basic block and inline Markdown syntax
specified in the original Markdown implementation as well as a few Markdown
extensions. The markdown package uses extension sets to make extension
management easy. There are four pre-defined extension sets; none, Common Mark,
GitHub Flavored, and GitHub Web. The default extension set used by the
flutter_markdown package is GitHub Flavored.

The Basic Markdown Demo shows the effect each of the pre-defined extension sets
has on a test Markdown document with basic and extended Markdown tags. Use the
Extension Set dropdown menu to select an extension set and view the Markdown
widget's output.

## Comments

Since GitHub Flavored is the default extension set, it is the initial setting
for the formatted Markdown view in the demo.
""";

  test('markdown_convertion_test', () async {
    List<Widget> widgets = await HTMLToPdf().convertMarkdown(markDown);
    marDownPdf.addPage(MultiPage(
        maxPages: 200,
        build: (context) {
          return widgets;
        }));
  });

  tearDownAll(() async {
    final file = File('example.pdf');
    await file.writeAsBytes(await pdf.save());
    final markDownfile = File('markdown_example.pdf');
    await markDownfile.writeAsBytes(await marDownPdf.save());
  });
}
