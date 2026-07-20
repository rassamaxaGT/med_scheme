---
name: project-onboarder
description: Qualitatively familiarize the agent with the project codebase, architecture, tech stack, key components, dependencies, build/test commands, and conventions. Trigger this skill whenever the user asks to get familiar with the project, explore the repository, understand how the code is structured, onboard to the codebase, analyze the project, or get a high-level overview of the application.
---

# Project Onboarder Skill

This skill guides you through a structured, highly efficient protocol to get fully oriented in any project codebase, understand its architecture, dependencies, build/test workflows, code styles, and active development context. 

Follow this protocol systematically when entering a new project or when explicitly requested to onboard.

---

## The Onboarding Protocol

Perform your exploration in four structured phases to build a comprehensive, high-fidelity model of the codebase without wasting tokens or getting lost in minor details.

### Phase 1: High-Level Reconnaissance (Detect & Map)
1. **Identify the Tech Stack & Environment**: 
   - Start by listing the root directory using `list_dir` or finding configuration/manifest files.
   - Look for manifest files like `pubspec.yaml` (Dart/Flutter), `package.json` (Node.js/JS/TS), `requirements.txt`/`pyproject.toml` (Python), `Cargo.toml` (Rust), `go.mod` (Go), `build.gradle`/`pom.xml` (Java/Kotlin), or `Csproj` (C#).
   - Read the manifest file to determine the main language, framework, key dependencies, and project metadata.
2. **Locate General Documentation**:
   - Search for `README.md`, `CONTRIBUTING.md`, or other top-level markdown documentation.
   - View the README to understand the project's purpose, setup instructions, and high-level architecture.
3. **Check for Agent Customizations**:
   - Check if there is an `.agent` directory, `.agents` folder, or `AGENTS.md` rules file in the workspace or global config. Read them to discover project-specific rules, custom skills, or workflows.
   - Look for Knowledge Items (KIs) provided in the agent's initialization metadata.

### Phase 2: Structural & Architectural Mapping
1. **Map Key Directories**:
   - Explore main directories (e.g., `lib/`, `src/`, `app/`, `tests/`) to understand the organizational layout.
   - Identify which architectural pattern is used:
     - *Layered / Clean Architecture*: Separate folders for domain, data, presentation.
     - *Feature-First / Domain-Driven*: Folders grouped by feature/use case containing their own logic and UI.
     - *Standard MVC / MVVM*: Folders for models, views, controllers/viewmodels.
2. **Find Key Entry Points**:
   - Locate the main application entry points where execution begins (e.g., `lib/main.dart`, `src/index.ts`, `app.py`, `src/App.tsx`).
   - Read the entry point files to see how the app is initialized, what global providers/contexts are set up, and how routing is configured.
3. **Trace Core Logic Flow**:
   - Identify 2-3 critical domain files or services (e.g., API clients, database configurations, state management classes) to see how logic flows between components.

### Phase 3: Developer Workflows & Commands
1. **Discover Build & Run Commands**:
   - Find scripts or tasks configured in manifest files (e.g., `scripts` block in `package.json`, custom gradle tasks, or run configurations).
   - Document how to build and run the application locally.
2. **Locate & Understand Test Suites**:
   - Look for a `test/` or `tests/` directory or inline test files (`*.test.ts`, `*_test.dart`).
   - Determine the testing framework being used and the exact command to run the tests.
3. **Find Linting & Formatting Rules**:
   - Look for configuration files like `analysis_options.yaml` (Dart), `eslint.config.js` / `.eslintrc` (JavaScript/TypeScript), `pyproject.toml` / `flake8` (Python).

### Phase 4: Active Development Context
1. **Determine Current State & Tasks**:
   - Check if there is a task plan or TODO list in progress (e.g., `.agent/plans/`, `task.md`, `implementation_plan.md`, or open issues).
   - If git is available and you have permission, check `git status` or recent commits (`git log -n 5`) to see what was recently changed.

---

## Synthesis & Codebase Map

After completing the reconnaissance, compile your findings into a structured codebase map.
Save this map as `.agent/project_context.md` (or write it to the chat if repository file edits are not appropriate). This ensures that future sessions can immediately load this context instead of performing the exploration again.

### Context Map Template
Use this exact markdown template for the `.agent/project_context.md` file:

```markdown
# Project Context Map: [Project Name]

## 1. Executive Summary & Tech Stack
- **Language & Framework**: [e.g., Dart 3.x, Flutter 3.x]
- **Primary Purpose**: [1-2 sentences explaining what the application does]
- **Key Dependencies**:
  - `dependency-1`: [purpose]
  - `dependency-2`: [purpose]

## 2. Directory Layout & Architecture
- **Architecture Pattern**: [e.g., Feature-First, Clean Architecture, MVC]
- **Directory Structure**:
  - `/dir1`: [description]
  - `/dir2`: [description]

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [link to file](file:///path/to/entry)
- **Initialization Steps**:
  1. [Step 1]
  2. [Step 2]

## 4. Key Workflows & Commands
- **Run Application**: `[command]`
- **Build Production**: `[command]`
- **Run Tests**: `[command]`
- **Lint/Format**: `[command]`

## 5. Development Conventions & Guidelines
- **State Management**: [e.g., Riverpod, Bloc, Redux, None]
- **Styling & Design System**: [e.g., Material Design, TailwindCSS, Vanilla CSS]
- **Error Handling & Logging**: [conventions used in the codebase]
- **Testing Patterns**: [conventions for writing tests]

## 6. Active Development Context
- **Current Goals/Tasks**: [what is currently being worked on]
- **Recent Changes**: [summary of recent modifications]
- **Known Challenges/Notes**: [any gotchas, performance issues, or architectural debt]
```

---

## Onboarding Best Practices (For the Agent)

- **Avoid Rabbit Holes**: Do not read large source files line-by-line during the reconnaissance phase. Stick to high-level structural directories and config files.
- **Use Search Strategically**: If you need to find where a specific service or class is defined, use `grep_search` rather than manual file exploration.
- **Link Code Symbols**: When referencing files, classes, or main configurations in the context map, always use clickable Markdown links (e.g., `[main.dart](file:///absolute/path/to/lib/main.dart)`).
