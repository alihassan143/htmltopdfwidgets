import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_pdf_engine/native_pdf_engine.dart';
import 'package:native_pdf_engine_example/viewer.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _pdfPath;
  String _statusMessage = 'Keep calm and generate PDF';
  bool _isGenerating = false;

  final TextEditingController _htmlController = TextEditingController(
    text: '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: sans-serif; padding: 20px; }
    h1 { color: #333; }
    p { color: #666; }
    .box { 
      background-color: #f0f0f0; 
      padding: 15px; 
      border-radius: 8px; 
      margin-top: 20px;
    }
  </style>
</head>
<body>
  <h1>Native PDF Engine</h1>
  <p>This PDF was generated from HTML using native platform webviews.</p>
  <div class="box">
    <p><strong>Platform:</strong> Native Render</p>
    <p>Success! The engine is working correctly.</p>
  </div>
</body>
</html>
''',
  );
  final TextEditingController _urlController = TextEditingController(
    text: 'https://flutter.dev',
  );

  int _selectedTabIndex = 0;

  @override
  void dispose() {
    _htmlController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating PDF...';
      _pdfPath = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/example.pdf';

      if (_selectedTabIndex == 0) {
        // HTML Mode
        await NativePdf.convert(_htmlController.text, targetPath);
      } else {
        // URL Mode
        await NativePdf.convertUrl(_urlController.text, targetPath);
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'PDF Generated Successfully at:\n$targetPath';
          _pdfPath = targetPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error generating PDF:\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Native PDF Engine Example')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Tab Selector
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('HTML'),
                              icon: Icon(Icons.code),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('URL'),
                              icon: Icon(Icons.link),
                            ),
                          ],
                          selected: {_selectedTabIndex},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(() {
                              _selectedTabIndex = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input Area
                  SizedBox(
                    height: 150,
                    child: _selectedTabIndex == 0
                        ? TextField(
                            controller: _htmlController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'HTML Content',
                              alignLabelWithHint: true,
                            ),
                            textAlignVertical: TextAlignVertical.top,
                          )
                        : TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'URL (e.g., https://example.com)',
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  if (_isGenerating)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _generatePdf,
                      child: const Text('Generate PDF'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _pdfPath != null
                  ? MainPage(file: File(_pdfPath!))
                  : Center(
                      child: Text(
                        'No PDF generated yet',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
