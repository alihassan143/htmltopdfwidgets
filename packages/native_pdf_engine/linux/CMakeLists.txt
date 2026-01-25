cmake_minimum_required(VERSION 3.10)

project(native_pdf_engine_linux LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native_pdf_engine_linux SHARED
  "native_pdf_engine_linux.cc"
)

target_include_directories(native_pdf_engine_linux PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Find GTK and WebKit2GTK
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)
pkg_check_modules(WEBKIT REQUIRED webkit2gtk-4.0)

target_include_directories(native_pdf_engine_linux PRIVATE ${GTK_INCLUDE_DIRS} ${WEBKIT_INCLUDE_DIRS})
target_link_libraries(native_pdf_engine_linux PRIVATE ${GTK_LIBRARIES} ${WEBKIT_LIBRARIES})

target_compile_definitions(native_pdf_engine_linux PRIVATE FLUTTER_PLUGIN_IMPL)
