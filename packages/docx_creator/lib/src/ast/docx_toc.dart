import 'package:xml/xml.dart';

import 'docx_node.dart';

/// Represents a Table of Contents (TOC) in the document.
///
/// A TOC in Word is typically an SDT (Structured Document Tag) containing
/// a Field Code (TOC) and cached result paragraphs.
class DocxTableOfContents extends DocxBlock {
  /// The TOC field instruction.
  ///
  /// Default: `TOC \o "1-3" \h \z \u`
  /// - \o "1-3": Include levels 1-3
  /// - \h: Hyperlinks
  /// - \z: Hide tab leader in web layout
  /// - \u: Use outline levels
  final String instruction;

  /// Whether to mark the TOC as dirty (update on open).
  ///
  /// If true, Word will prompt (or auto-update) to calculate page numbers.
  final bool updateOnOpen;

  /// Cached content (paragraphs) to display before update.
  ///
  /// If empty, Word might show nothing until updated.
  final List<DocxBlock> cachedContent;

  const DocxTableOfContents({
    this.instruction = 'TOC \\o "1-3" \\h \\z \\u',
    this.updateOnOpen = true,
    this.cachedContent = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTableOfContents(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    // Write SDT block for TOC
    builder.element('w:sdt', nest: () {
      // SDT Properties
      builder.element('w:sdtPr', nest: () {
        builder.element('w:docPartObj', nest: () {
          builder.element('w:docPartGallery', nest: () {
            builder.attribute('w:val', 'Table of Contents');
          });
          builder.element('w:docPartUnique');
        });
      });

      // SDT Content
      builder.element('w:sdtContent', nest: () {
        // 1. Begin Field
        builder.element('w:p', nest: () {
          builder.element('w:pPr', nest: () {
            builder.element('w:pStyle', nest: () {
              builder.attribute('w:val', 'TOCHeading');
            });
          });
          // Often includes a title "Table of Contents" in a separate paragraph or run,
          // but the FIELD itself starts with fldChar begin.
          // Let's stick to the generated field structure.

          builder.element('w:r', nest: () {
            builder.element('w:fldChar', nest: () {
              builder.attribute('w:fldCharType', 'begin');
              if (updateOnOpen) {
                builder.attribute('w:dirty', 'true');
              }
            });
          });

          builder.element('w:r', nest: () {
            builder.element('w:instrText', nest: () {
              builder.attribute('xml:space', 'preserve');
              builder.text(' $instruction ');
            });
          });

          builder.element('w:r', nest: () {
            builder.element('w:fldChar', nest: () {
              builder.attribute('w:fldCharType', 'separate');
            });
          });
        });

        // 2. Cached Content
        for (var block in cachedContent) {
          block.buildXml(builder);
        }

        // 3. End Field (usually in a paragraph, or end of previous paragraph)
        // Ideally should be in its own run at end of content, but sdtContent usually closes it.
        // Word expects the end char.
        builder.element('w:p', nest: () {
          builder.element('w:r', nest: () {
            builder.element('w:fldChar', nest: () {
              builder.attribute('w:fldCharType', 'end');
            });
          });
        });
      });
    });
  }
}
