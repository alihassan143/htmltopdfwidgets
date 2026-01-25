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
      // In Flutter Windows, plugins are usually linked.
      // If we built a shared library via CMake, it might be in the executable directory.
      // If it's a plugin, Flutter loads it.
      // We can try looking up symbols in the executable or the specific DLL.
      _bindings = native_pdf_engine_c_bindings(
        DynamicLibrary.open('native_pdf_engine_windows.dll'),
      );
    } catch (e) {
      // Fallback: in some setups (like 'flutter run'), symbols might be in the runner if statically linked?
      // But we defined SHARED library in CMake.
      try {
        _bindings = native_pdf_engine_c_bindings(DynamicLibrary.process());
      } catch (e2) {
        throw Exception(
          'Failed to load native_pdf_engine_windows.dll: $e\n$e2',
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
