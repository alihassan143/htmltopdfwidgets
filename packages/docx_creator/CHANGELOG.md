## 1.0.7

### Fixed
- **Table Row Heights**: Fixed missing `w:trHeight` parsing and export. Calendar tables and other tables with explicit row heights now preserve their dimensions.
- **Table Overlap**: Added parsing and export for `w:tblOverlap` attribute on floating tables.
- **Embedded Font Variants**: Fixed font reading to parse all font embed types (`w:embedRegular`, `w:embedBold`, `w:embedItalic`, `w:embedBoldItalic`) instead of only Regular. This fixes missing font files during round-trip.
- **Table Border Export**: Tables with a `styleId` (e.g., "Calendar3", "LightList-Accent3") no longer emit explicit `<w:tblBorders>` that was incorrectly overriding the named style definition.
- **Text Style Inheritance**: Fixed inline parser to only emit **direct** run properties (color, font size, fonts), not inherited ones from styles. This allows table cell text to properly inherit styling from table styles via `cnfStyle` conditional formatting.

---

## 1.0.6

### Fixed
- **Table Style Fidelity**: Fixed critical issue where table cell borders defined in Named Table Styles (via `w:tblStylePr`) were ignored.
  - Updated `DocxStyle` parser to correctly extract `w:tcBorders` from table style conditionals.
  - Fixed logic to properly prioritize table style borders when paragraph borders are absent.

## 1.0.5

### Fixed
- **Font Fidelity**: Fixed critical issue where embedded fonts were lost during the read-export cycle due to mismatched relationship IDs and filenames.
  - Preserved exact filenames and relationship IDs from the original document.
  - Updated `fontTable.xml.rels` handling to ensure valid links to embedded font files.
- **Line Spacing Fidelity**: Fixed issue where specific line spacing rules (e.g., 'Exactly' vs 'At Least') were ignored.
  - Added support for parsing and exporting `w:lineRule` attribute in paragraphs and styles.
  - Ensures visual vertical spacing matches the original document precisely.
- **Style Inheritance**: Fixed issue where paragraph styles (like 'Heading 1') were lost on export.
  - Added parsing for `w:pStyle` property in `DocxStyle` and `DocxParagraph`.
- **Inline Font Merging**: Fixed logic where direct font formatting (e.g., hints) completely overwrote character style fonts.
  - Implemented proper merging of direct font properties with underlying character style fonts.
- **Theme Support**: Added parsing for theme-related font attributes (`w:asciiTheme`, `w:eastAsiaTheme`, etc.) to preserve theme-based font selection.

## 1.0.4

### Added
- **Table Style Resolver**: Added full support for Named Table Styles (`w:tblStylePr`) and Conditional Formatting (`w:tblLook`).
  - Supports 'First Row', 'Last Row', 'First Column', 'Last Column', and 'Banded Rows/Columns' formatting.
  - Automatically resolves and "bakes" effective styles (shading, borders, fonts) into table cells for visual fidelity.
- **Floating Images**: Added parser support for floating images with precise positioning.
  - Supports `wp:anchor` parsing.
  - Handles `relativeFrom` (margin, page, column) and alignment attributes.
- **Drop Caps**: Added support for Drop Caps (`w:dropCap`) in paragraphs.
- **Footnotes & Endnotes**: Added comprehensive support for parsing and exporting Footnotes and Endnotes.
- **Text Borders**: Added support for parsing text borders (`w:bdr`).

### Fixed
- **Table Styles**: Fixed issue where table styles were not correctly applied to cells during parsing.
- **Attribute Export**: Fixed invalid hex color format (removed `#` prefix) in `w:fill` attribute generation to ensure compatibility with Microsoft Word.
- **Cell Copying**: Fixed `DocxTableCell.copyWith` bug that caused style properties to be lost when modifying table cells.

---

## 1.0.3

