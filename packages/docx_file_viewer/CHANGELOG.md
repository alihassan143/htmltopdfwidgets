# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-01-07

### 🎉 Stable Release

This release marks the stable 1.0.0 version with a complete architecture overhaul and significant feature improvements.

### ✨ New Features

- **Paged View Mode** - Documents can now be rendered in distinct page blocks (print layout style) in addition to continuous scrolling
- **Content-Aware Pagination** - Smart page breaks based on content height estimation
- **Embedded Font Loading** - Full support for OOXML font embedding with deobfuscation
- **Theme Color Resolution** - Proper handling of theme colors with tint/shade modifiers
- **Drop Cap Support** - Rich drop cap rendering with proper text wrapping
- **Floating Image Layout** - Left/right floating images with text wrap
- **Headers & Footers** - First page, odd/even page header/footer support
- **Footnotes & Endnotes** - Interactive footnote/endnote references with tap-to-view dialog
- **Table Conditional Formatting** - Support for first row, last row, first column, last column, and banded styles
- **Checkbox Support** - Interactive checkbox rendering in documents
- **Shape Rendering** - Basic shape support (rectangles, text boxes)

### 🔧 Improvements

- **Search Navigation** - Auto-scroll to search matches with dynamic alignment
- **Style Resolution** - Full style inheritance from named styles, paragraph, and run properties
- **Color Resolution** - Theme color, tint, and shade calculation
- **Border Rendering** - Complete border support for paragraphs and tables
- **Performance** - Optimized widget generation for large documents

### 🏗️ Architecture

- Migrated to modular builder pattern (`ParagraphBuilder`, `TableBuilder`, `ListBuilder`, etc.)
- Introduced `DocxWidgetGenerator` as the central rendering engine
- Added `DocxViewTheme` for comprehensive theming support
- Added `DocxSearchController` for programmatic search control
- Added `BlockIndexCounter` for search indexing

---

## [0.0.8]

### Fixed

- Bullet alignment improved
- Heading styles corrected

---

## [0.0.7]

### Added

- Text alignment from styles now parsed
- Background color and borders now parsed for paragraph and text elements

---

## [0.0.6]

### Fixed

- Styles were too much larger than expected
- If color is defined, don't apply default color

---

## [0.0.5]

### Added

- Styles now parsed from file for paragraph and character
- Text alignment now parsed from file

---

## [0.0.4]

### Fixed

- Ordered and unordered lists now render correctly

---

## [0.0.3]

### Fixed

- Resolved an issue where the divider was not being added correctly in the widget

### Breaking Changes

- Removed a static function to facilitate easier addition of new features in the future

---

## [0.0.2]

### Fixed

- Tag-based text not rendered issue resolved

---

## [0.0.1]

### Added

- Initial release