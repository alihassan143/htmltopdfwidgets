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
  const htmlText = '''
  <h1>Heading Example</h1>
  <p>This is a paragraph.</p>
  <img src="image.jpg" alt="Example Image" />
  <blockquote>This is a quote.</blockquote>
  
  <h4>Test unordered nested list</h4>
  <ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
    <li>
    <ul>
    <li>1st subitem</li>
    <li>2nd subitem</li>
    <li>3rd subitem, and here goes some text to see if the subitems are all aligned properly to the left.</li>
    </ul>
    </li>
    <li>Fourth item</li>
  </ul>
  
  <h4>Test ordered nested list</h4>
  <ol>
    <li>First item<br>With a newline</li>
    <li>Second item<br><i>With an italics newline</i></li>
    <li>Third item<br><b>With a bold newline</b></li>
    <li>
    <ol>
      <li>First subitem<br>With a newline</li>
      <li>Second subitem<br><i>With an italics newline</i></li>
      <li>Third subitem<br><b>With a bold newline</b></li>
    </ol>
    </li>
  </ol>
  <br>
  
  <h4>Test single formattings</h4>
  <p><b>Hello there bold</b></p>
  <p><i>Hello there italic</i></p>
  <p><u>Hello there underline</u></p>
  
  <h4>Test multiple formattings is one paragraph with newline</h4>
  <p>Regular text<br>Regular text (after a newline)</p>
  <p><b>Bold text<br>Bold text (after a newline)</b></p>
  <p><b><i>Bold and italic text<br>Bold and italic text (after a newline)</i></b></p>
  <p><b><i><u>Bold, italic and underline text<br>Bold, italic and underline text (after a newline)</u></i></b></p>
  <p><b><i>Bold and italic text<br><u>Bold, italic and underline text (after a newline)</u></i></b></p>
  <p><i><u>Italic and underline text<b><br>Bold, italic and underline text (after a newline)</b></u></i></p>

  <h4>Test text alignment</h4>
  
  <p style="text-align:justify;">This is a very long, but lovely and tremendously pleasant and easy to read line in a paragraph that is justified.</p>
  <p style="text-align:left;">This is a line in a paragraph that is aligned left.</p>
  <p style="text-align:right;">This is a line in a paragraph that is aligned right.</p>
  <p style="text-align:center;">This is a line in a paragraph that is aligned center.</p>

  <h4>Test tables</h4>
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
    // Document.debug = true;
    // RichText.debug = true;
    pdf = Document();
  });

  test('convertion_test', () async {

    String htmlText = "<p><i><u>Italic and underline text<b><br>Bold, italic and underline text (after a newline)</b></u></i></p>";

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
