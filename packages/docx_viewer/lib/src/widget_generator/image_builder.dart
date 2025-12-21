import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';

/// Builds Flutter [Image] widgets from [DocxImage] elements.
class ImageBuilder {
  final DocxViewConfig config;

  ImageBuilder({required this.config});

  /// Build a block-level image widget.
  Widget buildBlockImage(DocxImage image) {
    Widget imageWidget = Image.memory(
      image.bytes,
      width: image.width?.toDouble(),
      height: image.height?.toDouble(),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(image),
    );

    // Apply alignment
    Alignment alignment;
    switch (image.align) {
      case DocxAlign.center:
        alignment = Alignment.center;
        break;
      case DocxAlign.right:
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.centerLeft;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: alignment,
      child: imageWidget,
    );
  }

  /// Build an inline image widget.
  Widget buildInlineImage(DocxInlineImage image) {
    return Image.memory(
      image.bytes,
      width: image.width?.toDouble(),
      height: image.height?.toDouble(),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildInlineErrorPlaceholder(image),
    );
  }

  Widget _buildErrorPlaceholder(DocxImage image) {
    return Container(
      width: image.width?.toDouble() ?? 200,
      height: image.height?.toDouble() ?? 150,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorPlaceholder(DocxInlineImage image) {
    return Container(
      width: image.width?.toDouble() ?? 50,
      height: image.height?.toDouble() ?? 50,
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, size: 24, color: Colors.grey.shade400),
    );
  }
}
