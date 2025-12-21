// Example demonstrating background image support in docx_creator
//
// This example shows how to add images as page backgrounds with various
// fill modes and opacity settings, including loading from URLs.

import 'package:docx_creator/docx_creator.dart';

void main() async {
  // ============================================================
  // Example 1: Background from URL (Stretched)
  // Uses picsum.photos for a random high-quality image
  // ============================================================
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
  } catch (e) {
    ;
  }

  // ============================================================
  // Example 2: Watermark from URL
  // ============================================================
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
  } catch (e) {}

  // ============================================================
  // Example 3: Pattern/Tiled Background
  // ============================================================
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
  } catch (e) {}

  // ============================================================
  // Example 4: Background with text content
  // ============================================================
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
  } catch (e) {}
}
