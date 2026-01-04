import 'package:flutter/material.dart';

import '../utils/docx_units.dart';

/// A widget that renders content in a page-like container with margins and shadow.
///
/// This provides a "Word-like" viewing experience by wrapping content in a
/// container that resembles a printed page.
class DocumentPage extends StatelessWidget {
  /// The content to display inside the page.
  final Widget child;

  /// Page width in twips (default: A4 = 12240 twips = 8.5 inches).
  final int pageWidthTwips;

  /// Page height in twips (default: A4 = 15840 twips = 11 inches).
  /// If null, height is determined by content.
  final int? pageHeightTwips;

  /// Top margin in twips.
  final int marginTopTwips;

  /// Bottom margin in twips.
  final int marginBottomTwips;

  /// Left margin in twips.
  final int marginLeftTwips;

  /// Right margin in twips.
  final int marginRightTwips;

  /// Background color of the page.
  final Color pageColor;

  /// Shadow elevation for page effect.
  final double elevation;

  const DocumentPage({
    super.key,
    required this.child,
    this.pageWidthTwips = 12240, // A4 width
    this.pageHeightTwips,
    this.marginTopTwips = 1440, // 1 inch
    this.marginBottomTwips = 1440,
    this.marginLeftTwips = 1440,
    this.marginRightTwips = 1440,
    this.pageColor = Colors.white,
    this.elevation = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final pageWidth = DocxUnits.twipsToPixels(pageWidthTwips);
    final marginTop = DocxUnits.twipsToPixels(marginTopTwips);
    final marginBottom = DocxUnits.twipsToPixels(marginBottomTwips);
    final marginLeft = DocxUnits.twipsToPixels(marginLeftTwips);
    final marginRight = DocxUnits.twipsToPixels(marginRightTwips);

    return Container(
      width: pageWidth,
      constraints: pageHeightTwips != null
          ? BoxConstraints(
              minHeight: DocxUnits.twipsToPixels(pageHeightTwips!),
            )
          : null,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: pageColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation / 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: marginTop,
          bottom: marginBottom,
          left: marginLeft,
          right: marginRight,
        ),
        child: child,
      ),
    );
  }

  /// Creates a DocumentPage from DOCX section properties in twips.
  factory DocumentPage.fromSection({
    required Widget child,
    int? pageWidth,
    int? pageHeight,
    int? marginTop,
    int? marginBottom,
    int? marginLeft,
    int? marginRight,
    Color pageColor = Colors.white,
  }) {
    return DocumentPage(
      pageWidthTwips: pageWidth ?? 12240,
      pageHeightTwips: pageHeight,
      marginTopTwips: marginTop ?? 1440,
      marginBottomTwips: marginBottom ?? 1440,
      marginLeftTwips: marginLeft ?? 1440,
      marginRightTwips: marginRight ?? 1440,
      pageColor: pageColor,
      child: child,
    );
  }
}
