import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:htmltopdf_syncfusion/htmltopdf_syncfusion.dart' as lib;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML to PDF Syncfusion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HTML to PDF Syncfusion Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  String _htmlContent = '''
<h1 style="color: #4a148c; text-align: center;">Welcome to HTML to PDF!</h1>
<p style="font-size: 14px;">
  This is a demonstration of the <b>htmltopdfwidgets_syncfusion</b> package.
</p>

<blockquote style="margin: 10px 0; padding: 10px 20px; border-left: 5px solid #ccc; background-color: #f9f9f9;">
  This is a blockquote with a side border. It should have a gray bar on the left.
  "The only way to do great work is to love what you do." - Steve Jobs
</blockquote>

<h3>Unordered List:</h3>
<ul>
  <li>First item with bullet</li>
  <li>Second item with bullet</li>
  <li>Third item with bullet</li>
</ul>

<h3>Ordered List:</h3>
<ol>
  <li>First item with number</li>
  <li>Second item with number</li>
  <li>Third item with number</li>
</ol>

<div style="background-color: #e0f2f1; padding: 15px; border: 1px solid #00695c;">
  <h2>Features:</h2>
  <ul>
    <li>Headings (H1-H6)</li>
    <li>Paragraphs with custom styling</li>
  </ul>
</div>
<br/>
<h2>Multi-Language Support:</h2>
<p><b>English:</b> Hello World</p>
<p><b>Arabic:</b> مرحبا بالعالم</p>
<p><b>Chinese:</b> 你好世界</p>
<p><b>Emoji:</b> 😀 🎉 🚀 ❤️</p>
<br/>
<p>Enjoy generating PDFs!</p>
''';

  bool _isLoading = false;
  Uint8List? _pdfBytes;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _textController.text = _htmlContent;
    _generatePdf();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onContentChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value != _htmlContent) {
        setState(() {
          _htmlContent = value;
        });
        _generatePdf();
      }
    });
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await lib.HtmlToPdf().convert(_htmlContent);

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          // Left Side: Editor
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HTML Editor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      onChanged: _onContentChanged,
                      style:
                          const TextStyle(fontFamily: 'Courier', fontSize: 14),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter HTML here...',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical Divider
          const VerticalDivider(width: 1, color: Colors.grey),
          // Right Side: Preview
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  if (_pdfBytes != null)
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      key: ValueKey(_pdfBytes.hashCode),
                    )
                  else
                    const Center(child: Text('Generate PDF to view preview')),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
