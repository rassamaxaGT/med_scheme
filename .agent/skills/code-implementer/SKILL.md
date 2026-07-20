---
name: code-implementer
description: Execute coding tasks based on architectural designs and implementation plans (specifically those created by spec-planner under .agent/plans/). Use this skill whenever the user asks to implement code, run the task list, execute the implementation plan, code the features from a plan, or start implementing code based on plans/architecture.
---

# Code Implementer Skill

A skill to automate code implementation based on the plans created by `spec-planner` (`.agent/plans/task.md`, `.agent/plans/architecture.md`, `.agent/plans/implementation_plan.md`).

## Workflow

When triggered to implement a feature or run a plan:

### 1. Read Plan Artifacts
Read the following planning files to understand the context:
- [.agent/plans/task.md](file:///d:/projects/med_scheme/.agent/plans/task.md)
- [.agent/plans/architecture.md](file:///d:/projects/med_scheme/.agent/plans/architecture.md)
- [.agent/plans/implementation_plan.md](file:///d:/projects/med_scheme/.agent/plans/implementation_plan.md)

### 2. Identify the Next Task
Locate the first uncompleted task in `.agent/plans/task.md` (marked as `[ ]`). Focus on ONLY one task at a time to maintain high accuracy and prevent scope creep.

### 3. Implement the Code
- Read existing code or create the target file (as specified in `architecture.md`).
- Implement the requested logic, adhering to the Clean Architecture guidelines, BLoC state management rules, and code patterns described in `architecture.md`.
- Ensure there are no empty mock-ups, placeholders, or incomplete comments. The code must be fully operational.
- Maintain existing code styles and import conventions.

### 4. Compile and Verify
- Run code analyzer or tests (e.g. `flutter analyze` or `flutter test`) using the relevant MCP tool or terminal commands.
- If there are syntax errors or lint warnings, fix them immediately before proceeding.

### 5. Update Task List
Modify [.agent/plans/task.md](file:///d:/projects/med_scheme/.agent/plans/task.md) using the file editing tools, changing the completed task from `[ ]` to `[x]`.

### 6. Report Back
Present the implemented changes to the user, providing file links to the modified files, and asking if they want to proceed with the next task.
