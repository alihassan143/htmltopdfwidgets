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
      // Try opening the shared library
      _bindings = native_pdf_engine_c_bindings(
        DynamicLibrary.open('libnative_pdf_engine_linux.so'),
      );
    } catch (e) {
      try {
        // Fallback to process symbols (if statically linked or preloaded)
        _bindings = native_pdf_engine_c_bindings(DynamicLibrary.process());
      } catch (e2) {
        throw Exception(
          'Failed to load libnative_pdf_engine_linux.so: $e\n$e2',
        );
      }
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
