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
  <div style="font-family: Arial, sans-serif; line-height: 1.6;">
    <div style="background-color: #2c3e50; color: #ffffff; padding: 40px; text-align: center; border-bottom: 5px solid #e74c3c;">
        <h1 style="font-size: 36px; margin: 0;">Stress Test: Long Styled Content</h1>
        <p style="font-size: 18px; color: #ecf0f1;">Testing pagination and style persistence across page breaks</p>
    </div>

    <div style="padding: 20px;">
        <h2 style="color: #2980b9; border-left: 10px solid #2980b9; padding-left: 15px;">1. The Multi-Page Paragraph Test</h2>
        
        <p style="background-color: #fdf2e9; color: #7e5109; padding: 15px; border: 1px solid #e67e22; font-size: 14px;">
            <b style="color: #d35400; font-size: 18px;">START OF LONG BLOCK:</b> 
            This paragraph is intentionally long to force the PDF engine to break it across at least two or three pages. 
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. <span style="color: #c0392b; font-weight: bold;">[Style Change Mid-Sentence]</span> 
            Donec vel egestas leo, eu fringilla diam. Mauris ac elit eu sem elementum pharetra. Nam interdum, arcu et hendrerit 
            aliquet, ante quam egestas magna, vitae sodales eros lectus porta libero. 
            <br/><br/>
            Continuing the same paragraph block: Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 
            Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. 
            <span style="background-color: #27ae60; color: white; padding: 2px;">This highlight should ideally persist or break cleanly.</span> 
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. 
            Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
            <br/><br/>
            (Repeating to ensure length) Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor 
            incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco 
            laboris nisi ut aliquip ex ea commodo consequat. <i style="font-size: 20px;">Notice the font size increase here.</i> 
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. 
            Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, 
            est eros bibendum elit, nec luctus magna felis sollicitudin mauris. Integer in mauris eu nibh euismod gravida. 
            Duis ac tellus et risus vulputate vehicula. Donec lobortis risus a elit. Etiam tempor. Ut ullamcorper, 
            ligula eu tempor congue, eros est euismod turpis, id tincidunt sapien risus a quam. Maecenas fermentum 
            consequat mi. Donec fermentum. Pellentesque malesuada nulla a mi. Duis sapien sem, aliquet nec, commodo eget, 
            consequat quis, neque. Aliquam faucibus, elit ut dictum aliquet, felis nisl adipiscing sapien, sed malesuada 
            diam lacus eget erat. Cras mollis scelerisque nunc. Donec vehicula cursus purus. Mauris nulla magna, faucibus 
            interdum, condimentum vel, auctor vitae, magna.
            <br/><br/>
            (Page Break should happen somewhere here)
            <br/><br/>
            <span style="text-decoration: underline; color: #8e44ad;">Continuing the same HTML tag across a potential page break:</span> 
            Aenean placerat. In vulputate urna eu arcu. Aliquam erat volutpat. Suspendisse potenti. Sed vel lacus. 
            Mauris nibh felis, adipiscing varius, adipiscing in, lacinia vel, tellus. Suspendisse ac urna. 
            Etiam pellentesque mauris ut lectus. Nunc tellus ante, mattis eget, gravida vitae, ultricies ac, leo. 
            Integer leo pede, ornare a, lacinia eu, vulputate vel, nisl. Suspendisse mauris. Fusce accumsan mollis eros. 
            Pellentesque a diam sit amet mi ullamcorper vehicula. Integer adipiscing risus a sem. Nullam quis massa sit 
            amet nibh viverra malesuada. Nunc sem lacus, accumsan quis, faucibus non, congue vel, arcu. 
            Ut scelerisque hendrerit tellus. Integer sagittis. Vivamus a mauris eget arcu gravida tristique. 
            Nunc iaculis mi in ante.
        </p>
    </div>

    <div style="background-color: #ecf0f1; padding: 20px;">
        <h2 style="color: #2c3e50;">2. Mixed Styled Items</h2>
        <ul style="list-style-type: square; color: #2980b9;">
            <li style="margin-bottom: 10px;"><b>Item One:</b> With a custom margin bottom.</li>
            <li style="margin-bottom: 10px; color: #e74c3c;"><b>Item Two:</b> Red colored text to check inheritance.</li>
            <li style="margin-bottom: 10px; background-color: #f1c40f; padding: 5px;"><b>Item Three:</b> Highlighted background item.</li>
            <li style="margin-bottom: 10px;"><b>Item Four:</b> 
                <blockquote style="border-left: 5px solid #bdc3c7; padding-left: 10px; font-style: italic;">
                    "A nested blockquote inside a list item to test complex layout nesting."
                </blockquote>
            </li>
        </ul>
    </div>

    <div style="margin-top: 30px; border: 2px dashed #3498db; padding: 15px;">
        <h3 style="text-align: right; color: #34495e;">3. Final Complex Paragraph</h3>
        <p style="text-align: justify; font-size: 12px; color: #34495e;">
            This final section uses <b>text-align: justify</b> and a smaller font size. If the fix for 
            the "exceeded pdf page height" error is working, this container should start on the current 
            page and overflow gracefully to the next without cutting off the dashed border or losing the padding context.
            <br/><br/>
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum eget felis et metus iaculis 
            porttitor. Sed vel convallis mauris. Quisque sed dictum nisi. Nam hendrerit, sem ut 
            pellentesque pretium, magna felis imperdiet purus, id scelerisque magna neque vitae nibh. 
            Pellentesque sed nisl vitae lectus dictum elementum.
        </p>
    </div>
</div>
  ''';
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
