import 'dart:typed_data';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PdfView shows error on invalid bytes',
      (WidgetTester tester) async {
    // Attempt to load empty bytes which should trigger an error in PdfReader
    await tester.pumpWidget(
      MaterialApp(
        home: PdfView.bytes(Uint8List(0)),
      ),
    );

    // Initial load should show progress
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for load to fail
    await tester.pumpAndSettle();

    // Should show error UI
    expect(find.text('Failed to load PDF'), findsOneWidget);
  });

  testWidgets('PdfViewWithSearch builds structure correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfViewWithSearch(
            bytes: Uint8List.fromList(
                [1, 2, 3]), // Invalid but we just check build
          ),
        ),
      ),
    );

    await tester.pump(); // Start building

    // Should find the PdfView inside
    expect(find.byType(PdfView), findsOneWidget);

    // Search button should be visible default
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
