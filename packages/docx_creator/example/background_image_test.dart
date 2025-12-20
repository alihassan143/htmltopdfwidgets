// Example demonstrating background image support in docx_creator
//
// This example shows how to add images as page backgrounds with various
// fill modes and opacity settings, including loading from URLs.

import 'package:docx_creator/docx_creator.dart';

void main() async {
  print('Creating documents with background images from URLs...\n');

  // ============================================================
  // Example 1: Background from URL (Stretched)
  // Uses picsum.photos for a random high-quality image
  // ============================================================
  print('1. Loading background from URL...');
  try {
    final bgFromUrl = await DocxBackgroundImage.fromUrl(
      'https://picsum.photos/1920/1080', // Random HD image
      fillMode: DocxBackgroundFillMode.stretch,
    );

    final doc1 = docx()
        .section(backgroundImage: bgFromUrl)
        .h1('Background from URL')
        .p('This document has a background image loaded directly from a URL.')
        .p('')
        .bullet([
      'Image loaded from picsum.photos',
      'Automatically stretched to fill the page',
      'Extension auto-detected from Content-Type',
    ]).build();

    await DocxExporter().exportToFile(doc1, 'bg_from_url.docx');
    print('   ✅ Created: bg_from_url.docx\n');
  } catch (e) {
    print('   ⚠️  Could not load URL image: $e\n');
  }

  // ============================================================
  // Example 2: Watermark from URL
  // ============================================================
  print('2. Creating watermark from URL...');
  try {
    final watermark = await DocxBackgroundImage.watermarkFromUrl(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/Google-flutter-logo.png/240px-Google-flutter-logo.png',
      opacity: 0.1, // Very subtle
    );

    final doc2 = docx()
        .section(backgroundImage: watermark)
        .h1('Document with Watermark')
        .p('This document has a subtle Flutter logo watermark.')
        .p('The watermark is centered with 10% opacity to not obscure content.')
        .p('')
        .h2('Benefits of Watermarks')
        .bullet([
      'Protect document ownership',
      'Add professional branding',
      'Mark documents as DRAFT or CONFIDENTIAL',
    ]).build();

    await DocxExporter().exportToFile(doc2, 'watermark_from_url.docx');
    print('   ✅ Created: watermark_from_url.docx\n');
  } catch (e) {
    print('   ⚠️  Could not load watermark: $e\n');
  }

  // ============================================================
  // Example 3: Pattern/Tiled Background
  // ============================================================
  print('3. Creating tiled pattern background...');
  try {
    final pattern = await DocxBackgroundImage.fromUrl(
      'https://www.toptal.com/designers/subtlepatterns/uploads/symphony.png',
      fillMode: DocxBackgroundFillMode.tile,
      opacity: 0.3,
    );

    final doc3 = docx()
        .section(backgroundImage: pattern)
        .h1('Tiled Pattern Background')
        .p('This document uses a repeating pattern for a textured effect.')
        .build();

    await DocxExporter().exportToFile(doc3, 'tiled_pattern.docx');
    print('   ✅ Created: tiled_pattern.docx\n');
  } catch (e) {
    print('   ⚠️  Could not load pattern: $e\n');
  }

  // ============================================================
  // Example 4: Background with text content
  // ============================================================
  print('4. Creating nature background...');
  try {
    final natureBg = await DocxBackgroundImage.fromUrl(
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&q=80',
      fillMode: DocxBackgroundFillMode.stretch,
      opacity: 0.4, // Semi-transparent for readability
    );

    final doc4 = docx()
        .section(backgroundImage: natureBg)
        .h1('Mountain Landscape')
        .p('A beautiful document with a nature background.')
        .p('')
        .quote('The mountains are calling and I must go.')
        .p('')
        .table([
      ['Feature', 'Value'],
      ['Resolution', '1920x1080'],
      ['Opacity', '40%'],
      ['Fill Mode', 'Stretch'],
    ]).build();

    await DocxExporter().exportToFile(doc4, 'nature_background.docx');
    print('   ✅ Created: nature_background.docx\n');
  } catch (e) {
    print('   ⚠️  Could not load nature image: $e\n');
  }

  // ============================================================
  // Summary
  // ============================================================
  print('════════════════════════════════════════════════');
  print('Background Image Support Summary');
  print('════════════════════════════════════════════════');
  print('');
  print('Factory Methods:');
  print('  • DocxBackgroundImage.fromUrl() - Load from URL');
  print('  • DocxBackgroundImage.watermark() - Centered, low opacity');
  print('  • DocxBackgroundImage.watermarkFromUrl() - Watermark from URL');
  print('  • DocxBackgroundImage.tiled() - Repeating pattern');
  print('');
  print('Fill Modes:');
  print('  • stretch - Fills entire page (may distort)');
  print('  • tile    - Repeats image as pattern');
  print('  • center  - Centers at original size');
  print('  • fit     - Scales to fit, maintains ratio');
  print('');
  print('Supported Formats: PNG, JPEG, GIF, BMP, TIFF');
  print('Opacity Range: 0.0 (transparent) to 1.0 (opaque)');
}
