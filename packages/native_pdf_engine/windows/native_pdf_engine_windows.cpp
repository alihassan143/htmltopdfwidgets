#include "include/native_pdf_engine.h"

#include <atomic>
#include <fstream>
#include <map>
#include <string>
#include <vector>
#include <windows.h>
#include <wrl.h>
#include <wrl/client.h>
#include <wrl/event.h>

// Note: Standard WebView2 install vs NuGet. For a pure C++ file we expect
// headers. If headers are missing, compilation will fail.
#include "WebView2.h"

using namespace Microsoft::WRL;

// Helper to convert char* to wstring
std::wstring ToWString(const char *utf8) {
  if (!utf8)
    return L"";
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
  if (len <= 0)
    return L"";
  std::vector<wchar_t> buf(len);
  MultiByteToWideChar(CP_UTF8, 0, utf8, -1, buf.data(), len);
  return std::wstring(buf.data());
}

class PdfEngine {
public:
  PdfEngine() : hwnd_(nullptr) {
    // Create a message-only window or hidden window to handle messages
    HINSTANCE hInstance = GetModuleHandle(nullptr);
    WNDCLASS wc = {0};
    wc.lpfnWndProc = DefWindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"NativePdfEngineWindow";
    RegisterClass(&wc);

    hwnd_ = CreateWindowEx(0, L"NativePdfEngineWindow", L"NativeGeneratedPDF",
                           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                           CW_USEDEFAULT, CW_USEDEFAULT, HWND_MESSAGE, nullptr,
                           hInstance, nullptr);
  }

  ~PdfEngine() {
    // webview_ (ICoreWebView2) doesn't have Close(). Controller cleanup is
    // sufficient.
    if (webview_) {
      webview_ = nullptr;
    }
    if (controller_) {
      controller_->Close();
      controller_ = nullptr;
    }
    if (hwnd_) {
      DestroyWindow(hwnd_);
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
      // Generate temp path
      wchar_t tempPath[MAX_PATH];
      GetTempPathW(MAX_PATH, tempPath);
      wchar_t tempFileName[MAX_PATH];
      GetTempFileNameW(tempPath, L"PDF", 0, tempFileName);

      // Convert wstring back to string for consistency in storage
      int len = WideCharToMultiByte(CP_UTF8, 0, tempFileName, -1, NULL, 0, NULL,
                                    NULL);
      std::vector<char> buf(len);
      WideCharToMultiByte(CP_UTF8, 0, tempFileName, -1, buf.data(), len, NULL,
                          NULL);
      output_path_ = buf.data();
      is_temp_file_ = true;
    }

    // Initialize WebView2
    CreateCoreWebView2EnvironmentWithOptions(
        nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [this, content_str = std::string(content),
             is_url](HRESULT result, ICoreWebView2Environment *env) -> HRESULT {
              if (FAILED(result)) {
                Complete(false, "Failed to create environment", nullptr, 0);
                return result;
              }

              env->CreateCoreWebView2Controller(
                  hwnd_,
                  Callback<
                      ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                      [this, content_str,
                       is_url](HRESULT result,
                               ICoreWebView2Controller *controller) -> HRESULT {
                        if (FAILED(result)) {
                          Complete(false, "Failed to create controller",
                                   nullptr, 0);
                          return result;
                        }

                        controller_ = controller;
                        controller_->get_CoreWebView2(&webview_);

                        // Set size (e.g. A4 approximately or standard screen)
                        RECT bounds = {0, 0, 1024, 768};
                        controller_->put_Bounds(bounds);

                        // Navigate
                        std::wstring wcontent = ToWString(content_str.c_str());
                        if (is_url) {
                          webview_->Navigate(wcontent.c_str());
                        } else {
                          webview_->NavigateToString(wcontent.c_str());
                        }

                        // Listen for NavigationCompleted
                        EventRegistrationToken token;
                        webview_->add_NavigationCompleted(
                            Callback<
                                ICoreWebView2NavigationCompletedEventHandler>(
                                [this](ICoreWebView2 *sender,
                                       ICoreWebView2NavigationCompletedEventArgs
                                           *args) -> HRESULT {
                                  BOOL success;
                                  args->get_IsSuccess(&success);
                                  if (!success) {
                                    Complete(false, "Navigation failed",
                                             nullptr, 0);
                                    return S_OK;
                                  }

                                  // Print to PDF
                                  Print();
                                  return S_OK;
                                })
                                .Get(),
                            &token);

                        return S_OK;
                      })
                      .Get());
              return S_OK;
            })
            .Get());
  }

private:
  void Print() {
    if (!webview_)
      return;

    std::wstring wpath = ToWString(output_path_.c_str());

    // PrintToPdf is available in ICoreWebView2_7 interface.
    // We need to cast our webview_ (ICoreWebView2) to ICoreWebView2_7.
    ComPtr<ICoreWebView2_7> webview7;
    HRESULT hr = webview_.As(&webview7);
    if (FAILED(hr)) {
      Complete(false,
               "Failed to obtain ICoreWebView2_7 interface. WebView2 Runtime "
               "might be too old.",
               nullptr, 0);
      return;
    }

    // PrintToPdf takes 3 arguments: ResultFilePath, PrintSettings, and Handler.
    // We pass nullptr for settings to use default.
    webview7->PrintToPdf(
        wpath.c_str(), nullptr,
        Callback<ICoreWebView2PrintToPdfCompletedHandler>(
            [this, wpath](HRESULT result, BOOL is_successful) -> HRESULT {
              if (FAILED(result) || !is_successful) {
                Complete(false, "PrintToPdf failed", nullptr, 0);
              } else {
                if (is_temp_file_) {
                  // Read file
                  std::ifstream file(output_path_,
                                     std::ios::binary | std::ios::ate);
                  if (file.is_open()) {
                    std::streamsize size = file.tellg();
                    file.seekg(0, std::ios::beg);

                    std::vector<uint8_t> buffer(size);
                    if (file.read((char *)buffer.data(), size)) {
                      Complete(true, nullptr, buffer.data(), (int32_t)size);
                    } else {
                      Complete(false, "Failed to read temp PDF file", nullptr,
                               0);
                    }
                    file.close();
                    DeleteFileW(wpath.c_str());
                  } else {
                    Complete(false, "Failed to open output PDF file", nullptr,
                             0);
                  }
                } else {
                  Complete(true, nullptr, nullptr, 0);
                }
              }
              return S_OK;
            })
            .Get());
  }

  void Complete(bool success, const char *error, const uint8_t *data,
                int32_t length) {
    if (callback_) {
      callback_(success, error, data, length, user_data_);
      callback_ = nullptr; // Run once
    }
  }

  HWND hwnd_;
  ComPtr<ICoreWebView2Controller> controller_;
  ComPtr<ICoreWebView2> webview_;

  PdfCompletionCallback callback_;
  void *user_data_;
  std::string output_path_;
  bool is_temp_file_ = false;
};

// C API

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
