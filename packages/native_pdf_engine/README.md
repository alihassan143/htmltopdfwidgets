# native_pdf_engine

A minimal, high-performance Flutter package for generating PDFs from HTML or URLs using native OS webview capabilities.

This package uses `dart:ffi` and `package:jni` to invoke native APIs directly, ensuring:
- **Zero bloat**: No bundled browser engines (uses pre-installed OS webviews).
- **High performance**: Direct native calls, low overhead.
- **Native fidelity**: PDFs look exactly as they would when printing from Safari (iOS/macOS) or Chrome (Android).

## Platforms Supported

| Platform | Tech Stack | Status |
|---|---|---|
| **iOS** | `WKWebView` + `UIPrintPageRenderer` (via FFI/ObjC) | ✅ |
| **macOS** | `WKWebView` + `Cocoa` (via FFI/ObjC) | ✅ |
| **Android** | `android.webkit.WebView` + `PdfDocument` (via JNI/jnigen) | ✅ |
| **Windows** | *Planned* | 🚧 |
| **Linux** | *Planned* | 🚧 |

## Features

- **Convert HTML String to PDF**: Render raw HTML content directly to a PDF file or data.
- **Convert URL to PDF**: Capture a full webpage and save it as a PDF file or data.
- **Background Execution**: Most operations run efficiently without blocking the main UI thread (Android uses `runOnUiThread` for safety).

## Installation

Add `native_pdf_engine` to your `pubspec.yaml`:

```yaml
dependencies:
  native_pdf_engine: ^0.0.1
```

## Setup

### Android

1. **Internet Permission**: If you are converting URLs, ensure your `android/app/src/main/AndroidManifest.xml` includes:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```
2. **Cleartext Traffic**: If you need to support HTTP URLs (not recommended), allow cleartext traffic in your manifest or network security config.

### iOS / macOS

No special setup is usually required. App Sandbox/Hardened Runtime on macOS may require allowing outgoing network connections (`com.apple.security.network.client`) if fetching URLs.

## Usage

```dart
import 'package:native_pdf_engine/native_pdf_engine.dart';

void main() async {
  // 1. Convert HTML String
  try {
     await NativePdf.convert(
       '<h1>Hello World</h1><p>This is a native PDF!</p>',
       'output/path/document.pdf',
     );
     print('PDF Generated!');
  } catch (e) {
     print('Error: $e');
  }

  // 2. Convert URL
  try {
     await NativePdf.convertUrl(
       'https://flutter.dev',
       'output/path/flutter_website.pdf',
     );
     print('URL Captured!');
  } catch (e) {
     print('Error: $e');
  }

  // 3. Get PDF Data directly (HTML)
  try {
     final pdfData = await NativePdf.convertToData('<h1>Direct Data</h1>');
     print('Got PDF Data: ${pdfData.length} bytes');
  } catch (e) {
     print('Error: $e');
  }

  // 4. Get PDF Data directly (URL)
  try {
     final pdfData = await NativePdf.convertUrlToData('https://dart.dev');
     print('Got PDF Data: ${pdfData.length} bytes');
  } catch (e) {
     print('Error: $e');
  }
}
```

## How It Works

This package avoids the complexity of `flutter_inappwebview` or `printing` when you just need a simple, headless PDF generation:

- **Android**: It spins up a headless `WebView`, loads the content, waits for completion (via polling), and draws the view hierarchy onto a `android.graphics.pdf.PdfDocument` Canvas.
- **iOS/macOS**: It creates a headless `WKWebView`, loads the content, and uses the native `createPDF` configuration API available in WebKit.

## License

MIT
