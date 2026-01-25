import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_pdf_engine_c_bindings.dart';

class NativePdfLinux {
  static native_pdf_engine_c_bindings? _bindings;

  static void _init() {
    if (_bindings != null) return;
    try {
      try {
        // First try process symbols (static linking)
        final library = DynamicLibrary.process();
        _bindings = native_pdf_engine_c_bindings(library);
        // Force symbol lookup to verify content
        _bindings!.NativePdf_CreateEngine;
      } catch (_) {
        // Fallback to shared library
        final library = DynamicLibrary.open('libnative_pdf_engine_linux.so');
        _bindings = native_pdf_engine_c_bindings(library);
        // Force symbol lookup to verify content
        _bindings!.NativePdf_CreateEngine;
      }
    } catch (e) {
      _bindings = null; // Reset if failed
      throw Exception('Failed to load native_pdf_engine_linux: $e');
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
          // Copy bytes
          completer.complete(Uint8List.fromList(bytes));
        } else {
          completer.complete(null);
        }
      } else {
        final msg = errorMsg.cast<Utf8>().toDartString();
        completer.completeError(Exception(msg));
      }
      callback.close(); // Clean up
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
