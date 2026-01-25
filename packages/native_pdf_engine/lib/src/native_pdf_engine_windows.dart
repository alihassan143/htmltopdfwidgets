import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_pdf_engine_c_bindings.dart';

class NativePdfWindows {
  static native_pdf_engine_c_bindings? _bindings;

  static void _init() {
    if (_bindings != null) return;
    try {
      // On Windows, plugins are built as DLLs. process() usually only sees the exe symbols.
      // We must load the DLL explicitly.
      final library = DynamicLibrary.open('native_pdf_engine_windows.dll');
      _bindings = native_pdf_engine_c_bindings(library);

      // Force symbol lookup to ensure the library is valid and symbols are exported
      _bindings!.NativePdf_CreateEngine;
    } catch (e) {
      // If the DLL is missing dependencies (like WebView2Loader.dll), open() throws.
      // Rethrow with clear message.
      throw Exception('Failed to load native_pdf_engine_windows.dll: $e');
    }
  }

  static Future<Uint8List?> convert(
    String content, {
    String? outputPath,
    required bool isUrl,
  }) async {
    _init();

    final engine = _bindings!.NativePdf_CreateEngine();
    if (engine == nullptr) {
      throw Exception('Failed to create PDF engine');
    }

    final completer = Completer<Uint8List?>();

    // Callback
    late NativeCallable<PdfCompletionCallbackFunction> callback;
    callback = NativeCallable<PdfCompletionCallbackFunction>.listener((
      bool success,
      Pointer<Char> errorMsg,
      Pointer<Uint8> data,
      int length,
      Pointer<Void> userData,
    ) {
      if (success) {
        if (data != nullptr && length > 0) {
          final bytes = data.asTypedList(length);
          // Copy the bytes because the pointer is valid only during callback
          completer.complete(Uint8List.fromList(bytes));
        } else {
          completer.complete(null);
        }
      } else {
        final msg = errorMsg.cast<Utf8>().toDartString();
        completer.completeError(Exception(msg));
      }
      callback.close(); // Clean up the listener port
    });

    final cContent = content.toNativeUtf8();
    final cOutputPath = (outputPath ?? "").toNativeUtf8();

    try {
      _bindings!.NativePdf_Generate(
        engine,
        cContent.cast(),
        isUrl,
        cOutputPath.cast(),
        callback.nativeFunction,
        nullptr,
      );

      return await completer.future;
    } finally {
      calloc.free(cContent);
      calloc.free(cOutputPath);
      _bindings!.NativePdf_DestroyEngine(engine);
    }
  }
}
