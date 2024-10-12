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
import 'package:test/test.dart';

late Document pdf;

void main() {
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
//   const htmlText = '''
//   <h1>Heading Example</h1>
//   <p>This is a paragraph.</p>
//   <img src="image.jpg" alt="Example Image" />
//   <blockquote>This is a quote.</blockquote>
//
//   <h4>Test unordered nested list</h4>
//   <ul>
//     <li>First item</li>
//     <li>Second item</li>
//     <li>Third item</li>
//     <li>
//     <ul>
//     <li>1st subitem</li>
//     <li>2nd subitem</li>
//     <li>3rd subitem, and here goes some text to see if the subitems are all aligned properly to the left.</li>
//     </ul>
//     </li>
//     <li>Fourth item</li>
//   </ul>
//
//   <h4>Test ordered nested list</h4>
//   <ol>
//     <li>First item<br>With a newline</li>
//     <li>Second item<br><i>With an italics newline</i></li>
//     <li>Third item<br><b>With a bold newline</b></li>
//     <li>
//     <ol>
//       <li>First subitem<br>With a newline</li>
//       <li>Second subitem<br><i>With an italics newline</i></li>
//       <li>Third subitem<br><b>With a bold newline</b></li>
//     </ol>
//     </li>
//   </ol>
//   <br>
//
//   <h4>Test single formattings</h4>
//   <p><b>Hello there bold</b></p>
//   <p><i>Hello there italic</i></p>
//   <p><u>Hello there underline</u></p>
//
//   <h4>Test multiple formattings is one paragraph with newline</h4>
//   <p>Regular text<br>Regular text (after a newline)</p>
//   <p><b>Bold text<br>Bold text (after a newline)</b></p>
//   <p><b><i>Bold and italic text<br>Bold and italic text (after a newline)</i></b></p>
//   <p><b><i><u>Bold, italic and underline text<br>Bold, italic and underline text (after a newline)</u></i></b></p>
//   <p><b><i>Bold and italic text<br><u>Bold, italic and underline text (after a newline)</u></i></b></p>
//   <p><i><u>Italic and underline text<b><br>Bold, italic and underline text (after a newline)</b></u></i></p>
//
//   <h4>Test text alignment</h4>
//
//   <p style="text-align:justify;">This is a very long, but lovely and tremendously pleasant and easy to read line in a paragraph that is justified.</p>
//   <p style="text-align:left;">This is a line in a paragraph that is aligned left.</p>
//   <p style="text-align:right;">This is a line in a paragraph that is aligned right.</p>
//   <p style="text-align:center;">This is a line in a paragraph that is aligned center.</p>
//
//   <h4>Test tables</h4>
//   <table>
//   <tr>
//     <th>Company</th>
//     <th>Contact</th>
//     <th>Country</th>
//   </tr>
//   <tr>
//     <td>Alfreds Futterkiste</td>
//     <td>Maria Anders</td>
//     <td>Germany</td>
//   </tr>
//   <tr>
//     <td>Centro comercial Moctezuma</td>
//     <td>Francisco Chang</td>
//     <td>Mexico</td>
//   </tr>
// </table>''';
  setUpAll(() {
    // Document.debug = true;
    // RichText.debug = true;
    pdf = Document();
  });

  test('convertion_test', () async {

    List<Widget> widgets = await HTMLToPdf().convert(htmlText);
    pdf.addPage(MultiPage(
        maxPages: 200,
        build: (context) {
          return widgets;
        }));
  });

  tearDownAll(() async {
    final file = File('example.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
