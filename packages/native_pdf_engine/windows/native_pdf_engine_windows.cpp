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

  // ... (Generate method remains mostly same, ensuring headers are included)

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

    // PrintToPdf takes 2 arguments: ResultFilePath and Handler.
    // It does not take a print settings object in this version (unlike
    // WebKitGTK logic).
    webview7->PrintToPdf(
        wpath.c_str(),
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

void *NativePdf_CreateEngine() { return new PdfEngine(); }

void NativePdf_DestroyEngine(void *engine) {
  if (engine)
    delete static_cast<PdfEngine *>(engine);
}

void NativePdf_Generate(void *engine, const char *content, bool is_url,
                        const char *output_path, PdfCompletionCallback callback,
                        void *user_data) {
  if (engine) {
    static_cast<PdfEngine *>(engine)->Generate(content, is_url, output_path,
                                               callback, user_data);
  }
}
