import 'dart:io';

import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';

void main() {
  createDocument();
}

const htmlText = '''<h1>AppFlowyEditor</h1>
<h2>👋 <strong>Welcome to</strong> <strong><em><a href="appflowy.io">AppFlowy Editor</a></em></strong></h2>
  <p>AppFlowy Editor is a <strong>highly customizable</strong> <em>rich-text editor</em></p>
<hr />
<p><u>Here</u> is an example <del>your</del> you can give a try</p>
<br>
<span style="font-weight: bold;background-color: #cccccc;font-style: italic;">Span element</span>
<span style="font-weight: medium;text-decoration: underline;">Span element two</span>
</br>
<span style="font-weight: 900;text-decoration: line-through;">Span element three</span>
<a href="https://appflowy.io">This is an anchor tag!</a>
<img src="https://images.squarespace-cdn.com/content/v1/617f6f16b877c06711e87373/c3f23723-37f4-44d7-9c5d-6e2a53064ae7/Asset+10.png?format=1500w" />
<h3>Features!</h3>
<ul>
  <li>[x] Customizable</li>
  <li>[x] Test-covered</li>
  <li>[ ] more to come!</li>
</ul>
<ol>
  <li>First item</li>
  <li>Second item</li>
</ol>
<li>List element</li>
<blockquote>
  <p>This is a quote!</p>
</blockquote>
<code>
  Code block
</code>
<em>Italic one</em> <i>Italic two</i>
<b>Bold tag</b>
<img src="http://appflowy.io" alt="AppFlowy">
<p>You can also use <strong><em>AppFlowy Editor</em></strong> as a component to build your own app.</p>
<h3>Awesome features</h3>

<p>If you have questions or feedback, please submit an issue on Github or join the community along with 1000+ builders!</p>
  <h3>Checked Boxes</h3>
 <input type="checkbox" id="option2" checked> 
  <label for="option2">Option 2</label>
  <input type="checkbox" id="option3"> 
  <label for="option3">Option 3</label>
  ''';
const String markDown = """
| Plugin | README |
| ------ | ------ |
| Dropbox | 1 |
| GitHub | 2 |
| Google Drive | 3 |
| OneDrive | 3 |
| Medium | 4 |
| Google Analytics | 5 |
""";
createDocument() async {
  const filePath = 'html_example.pdf';
  const markDownfilePath = 'markdown_example.pdf';
  final file = File(filePath);
  final markdownfile = File(markDownfilePath);
  final newpdf = Document();
  final markdownNewpdf = Document();
  final List<Widget> widgets =
      await HTMLToPdf().convert(htmlText, wrapInParagraph: true);
  final List<Widget> markdownwidgets = await HTMLToPdf().convertMarkdown(
    markDown,
  );
  newpdf.addPage(MultiPage(
      maxPages: 200,
      build: (context) {
        return widgets;
      }));
  markdownNewpdf.addPage(MultiPage(
      maxPages: 200,
      build: (context) {
        return markdownwidgets;
      }));
  await file.writeAsBytes(await newpdf.save());
  await markdownfile.writeAsBytes(await markdownNewpdf.save());
}
