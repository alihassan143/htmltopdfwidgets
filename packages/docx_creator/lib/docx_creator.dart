/// docx_creator - A developer-first DOCX generation library
///
/// Create professional Word documents with a fluent API:
/// ```dart
/// import 'package:docx_creator/docx_creator.dart';
///
/// final doc = docx()
///   .h1('Title')
///   .p('Content')
///   .build();
///
/// await DocxExporter().exportToFile(doc, 'output.docx');
/// ```
library;

export 'src/ast/docx_background_image.dart';
export 'src/ast/docx_block.dart';
export 'src/ast/docx_drawing.dart';
export 'src/ast/docx_drop_cap.dart';
export 'src/ast/docx_footnote.dart';
export 'src/ast/docx_image.dart';
export 'src/ast/docx_inline.dart';
export 'src/ast/docx_list.dart';
// AST
export 'src/ast/docx_node.dart';
export 'src/ast/docx_section.dart';
export 'src/ast/docx_section_break.dart';
export 'src/ast/docx_table.dart';
// Builder
export 'src/builder/docx_document_builder.dart';
export 'src/core/defaults.dart';
// Core
export 'src/core/enums.dart';
export 'src/core/exceptions.dart';
export 'src/core/measurements.dart';
export 'src/core/xml_extension.dart';
// Exporters
export 'src/exporters/docx_exporter.dart';
export 'src/exporters/html_exporter.dart';
export 'src/exporters/pdf/pdf_exporter.dart';
// Parsers
export 'src/parsers/html_parser.dart';
export 'src/parsers/markdown_parser.dart';
export 'src/reader/docx_reader.dart';
export 'src/reader/models/docx_style.dart';
// Reader Models
export 'src/reader/models/docx_theme.dart';
// Utilities
export 'src/utils/content_types_generator.dart';
export 'src/utils/docx_id_generator.dart';
export 'src/utils/docx_validator.dart';
export 'src/utils/xml_utils.dart' hide DocxIdGenerator;
