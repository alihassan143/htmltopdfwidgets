cmake_minimum_required(VERSION 3.14)

project(native_pdf_engine_windows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native_pdf_engine_windows SHARED
  "native_pdf_engine_windows.cpp"
)

target_include_directories(native_pdf_engine_windows PRIVATE "include")

# Link libraries
# On Windows, we need to link against WebView2Loader using helper or NuGet
# For Flutter desktop plugins, it's common to expect WebView2 to be available or use a package.
# Depending on how we distribute, we might need to fetch packages.
# Using 'packages' via FetchContent or find_package if available.
# But standard Flutter windows plugin template handles this differently.

# We will rely on the standard windows libs for now and assume headers are available 
# or use a raw implementation if possible, but WebView2 is not in standard libs.
# We need Microsoft.Web.WebView2 package.

# Simplified: We assume usage of the NuGet package manager which Flutter Windows uses.
# But for a pure plugin, we might need to add it to generic dependencies.

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
