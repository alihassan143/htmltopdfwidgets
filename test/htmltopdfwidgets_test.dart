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
  const htmlText = '''  <h1>Heading Example</h1>
  <p>This is a paragraph.</p>
  <img src="image.jpg" alt="Example Image" />
  <blockquote>This is a quote.</blockquote>
  <ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
    <li>
    <ul>
    <li>1st subitem</li>
    <li>2nd subitem</li>
    <li>3rd subitem</li>
    </ul>
    </li>
  </ul>
  
  <ol>
    <li>First item<br>With a newline</li>
    <li>Second item<br><i>With an italics newline</i></li>
    <li>Third item<br><b>With a bold newline</b></li>
  </ol>
  
  <br>
  <br>
  <p><b>Hello there bold</b></p>
  <br>
  <p><b>Hello there bold<br>With a newline</b></p>
  <br>
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
