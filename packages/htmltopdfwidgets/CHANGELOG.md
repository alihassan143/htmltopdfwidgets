## 2.0.1

* **Fixes**:
    * ([#63](https://github.com/alihassan143/htmltopdfwidgets/pull/63)) feat: add .gitignore and remove ignored files by @alihassan143
    * ([#63](https://github.com/alihassan143/htmltopdfwidgets/pull/63)) fix: fixed issue of pdf generation when text for table cell is very long by @AbhishekDoshi26
    * ([#63](https://github.com/alihassan143/htmltopdfwidgets/pull/63)) fix: fixed pipeline by @AbhishekDoshi26
    * ([#63](https://github.com/alihassan143/htmltopdfwidgets/pull/63)) fix: removed whitespace in paragraph starting by @AbhishekDoshi26
    * ([#63](https://github.com/alihassan143/htmltopdfwidgets/pull/63)) fix: fixed column header background color by @AbhishekDoshi26
    * ([#61](https://github.com/alihassan143/htmltopdfwidgets/pull/61)) feat: Update legacy HTML to widgets and browser PDF builder, generating new test and example PDF outputs by @AbhishekDoshi26.

## 2.0.0
* **New Architecture**: Introduced a "Browser Rendering Engine" architecture for more robust HTML to PDF conversion.
    * **Style Engine**: Comprehensive CSS parsing and cascading support.
    * **Render Tree**: Intermediate DOM representation with fully computed styles.
    * **PDF Builder**: Modular PDF widget generation with better layout handling.
* **Unified API**: Updated `HTMLToPdf.convert` to support the new engine via `useNewEngine: true`.
* **Checkbox Enhancements**:
    * Fixed inline rendering of checkboxes (now flow with text).
    * Improved vertical alignment (centered by default, respects `vertical-align`).
* **Multi-Language Support**:
    * Added `textDirection` support for RTL languages (Arabic, Hebrew).
    * Added `fontFallback` support for Emojis and complex scripts in the new engine.
* **Enhanced Element Support**:
    * Improved Table rendering with full CSS support (borders, padding, background).
    * Better List handling (nested lists, custom bullets).
    * Support for `blockquote`, `pre`, `code`, `hr`, `checkbox`, and more.
* **Rendering Improvements**:
    * Fixed inline content rendering (bold, italic, mixed text).
    * Fixed list item text visibility.
    * Optimized default spacing to match legacy engine.
* **Custom Styles**: Added full support for `HtmlTagStyle` in the new engine.
* **Robustness**: Improved error handling for images and fonts.
* **Legacy Support**: Maintained full backward compatibility with the legacy engine (default).

## 2.0.0-beta.2

* **Checkbox Enhancements**:
    * Fixed inline rendering of checkboxes (now flow with text).
    * Improved vertical alignment (centered by default, respects `vertical-align`).
* **Multi-Language Support**:
    * Added `textDirection` support for RTL languages (Arabic, Hebrew).
    * Added `fontFallback` support for Emojis and complex scripts in the new engine.
* **Robustness**:
    * Improved error handling for images and fonts.

## 2.0.0-beta.1

*   **New Architecture**: Introduced a "Browser Rendering Engine" architecture for more robust HTML to PDF conversion.
    *   **Style Engine**: Comprehensive CSS parsing and cascading support (`lib/src/browser/css_style.dart`).
    *   **Render Tree**: Intermediate DOM representation with fully computed styles (`lib/src/browser/render_node.dart`).
    *   **PDF Builder**: Modular PDF widget generation with better layout handling (`lib/src/browser/pdf_builder.dart`).
*   **Unified API**: Updated `HTMLToPdf.convert` to support the new engine via `useNewEngine: true`.
*   **Enhanced Support**:
    *   Improved Table rendering with full CSS support (borders, padding, background).
    *   Better List handling (nested lists, custom bullets).
    *   Support for `blockquote`, `pre`, `code`, `hr`, `checkbox`, and more.
*   **Rendering Improvements**:
    *   Fixed inline content rendering (bold, italic, mixed text).
    *   Fixed list item text visibility.
    *   Optimized default spacing to match legacy engine.
*   **Custom Styles**: Added full support for `HtmlTagStyle` in the new engine.
*   **Legacy Support**: Maintained full backward compatibility with the legacy engine (default).

## 1.1.3
* *([#52](https://github.com/alihassan143/htmltopdfwidgets/pull/52)) fix css color parsing
## 1.1.1
* Fix markdown table issue and added more markdown properties modifiers
## 1.1.0
*([#46](https://github.com/alihassan143/htmltopdfwidgets/pull/46)) Add support for local image files

## 1.0.9
* added support for horizontal divider
* code block and pre tag support
## 1.0.8
* fix: Links get formatted but are not clickable in the PDF ([#35](https://github.com/alihassan143/htmltopdfwidgets/issues/35))
## 1.0.7
* fix nested child skipping issue fixed
## 1.0.6
* added wrap in paragraph element feature for html text
## 1.0.5
* Markdown to pdf support added
## 1.0.4
* Fix wrong styles of background color ([#31](https://github.com/alihassan143/htmltopdfwidgets/issues/31))
* Add support for custom fonts ([#34](https://github.com/alihassan143/htmltopdfwidgets/pull/34)) by @hig-dev
## 1.0.3
* Intial support for checkboxes
*([#25](https://github.com/alihassan143/htmltopdfwidgets/issues/25))
## 1.0.2
* update readme
*([#20](https://github.com/alihassan143/htmltopdfwidgets/issues/20))
## 1.0.1
* update readme
## 1.0.0
*  fix line break
*  fix Can't manage to render colors    
*  text alignment feature added    


## 0.0.9+2
*  fix internal css decoration not working
## 0.0.9+1

*  optimiz parse logic
*  documentation fixs
*  using override dependency for pdf due to underline and italic issues 
*  update readme 
## 0.0.9

*  optimiz parse logic
*  documentation fixs
*  using override dependency for pdf due to underline and italic issues 

## 0.0.8+2

*  support for html table tag added
## 0.0.8+1

*  update reamdme.md
## 0.0.8

*  support custom styles

## 0.0.7

*  support for dart sdk
*  nested elements children support
## 0.0.6

*  multiple styles on same text
*  font fallback and font added 
## 0.0.5

*  missing image element added
## 0.0.4

*  optimization
## 0.0.3

*  depedency updates
## 0.0.2

*  network image fixes.
## 0.0.1

* Describe initial release.
