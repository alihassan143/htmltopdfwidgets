import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'native_pdf_engine_c_bindings.dart';

class NativePdfWindows {
  static native_pdf_engine_c_bindings? _bindings;

  static void _init() {
    if (_bindings != null) return;

    // Helper to verify library validity
    bool tryLoad(DynamicLibrary lib) {
      try {
        lib.lookup<NativeFunction<Pointer<Void> Function()>>(
          'NativePdf_CreateEngine',
        );
        _bindings = native_pdf_engine_c_bindings(lib);
        return true;
      } catch (_) {
        return false;
      }
    }

    // 1. Try standard open (PATH)
    try {
      if (tryLoad(DynamicLibrary.open('native_pdf_engine_windows.dll'))) return;
    } catch (_) {}

    // 2. Try absolute path relative to executable
    try {
      final location = path.join(
        path.dirname(Platform.resolvedExecutable),
        'native_pdf_engine_windows.dll',
      );
      if (tryLoad(DynamicLibrary.open(location))) return;
    } catch (_) {}

    throw Exception(
      'Failed to load native_pdf_engine_windows.dll from any location.',
    );
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
