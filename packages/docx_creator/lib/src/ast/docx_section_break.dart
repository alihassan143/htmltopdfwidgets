import 'package:xml/xml.dart';

import 'docx_node.dart';
import 'docx_section.dart';

/// Represents a section break in the document.
///
/// Inserting a [DocxSectionBreakBlock] defines the properties (page size, margins, etc.)
/// of the *preceding* section of the document.
///
/// ```dart
/// builder.addParagraph('Page 1 (Portrait)');
/// builder.addSectionBreak(DocxSectionDef(
///   orientation: DocxPageOrientation.portrait,
/// ));
/// builder.addParagraph('Page 2 (Landscape)');
/// // The final section properties are defined by the document's main section definition.
/// ```
class DocxSectionBreakBlock extends DocxBlock {
  final DocxSectionDef section;

  const DocxSectionBreakBlock(this.section, {super.id});

  @override
  void accept(DocxVisitor visitor) {
    // We treat this as a section visitation
    visitor.visitSection(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        // DocxSectionDef.buildXml generates <w:sectPr>...</w:sectPr>
        section.buildXml(builder);
      });
    });
  }
}
