/// Native PDF Engine - HTML to PDF conversion using native OS webviews
///
/// Supports iOS and macOS platforms only.
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart' as jni;
import 'package:objective_c/objective_c.dart' as objc;

import 'src/android/java/lang/Runnable.dart' as javalang;
import 'src/android_bindings.dart' as android;
import 'src/native_pdf_engine_ios_bindings.dart' as ios;
import 'src/native_pdf_engine_macos_bindings.dart' as macos;

/// High-level PDF generation API for iOS and macOS.
///
/// This class provides static methods to convert HTML content or URLs to PDF files
/// using native WebKit components for optimal performance and memory efficiency.
class NativePdf {
  NativePdf._(); // Prevent instantiation

  static Completer<dynamic>? _pendingCompleter;

  // Keep strong references to prevent garbage collection
  static Object? _activeWebView;
  static Object? _activeDelegate;
  static String? _activeOutputPath;

  /// Convert HTML string to PDF file.
  ///
  /// [html] - The HTML content to convert.
  /// [outputPath] - The file path where the PDF will be saved.
  ///
  /// Returns a [Future] that completes when the PDF has been generated.
  /// Throws [Exception] on failure.
  static Future<void> convert(String html, String outputPath) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<void>();
    _activeOutputPath = outputPath;

    try {
      if (Platform.isIOS) {
        _convertIOS(html, outputPath: outputPath, isUrl: false);
      } else if (Platform.isMacOS) {
        _convertMacOS(html, outputPath: outputPath, isUrl: false);
      } else if (Platform.isAndroid) {
        _convertAndroid(html, outputPath: outputPath, isUrl: false);
      } else {
        throw UnsupportedError(
          'Platform not supported. Only iOS and macOS are supported.',
        );
      }
      await _pendingCompleter!.future;
    } finally {
      _cleanup();
    }
  }

  /// Convert URL to PDF file.
  ///
  /// [url] - The URL to capture (e.g., https://example.com).
  /// [outputPath] - The file path where the PDF will be saved.
  ///
  /// Returns a [Future] that completes when the PDF has been generated.
  /// Throws [Exception] on failure.
  static Future<void> convertUrl(String url, String outputPath) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<void>();
    _activeOutputPath = outputPath;

    try {
      if (Platform.isIOS) {
        _convertIOS(url, outputPath: outputPath, isUrl: true);
      } else if (Platform.isMacOS) {
        _convertMacOS(url, outputPath: outputPath, isUrl: true);
      } else if (Platform.isAndroid) {
        _convertAndroid(url, outputPath: outputPath, isUrl: true);
      } else {
        throw UnsupportedError(
          'Platform not supported. Only iOS and macOS are supported.',
        );
      }
      await _pendingCompleter!.future;
    } finally {
      _cleanup();
    }
  }

  /// Convert HTML string to PDF data.
  ///
  /// [html] - The HTML content to convert.
  ///
  /// Returns a [Future] that completes with the PDF data as [Uint8List].
  /// Throws [Exception] on failure.
  static Future<Uint8List> convertToData(String html) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<Uint8List>();
    _activeOutputPath = null;

    try {
      if (Platform.isIOS) {
        _convertIOS(html, isUrl: false);
      } else if (Platform.isMacOS) {
        _convertMacOS(html, isUrl: false);
      } else if (Platform.isAndroid) {
        _convertAndroid(html, isUrl: false);
      } else {
        throw UnsupportedError(
          'Platform not supported. Only iOS and macOS are supported.',
        );
      }
      return await _pendingCompleter!.future as Uint8List;
    } finally {
      _cleanup();
    }
  }

  /// Convert URL to PDF data.
  ///
  /// [url] - The URL to capture (e.g., https://example.com).
  ///
  /// Returns a [Future] that completes with the PDF data as [Uint8List].
  /// Throws [Exception] on failure.
  static Future<Uint8List> convertUrlToData(String url) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<Uint8List>();
    _activeOutputPath = null;

    try {
      if (Platform.isIOS) {
        _convertIOS(url, isUrl: true);
      } else if (Platform.isMacOS) {
        _convertMacOS(url, isUrl: true);
      } else if (Platform.isAndroid) {
        _convertAndroid(url, isUrl: true);
      } else {
        throw UnsupportedError(
          'Platform not supported. Only iOS and macOS are supported.',
        );
      }
      return await _pendingCompleter!.future as Uint8List;
    } finally {
      _cleanup();
    }
  }

  static void _cleanup() {
    _pendingCompleter = null;
    _activeWebView = null;
    _activeDelegate = null;
    _activeOutputPath = null;
  }

  static void _completeWithSuccess([dynamic result]) {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(result);
    }
  }

  static void _completeWithError(Object error) {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(error);
    }
  }
}

