#include "include/native_pdf_engine.h"

#include <fstream>
#include <gtk/gtk.h>
#include <string>
#include <unistd.h>
#include <vector>
#include <webkit2/webkit2.h>

class PdfEngine {
public:
  PdfEngine() {
    // We typically rely on the host application to have initialized GTK.
    // But if running purely headless (e.g. dart test), we need to ensure init.
    if (!gtk_init_check(nullptr, nullptr)) {
      // Error
    }
  }

  ~PdfEngine() {
    // Cleanup if needed
    // Widgets are destroyed by GTK usually, but if we own the webview:
    if (webview_) {
      // g_object_unref(webview_);
    }
  }

  void Generate(const char *content, bool is_url, const char *output_path,
                PdfCompletionCallback callback, void *user_data) {
    callback_ = callback;
    user_data_ = user_data;

    if (output_path && strlen(output_path) > 0) {
      output_path_ = output_path;
      is_temp_file_ = false;
    } else {
      // Create temp file
      char temp[] = "/tmp/pdf_XXXXXX";
      int fd = mkstemp(temp);
      if (fd != -1) {
        close(fd);
        output_path_ = temp;
        is_temp_file_ = true;
      } else {
        // Handle error
        Complete(false, "Failed to create temp file", nullptr, 0);
        return;
      }
    }

    // Create WebView (Offscreen)
    // Note: In WebKitGTK, we might need a window to render correctly?
    // Usually creation of WebView is enough for loading.
    webview_ = WEBKIT_WEB_VIEW(webkit_web_view_new());

    // Ensure settings allow printing background?
    WebKitSettings *settings = webkit_web_view_get_settings(webview_);
    webkit_settings_set_print_backgrounds(settings, TRUE);

    // Connect Signal: load-changed
    g_signal_connect(webview_, "load-changed", G_CALLBACK(OnLoadChanged), this);

    if (is_url) {
      webkit_web_view_load_uri(webview_, content);
    } else {
      webkit_web_view_load_html(webview_, content, nullptr);
    }
  }

private:
  static void OnLoadChanged(WebKitWebView *web_view, WebKitLoadEvent load_event,
                            gpointer user_data) {
    PdfEngine *engine = static_cast<PdfEngine *>(user_data);
    if (load_event == WEBKIT_LOAD_FINISHED) {
      // Print
      engine->Print();
    }
  }

  void Print() {
    WebKitPrintOperation *print_op = webkit_print_operation_new(webview_);

    WebKitPrintOperationResponse response =
        WEBKIT_PRINT_OPERATION_RESPONSE_PRINT;
    GtkPrintSettings *print_settings = gtk_print_settings_new();

    // Set output to file
    gtk_print_settings_set(print_settings, GTK_PRINT_SETTINGS_OUTPUT_URI,
                           (std::string("file://") + output_path_).c_str());

    // Export action
    gtk_print_settings_set(print_settings, GTK_PRINT_SETTINGS_PRINTER,
                           "Print to File");
    // Or action export?
    // webkit_print_operation_print will show dialog unless we configure it
    // heavily? WebKitPrintOperation doesn't expose strict "no_dialog" easily
    // without print mode. However, if we set the printer to "Print to File" and
    // output uri, it usually works. For now, trigger the standard print.

    // Better: use webkit_print_operation_run_dialog separately?
    // No, use webkit_print_operation_print which is asynchronous.

    webkit_print_operation_set_print_settings(print_op, print_settings);

    g_signal_connect(print_op, "finished", G_CALLBACK(OnPrintFinished), this);
    g_signal_connect(print_op, "failed", G_CALLBACK(OnPrintFailed), this);

    // Run export
    webkit_print_operation_print(print_op);

    g_object_unref(print_settings);
    g_object_unref(print_op);
  }

  static void OnPrintFinished(WebKitPrintOperation *print_operation,
                              gpointer user_data) {
    PdfEngine *engine = static_cast<PdfEngine *>(user_data);

    if (engine->is_temp_file_) {
      // Read back file
      std::ifstream file(engine->output_path_,
                         std::ios::binary | std::ios::ate);
      if (file.is_open()) {
        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        std::vector<uint8_t> buffer(size);
        if (file.read((char *)buffer.data(), size)) {
          engine->Complete(true, nullptr, buffer.data(), (int32_t)size);
        } else {
          engine->Complete(false, "Failed to read temp PDF file", nullptr, 0);
        }
        file.close();
        unlink(engine->output_path_.c_str());
      } else {
        engine->Complete(false, "Failed to open back temp PDF file", nullptr,
                         0);
      }
    } else {
      engine->Complete(true, nullptr, nullptr, 0);
    }
  }

  static void OnPrintFailed(WebKitPrintOperation *print_operation,
                            GError *error, gpointer user_data) {
    PdfEngine *engine = static_cast<PdfEngine *>(user_data);
    engine->Complete(false, error ? error->message : "Unknown error", nullptr,
                     0);
  }

  void Complete(bool success, const char *error, const uint8_t *data,
                int32_t length) {
    if (callback_) {
      callback_(success, error, data, length, user_data_);
      callback_ = nullptr;
    }
  }

  WebKitWebView *webview_ = nullptr;
  PdfCompletionCallback callback_ = nullptr;
  void *user_data_ = nullptr;
  std::string output_path_;
  bool is_temp_file_ = false;
};

// C API

// We must repeat EXPORT to ensure visibility, and extern "C" to prevent
// mangling if the header wasn't perfectly consistent or if we want to be
// explicit.
#ifdef __cplusplus
extern "C" {
#endif

EXPORT void *NativePdf_CreateEngine() { return new PdfEngine(); }

EXPORT void NativePdf_DestroyEngine(void *engine) {
  if (engine)
    delete static_cast<PdfEngine *>(engine);
}

EXPORT void NativePdf_Generate(void *engine, const char *content, bool is_url,
                               const char *output_path,
                               PdfCompletionCallback callback,
                               void *user_data) {
  if (engine) {
    static_cast<PdfEngine *>(engine)->Generate(content, is_url, output_path,
                                               callback, user_data);
  }
}

#ifdef __cplusplus
}
#endif