### Improved
- **Modular DocxReader Architecture**: Refactored 1797-line monolithic `docx_reader.dart` into 11 focused modules:
  - `reader_context.dart` - Shared state manager
  - `parsers/style_parser.dart` - Style resolution
  - `parsers/block_parser.dart` - Paragraph/list parsing
  - `parsers/inline_parser.dart` - Text/image/shape parsing
  - `parsers/table_parser.dart` - Table/rowspan handling
  - `parsers/section_parser.dart` - Headers/footers/sections
  - `handlers/relationship_manager.dart` - OOXML relationships
  - `handlers/font_reader.dart` - Embedded font extraction
- **Modular HTML Parser Architecture**: Refactored 1259-line `html_parser.dart` into 8 modules:
  - `html/parser_context.dart` - CSS class map & shared state
  - `html/style_context.dart` - Style inheritance context
  - `html/color_utils.dart` - 141 CSS named colors
  - `html/block_parser.dart` - Block elements
  - `html/inline_parser.dart` - Inline elements
  - `html/table_parser.dart` - Tables with nested support
  - `html/list_parser.dart` - Ordered/unordered lists
  - `html/image_parser.dart` - Image elements

### Fixed
- **UTF-8 Encoding**: Fixed XML content parsing to use proper UTF-8 decoding in DocxReader
- **Shape Parsing**: Restored full shape dimension/color/preset parsing in refactored reader
- **Nested Table Support**: HTML parser now correctly handles tables inside table cells
- **Background Inheritance**: Fixed `resetBackground()` to properly clear nullable `shadingFill` values

---

## 1.0.2

### Added
- **DrawingML Shapes**: Full support for 70+ preset shapes (rectangles, ellipses, stars, arrows, flowchart symbols, etc.)
  - Block-level shapes (`DocxShapeBlock`) and inline shapes (`DocxShape`)
  - Fill colors, outline colors, and outline widths
  - Text content inside shapes
  - Rotation support
  - Floating and inline positioning
- **Shape Reader Support**: Shapes are now preserved when reading existing DOCX files
- **141 CSS Named Colors**: Full W3C CSS3 Extended Color Keywords support in HTML parser
  - All grey/gray spelling variations supported
  - Includes colors like `dodgerblue`, `mediumvioletred`, `papayawhip`, etc.
- **Comprehensive Examples**: Added four complete example files:
  - `manual_builder_example.dart` - All builder API features
  - `html_parser_example.dart` - All HTML/CSS features
  - `markdown_parser_example.dart` - All Markdown features
  - `reader_editor_example.dart` - Full read-edit-write workflow

### Improved
- **Documentation**: Complete rewrite of README.md and new DOCUMENTATION.md with:
  - Full API reference tables
  - All supported HTML tags and CSS properties
  - Step-by-step DOCX Reader/Editor guide
  - OpenXML internals explanation
  - Troubleshooting section
- **Color Handling**: Improved color class with automatic hex normalization (strips `#` and `0x` prefixes)
- **List Rendering**: Enhanced 9-level nested list support with proper abstract numbering

### Fixed
- **Background Color Inheritance**: Fixed CSS `background-color` incorrectly inheriting to inline children
- **Code Block Visibility**: Fixed text visibility in code blocks when used with background colors

---

## 1.0.1

### Fixed
- **List Rendering**: Fixed numbered and bullet lists not displaying markers in Word when multiple lists appear in the same document.
- **Color Parsing**: Fixed `HtmlParser` color parsing for font colors and background highlights. Now supports:
  - Hex codes (3-digit and 6-digit)
  - RGB/RGBA formats
  - Extended CSS named colors (including `grey`, `lime`, `maroon`, etc.)
- **Highlight Mapping**: Fixed incorrect default highlight color (no longer defaults to yellow for unknown colors).

### Improved
- **OOXML Compliance**: Updated `numbering.xml` generation to match python-docx patterns for better Word compatibility (`w:nsid`, `w:tmpl`, `w:tabs`).

---

## 1.0.0

- Initial version.