// iOS Implementation
void _convertIOS(String content, {String? outputPath, required bool isUrl}) {
  // Create WKWebViewConfiguration
  final config = ios.WKWebViewConfiguration.alloc().init();

  // Create frame for the web view (1024x768 for PDF generation)
  final framePtr = calloc<objc.CGRect>();
  framePtr.ref.origin.x = 0;
  framePtr.ref.origin.y = 0;
  framePtr.ref.size.width = 1024;
  framePtr.ref.size.height = 768;

  // Create WKWebView
  final webView = ios.WKWebView.alloc().initWithFrame$1(
    framePtr.ref,
    configuration: config,
  );

  calloc.free(framePtr);

  // Create navigation delegate to handle page load completion
  final delegate = ios.WKNavigationDelegate$Builder.implementAsListener(
    webView_didFinishNavigation_: (wv, navigation) {
      _handleIOSNavigationFinished(wv, outputPath);
    },
    webView_didFailNavigation_withError_: (wv, navigation, error) {
      NativePdf._completeWithError(
        Exception(
          'Navigation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
    },
    webView_didFailProvisionalNavigation_withError_: (wv, navigation, error) {
      NativePdf._completeWithError(
        Exception(
          'Provisional navigation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
    },
  );

  // Keep strong references to prevent GC
  NativePdf._activeWebView = webView;
  NativePdf._activeDelegate = delegate;

  webView.navigationDelegate = delegate;

  // Load content
  if (isUrl) {
    final nsUrl = objc.NSURL.URLWithString(objc.NSString(content));
    if (nsUrl == null) {
      NativePdf._completeWithError(Exception('Invalid URL: $content'));
      return;
    }
    final request = ios.NSURLRequest.requestWithURL(nsUrl);
    webView.loadRequest(request);
  } else {
    webView.loadHTMLString(objc.NSString(content), baseURL: null);
  }
}

void _handleIOSNavigationFinished(ios.WKWebView webView, String? outputPath) {
  // Create PDF configuration
  final pdfConfig = ios.WKPDFConfiguration.alloc().init();

  // Create completion handler block
  final completionHandler = ios.ObjCBlock_ffiVoid_NSData_NSError.listener((
    objc.NSData? data,
    objc.NSError? error,
  ) {
    if (error != null) {
      NativePdf._completeWithError(
        Exception(
          'PDF generation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
      return;
    }

    if (data != null) {
      try {
        final ptr = data.bytes.cast<ffi.Uint8>();
        final len = data.length;
        final bytes = ptr.asTypedList(len);
        if (outputPath != null) {
          File(outputPath).writeAsBytesSync(bytes);
          NativePdf._completeWithSuccess();
        } else {
          NativePdf._completeWithSuccess(bytes);
        }
      } catch (e) {
        NativePdf._completeWithError(Exception('Failed to generate PDF: $e'));
      }
    } else {
      NativePdf._completeWithError(Exception('PDF data is null'));
    }
  });

  webView.createPDFWithConfiguration(
    pdfConfig,
    completionHandler: completionHandler,
  );
}

// macOS Implementation
void _convertMacOS(String content, {String? outputPath, required bool isUrl}) {
  // Create WKWebViewConfiguration
  final config = macos.WKWebViewConfiguration.alloc().init();

  // Create frame for the web view (1024x768 for PDF generation)
  final framePtr = calloc<objc.CGRect>();
  framePtr.ref.origin.x = 0;
  framePtr.ref.origin.y = 0;
  framePtr.ref.size.width = 1024;
  framePtr.ref.size.height = 768;

  // Create WKWebView
  final webView = macos.WKWebView.alloc().initWithFrame$1(
    framePtr.ref,
    configuration: config,
  );

  calloc.free(framePtr);

  // Create navigation delegate to handle page load completion
  final delegate = macos.WKNavigationDelegate$Builder.implementAsListener(
    webView_didFinishNavigation_: (wv, navigation) {
      _handleMacOSNavigationFinished(wv, outputPath);
    },
    webView_didFailNavigation_withError_: (wv, navigation, error) {
      NativePdf._completeWithError(
        Exception(
          'Navigation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
    },
    webView_didFailProvisionalNavigation_withError_: (wv, navigation, error) {
      NativePdf._completeWithError(
        Exception(
          'Provisional navigation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
    },
  );

  // Keep strong references to prevent GC
  NativePdf._activeWebView = webView;
  NativePdf._activeDelegate = delegate;

  webView.navigationDelegate = delegate;

  // Load content
  if (isUrl) {
    final nsUrl = objc.NSURL.URLWithString(objc.NSString(content));
    if (nsUrl == null) {
      NativePdf._completeWithError(Exception('Invalid URL: $content'));
      return;
    }
    final request = macos.NSURLRequest.requestWithURL(nsUrl);
    webView.loadRequest(request);
  } else {
    webView.loadHTMLString(objc.NSString(content), baseURL: null);
  }
}

void _handleMacOSNavigationFinished(
  macos.WKWebView webView,
  String? outputPath,
) {
  // Create PDF configuration
  final pdfConfig = macos.WKPDFConfiguration.alloc().init();

  // Create completion handler block
  final completionHandler = macos.ObjCBlock_ffiVoid_NSData_NSError.listener((
    objc.NSData? data,
    objc.NSError? error,
  ) {
    if (error != null) {
      NativePdf._completeWithError(
        Exception(
          'PDF generation failed: ${error.localizedDescription.toDartString()}',
        ),
      );
      return;
    }

    if (data != null) {
      try {
        final ptr = data.bytes.cast<ffi.Uint8>();
        final len = data.length;
        final bytes = ptr.asTypedList(len);
        if (outputPath != null) {
          File(outputPath).writeAsBytesSync(bytes);
          NativePdf._completeWithSuccess();
        } else {
          NativePdf._completeWithSuccess(bytes);
        }
      } catch (e) {
        NativePdf._completeWithError(Exception('Failed to generate PDF: $e'));
      }
    } else {
      NativePdf._completeWithError(Exception('PDF data is null'));
    }
  });

  webView.createPDFWithConfiguration(
    pdfConfig,
    completionHandler: completionHandler,
  );
}

// Android Implementation
void _convertAndroid(
  String content, {
  String? outputPath,
  required bool isUrl,
}) async {
  final activity = jni.Jni.androidActivity(
    PlatformDispatcher.instance.engineId!,
  );
  if (activity == null) {
    NativePdf._completeWithError(
      Exception('Android Activity is null. Engine not attached?'),
    );
    return;
  }

  // Cast to strongly typed Activity
  final androidActivity = android.Activity.fromReference(activity.reference);

  // Use a Completer to bridge the async gap from the UI thread callback
  final completer = Completer<Uint8List?>();

  // Implement Runnable
  final runnable = javalang.Runnable.implement(
    javalang.$Runnable(
      run: () async {
        try {
          // 1. Create WebView
          // WebView constructor expects a Context. Activity is a Context, but JNI bindings don't automatically inherit.
          // We explicitly create a Context reference from the Activity reference.
          final androidContext = android.Context.fromReference(
            androidActivity.reference,
          );
          final webView = android.WebView(androidContext);

          NativePdf._activeWebView = webView; // Keep reference

          // 2. Configure Settings
          final settings = webView.getSettings();
          settings?.setJavaScriptEnabled(true);
          settings?.setDomStorageEnabled(true);

          // 3. Set layout manually to fixed size (e.g. A4 or 1024x768)
          final width = 1024;
          final height = 768;

          // Cast WebView to View to access layout() and draw()
          final webViewAsView = android.View.fromReference(webView.reference);

          // Force layout
          webViewAsView.layout(0, 0, width, height);

          // 4. Load Content
          if (isUrl) {
            webView.loadUrl(content.toJString());
          } else {
            webView.loadDataWithBaseURL(
              jni.JString.fromString(""),
              content.toJString(),
              "text/html".toJString(),
              "utf-8".toJString(),
              jni.JString.fromString(""),
            );
          }

          // 5. Poll for completion
          // onPageFinished is robust, but requires subclassing WebViewClient which is hard in JNI.
          // We use getProgress loop as a workaround.
          int attempts = 0;
          while ((webView.getProgress() < 100) && attempts < 100) {
            // 10s timeout
            await Future.delayed(Duration(milliseconds: 100));
            attempts++;
          }

          if (attempts >= 100) {
            debugPrint(
              "Timeout waiting for page load, proceeding with partial render...",
            );
          }

          // Allow a bit more time for rendering after 100%
          await Future.delayed(Duration(milliseconds: 500));

          // 6. Generate PDF
          final pdfDoc = android.PdfDocument();

          // Page Info
          final pageBuilder = android.PdfDocument$PageInfo$Builder(
            width,
            height,
            1,
          );
          final pageInfo = pageBuilder.create();

          // Start Page
          final page = pdfDoc.startPage(pageInfo);
          final canvas = page?.getCanvas();

          if (canvas != null) {
            // Draw WebView to Canvas
            webViewAsView.draw(canvas);
          }

          pdfDoc.finishPage(page);

          if (outputPath != null) {
            // 7. Write to file
            // File.new$1(String) corresponds to File(String pathname)
            final file = android.File.new$1(outputPath.toJString());
            // FileOutputStream(File) corresponds to FileOutputStream(File file)
            final fos = android.FileOutputStream(file);

            pdfDoc.writeTo(fos);
            fos.close();
            completer.complete(null);
          } else {
            // Write to ByteArrayOutputStream
            final bos = android.ByteArrayOutputStream();
            pdfDoc.writeTo(bos);
            final bytes = bos.toByteArray();

            // JArray<jbyte> (which is Int8) to Uint8List conversion
            // we need to copy elements.
            // The JArray can be accessed.
            final int count = bytes!.length;
            final uint8List = Uint8List(count);
            for (var i = 0; i < count; i++) {
              uint8List[i] = bytes[i] & 0xFF; // Handle signed byte
            }

            bos.close();
            completer.complete(uint8List);
          }

          // 8. Close
          pdfDoc.close();
        } catch (e) {
          completer.completeError(e);
        }
      },
    ),
  );

  // Execute on UI Thread
  androidActivity.runOnUiThread(runnable);

  // Wait for completion
  try {
    final result = await completer.future;
    NativePdf._completeWithSuccess(result);
  } catch (e) {
    NativePdf._completeWithError(Exception('PDF generation failed: $e'));
  }
}
