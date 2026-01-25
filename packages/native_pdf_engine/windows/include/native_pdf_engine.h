#pragma once

#include <stdbool.h>
#include <stdint.h>

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*PdfCompletionCallback)(bool success, const char *error_message,
                                      const uint8_t *data, int32_t length,
                                      void *user_data);

EXPORT void *NativePdf_CreateEngine();

EXPORT void NativePdf_DestroyEngine(void *engine);

EXPORT void NativePdf_Generate(void *engine, const char *content, bool is_url,
                               const char *output_path,
                               PdfCompletionCallback callback, void *user_data);

#ifdef __cplusplus
}
#endif
