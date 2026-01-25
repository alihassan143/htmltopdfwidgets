cmake_minimum_required(VERSION 3.14)

project(native_pdf_engine_windows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native_pdf_engine_windows SHARED
  "native_pdf_engine_windows.cpp"
)

target_include_directories(native_pdf_engine_windows PRIVATE "include")

# Download WebView2 NuGet package
set(WEBVIEW2_VERSION "1.0.2210.55")
set(WEBVIEW2_URL "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/${WEBVIEW2_VERSION}")
set(WEBVIEW2_DIR "${CMAKE_CURRENT_BINARY_DIR}/webview2_package")

if(NOT EXISTS "${WEBVIEW2_DIR}")
    message(STATUS "Downloading Microsoft.Web.WebView2.${WEBVIEW2_VERSION}...")
    file(DOWNLOAD "${WEBVIEW2_URL}" "${WEBVIEW2_DIR}/webview2.zip" STATUS DOWNLOAD_STATUS)
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download WebView2 package.")
    endif()
    
    file(ARCHIVE_EXTRACT INPUT "${WEBVIEW2_DIR}/webview2.zip" DESTINATION "${WEBVIEW2_DIR}")
endif()

target_include_directories(native_pdf_engine_windows PRIVATE "${WEBVIEW2_DIR}/build/native/include")

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(WEBVIEW2_ARCH "x64")
else()
    set(WEBVIEW2_ARCH "x86")
endif()

target_link_libraries(native_pdf_engine_windows PRIVATE 
    "${WEBVIEW2_DIR}/build/native/${WEBVIEW2_ARCH}/WebView2Loader.dll.lib"
)

# Copy WebView2Loader.dll to output directory
add_custom_command(TARGET native_pdf_engine_windows POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${WEBVIEW2_DIR}/build/native/${WEBVIEW2_ARCH}/WebView2Loader.dll"
    "$<TARGET_FILE_DIR:native_pdf_engine_windows>"
)

target_compile_definitions(native_pdf_engine_windows PRIVATE FLUTTER_PLUGIN_IMPL)
target_link_libraries(native_pdf_engine_windows PRIVATE flutter_wrapper_plugin)

# List of libraries to link
target_link_libraries(native_pdf_engine_windows PRIVATE
  kernel32
  user32
  shell32
  ole32
  oleaut32
  uuid
  shlwapi
)
