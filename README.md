# Flutter Packages Workspace

Welcome to the `flutter-packages` monorepo! This repository contains packages for converting HTML and Markdown to PDF in Flutter, using different rendering engines.

## Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [htmltopdfwidgets](packages/htmltopdfwidgets) | [![pub package](https://img.shields.io/pub/v/htmltopdfwidgets.svg)](https://pub.dev/packages/htmltopdfwidgets) | The core package for converting HTML and Markdown to PDF widgets. Supports both legacy and new browser-like rendering engines. |
| [htmltopdf_syncfusion](packages/htmltopdf_syncfusion) | [![pub package](https://img.shields.io/pub/v/htmltopdf_syncfusion.svg)](https://pub.dev/packages/htmltopdf_syncfusion) | A finalized package that uses Syncfusion PDF widgets for rendering. |
| [docx_creator](packages/docx_creator) | [![pub package](https://img.shields.io/pub/v/docx_creator.svg)](https://pub.dev/packages/docx_creator) | A developer-first Dart package for creating professional DOCX documents with fluent API, Markdown/HTML parsing, and comprehensive formatting. |
| [docx_file_viewer](packages/docx_file_viewer) | [![pub package](https://img.shields.io/pub/v/docx_file_viewer.svg)](https://pub.dev/packages/docx_file_viewer) | A native Flutter DOCX viewer that renders Word documents using Flutter widgets. |
| [native_pdf_engine](packages/native_pdf_engine) | [![pub package](https://img.shields.io/pub/v/native_pdf_engine.svg)](https://pub.dev/packages/native_pdf_engine) | A high-performance, FFI-based Flutter package to convert HTML and URLs to PDF using native OS webviews. |

## Workspace Management

This repository uses [Melos](https://melos.invertase.dev/) to manage the workspace.

### Getting Started

1.  **Install Melos**:
    ```bash
    dart pub global activate melos
    ```

2.  **Bootstrap the workspace**:
    ```bash
    melos bootstrap
    ```
    This command links local packages together and installs dependencies.

### Common Commands

-   `melos run analyze`: Run Dart analyzer in all packages.
-   `melos run test`: Run tests in all packages.
-   `melos run format`: Format code in all packages.

## License

This repository is licensed under the [Apache License 2.0](LICENSE).
