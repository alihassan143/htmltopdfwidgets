# HTMLtoPDFWidgets Workspace

Welcome to the `htmltopdfwidgets` monorepo! This repository contains packages for converting HTML and Markdown to PDF in Flutter, using different rendering engines.

## Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [htmltopdfwidgets](packages/htmltopdfwidgets) | [![pub package](https://img.shields.io/pub/v/htmltopdfwidgets.svg)](https://pub.dev/packages/htmltopdfwidgets) | The core package for converting HTML and Markdown to PDF widgets. Supports both legacy and new browser-like rendering engines. |
| [htmltopdfwidgets_syncfusion](packages/syncfusion_htmltopdfwidgets) | [![pub package](https://img.shields.io/pub/v/htmltopdfwidgets_syncfusion.svg)](https://pub.dev/packages/htmltopdfwidgets_syncfusion) | A finalized package that uses Syncfusion PDF widgets for rendering. |

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
