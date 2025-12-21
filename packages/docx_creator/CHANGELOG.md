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
