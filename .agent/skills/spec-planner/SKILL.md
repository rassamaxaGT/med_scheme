---
name: spec-planner
description: Develop an implementation plan and system architecture based on a specification document (ТЗ / Technical Specification / Requirements), and record them into files for subsequent coding agents. Use this skill whenever the user provides a task description, requirements, ТЗ, or specification and wants to plan the architecture, design components, or prepare files for implementation.
---

# Spec Planner Skill

A skill to convert a specification or requirements document (ТЗ - Техническое Задание) into structural planning files (`architecture.md`, `implementation_plan.md`, `task.md`) so that development agents can immediately begin execution with clear guidelines.

## Workflow

When provided with a specification, requirements, or a ТЗ:

### 1. Requirements Analysis
Carefully read the provided specification. Identify:
- Core user requirements and features.
- System dependencies, packages, and frameworks.
- Potential risks, edge cases, and design constraints.

### 2. Design the Architecture
Define the structural layout of the code changes.
- Identify new and modified files/components.
- Define data models, classes, functions, API payloads, or state management approaches.
- Save this information to `.agent/plans/architecture.md`.

Use this template for `.agent/plans/architecture.md`:
```markdown
# Architecture Design: [Feature/Project Name]

## Overview
Brief description of the architectural approach.

## Components & File Structure
List of new and modified files and their roles in the system. Use file links (e.g., [main.dart](file:///d:/projects/med_scheme/lib/main.dart)).

## Data Models / Schemas
Details of data types, database schemas, or state models.

## APIs & External Integrations
Endpoints, parameters, and payloads.
```

### 3. Draft the Implementation Plan
Define the sequence of tasks. Group them logically so dependencies are resolved first (e.g., database schema before UI, mock service before real API integration).
- Save this information to `.agent/plans/implementation_plan.md`.

Use this template for `.agent/plans/implementation_plan.md`:
```markdown
# Implementation Plan: [Feature/Project Name]

## Phases of Development
- **Phase 1: Foundation & Setup** (configuration, basic models, dependencies)
- **Phase 2: Core Logic & Services** (APIs, databases, services)
- **Phase 3: UI & Presentation** (views, controllers, widgets)
- **Phase 4: Integration & Edge Cases** (connecting services to UI, handling errors)

## Risks & Considerations
Highlight any tricky areas, performance concerns, or API limitations.
```

### 4. Create the Task Checklist
Translate the implementation plan phases into a markdown checklist. Subsequent agents will use this file as their TODO list, updating it as they make progress.
- Save this checklist to `.agent/plans/task.md`.

Use this template for `.agent/plans/task.md`:
```markdown
# Task List: [Feature/Project Name]

- [ ] **Phase 1: Foundation & Setup**
  - [ ] Add dependency [package_name] to pubspec.yaml
  - [ ] Create data models in [model_file.dart]
- [ ] **Phase 2: Core Logic & Services**
  - [ ] Implement database sync/caching in [db_service.dart]
  - [ ] Add integration tests for caching logic
- [ ] **Phase 3: UI & Presentation**
  - [ ] Create user interface widgets in [view_widget.dart]
- [ ] **Phase 4: Verification**
  - [ ] Perform manual testing of key user flows
  - [ ] Run full project tests
```

### 5. Final Report
Summarize the created files for the user and provide links to each file:
- [.agent/plans/architecture.md](file:///d:/projects/med_scheme/.agent/plans/architecture.md)
- [.agent/plans/implementation_plan.md](file:///d:/projects/med_scheme/.agent/plans/implementation_plan.md)
- [.agent/plans/task.md](file:///d:/projects/med_scheme/.agent/plans/task.md)
