## 0.1.0
*   **Feature**: Added Markdown to PDF conversion support (`HtmlToPdf.convertMarkdown`).
*   **Feature**: Added Checkbox support in lists (`[ ]`, `[x]`).
*   **Fix**: Improved robustness of image loading (checking `Content-Type` to avoid crashes on non-image URLs).
*   **Fix**: Fixed nested list indentation and switched to safer bullet markers.
*   **Fix**: Implemented style inheritance for correct header rendering (font sizes/weights).

## 0.0.6

*   **Fixed**: Resolved OIDC authentication for automated publishing by injecting Dart credentials.

## 0.0.5

*   **Fixed**: Resolved CI/CD issue where changes were not detected during release.

## 0.0.4

*   **Documentation**: Improved README with clear usage examples.
*   **Fix**: Resolved lint errors in tests.

## 0.0.2

*   **Refactor**: Renamed package to `htmltopdf_syncfusion` for consistency.
*   **Chore**: Updated CI workflows to use Flutter and Melos for improved reliability.

## 0.0.1

*   **Initial Release**:
    *   Converts HTML strings to Syncfusion PDF widgets.
    *   Supports Markdown parsing.
    *   **Arabic Support**: Right-to-Left (RTL) text direction and character reshaping.
    *   **Multi-language**: CJK and Emoji font fallback support.
    *   **Styling**: Basic CSS support (fontSize, color, backgroundColor, alignment, borders).
    *   **Lists**: Ordered and unordered list rendering.
    *   **Tables**: HTML table rendering with borders.
    *   **Images**: Support for network and asset images.
