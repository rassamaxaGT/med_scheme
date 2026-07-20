# Developer Workflows: Testing and Linting

I have analyzed the developer workflows, testing setup, and static analysis/linting rules for this project.

## 1. Running the Test Suite
- **Testing Framework**: The project uses **`flutter_test`** (configured as a dev dependency in `pubspec.yaml`), which is the standard testing library for Flutter unit and widget tests.
- **Run Command**: To run all tests in the project, use:
  ```bash
  flutter test
  ```
- **Test files**: Located under the root `/test` folder (e.g., [widget_test.dart](file:///d:/projects/med_scheme/test/widget_test.dart)).

## 2. Linting and Static Analysis
- **Linting Rules**: Defined in [analysis_options.yaml](file:///d:/projects/med_scheme/analysis_options.yaml) in the root directory.
- **Linter Preset**: It inherits the recommended set of lints for Flutter apps:
  ```yaml
  include: package:flutter_lints/flutter.yaml
  ```
- **Custom Rules**: You can add/modify specific rules in the `linter/rules` block of the configuration file.
- **Run Lint Check Command**: To analyze the project and check for static analysis warnings:
  ```bash
  flutter analyze
  ```
