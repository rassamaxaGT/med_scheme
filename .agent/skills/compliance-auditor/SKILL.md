---
name: compliance-auditor
description: Conduct a full-scale compliance audit of the codebase against the technical specification (ТЗ). Use this skill whenever the user asks to check/verify/audit how well the code matches the spec, validate that all requirements are implemented, find missing features, identify deviations from the ТЗ, or produce a compliance report. Also trigger this skill when the user asks to "проверить соответствие кода ТЗ", "провести аудит", "что не реализовано по ТЗ", or "сравнить код со спецификацией".
---

# Compliance Auditor Skill

This skill conducts a structured, full-scale audit of a codebase against a technical specification (ТЗ / Requirements Document). The output is a rich, actionable compliance report saved as a markdown artifact.

---

## When to Run This Skill

Run when the user wants to know how well the code matches the spec — what is implemented, what is missing, what deviates, and what architectural risks exist.

---

## The Audit Protocol

### Step 1: Gather and Parse the Specification

1. Locate all spec/ТЗ documents in the project root. Look for:
   - `spek.md`, `spec.md`, `ТЗ.md`, `REQUIREMENTS.md`
   - `PROJECT_DOCUMENTATION.md` or `.txt`
   - Any document in `.agent/plans/` named `implementation_plan.md` or `architecture.md`
2. Read each document **completely** — do not skip sections.
3. Extract every **functional requirement** (user story / feature / acceptance criterion) and every **non-functional requirement** (architecture, performance, platform, offline, etc.).
4. Organize them into a structured checklist before touching any code. Group by epic / module.

### Step 2: Map Requirements to Code

For each requirement, find the corresponding implementation:
- Use `list_dir` to understand the code structure.
- Use `view_file` to read relevant source files — entry points, BLoC files, repository implementations, UI widgets, painter classes.
- Use `grep_search` to find specific feature implementations (e.g., search for `pressure`, `compute(`, `customStamp`, feature class names).
- Check **both** platforms if the project is crossplatform (e.g., IO impl vs. Web impl).

Do not read files you don't need. Be surgical — start with entry points and work outward to specific features only when needed.

### Step 3: Assess Each Requirement

For each requirement assign one of four statuses:

| Status | Meaning |
|---|---|
| ✅ **IMPLEMENTED** | Feature is present, working, matches spec intent |
| ⚠️ **PARTIAL** | Feature exists but is incomplete, has gaps, or edge cases are missing |
| ❌ **MISSING** | Feature is not implemented at all |
| 🔀 **DEVIATED** | Feature is implemented differently from the spec — may be intentional or a bug |

Always cite **exact file paths and line numbers** when marking something as IMPLEMENTED or PARTIAL.

### Step 4: Synthesize the Report

Compile all findings into the compliance report artifact (see template below). The report must include:
- **Executive summary** with overall coverage percentage
- **Full requirement checklist** — every spec requirement with status + evidence
- **Deviation log** — items marked PARTIAL, MISSING, or DEVIATED with detailed explanations
- **Architecture compliance** — does the code match the stated architectural pattern?
- **Prioritized recommendations** — what to fix first, second, third

---

## Report Template

Save the report to the artifact directory as `compliance_audit.md`. Use **exactly** this structure:

```markdown
# Отчёт о соответствии кода ТЗ: [Project Name]

_Дата аудита: [date]_

---

## 1. Сводка (Executive Summary)

| Метрика | Значение |
|---|---|
| Всего требований проверено | N |
| ✅ Реализовано полностью | N (XX%) |
| ⚠️ Реализовано частично | N (XX%) |
| ❌ Не реализовано | N (XX%) |
| 🔀 Отклонение от ТЗ | N (XX%) |
| **Итоговый балл соответствия** | **XX%** |

[1–2 sentences: overall verdict]

---

## 2. Детальный чеклист требований

### Эпик [N]: [Epic Name]

| # | Требование | Статус | Реализация / Комментарий |
|---|---|---|---|
| 1 | [Requirement text] | ✅ | [file:line — brief note] |
| 2 | [Requirement text] | ⚠️ | [what works, what's missing] |
| 3 | [Requirement text] | ❌ | [why it's missing] |

[Repeat for each epic]

---

## 3. Детальный разбор отклонений

For each ⚠️ PARTIAL, ❌ MISSING, or 🔀 DEVIATED item:

### [Issue title]
- **Требование:** [exact text from spec]
- **Статус:** ⚠️ / ❌ / 🔀
- **Детали:** [what is and isn't implemented, with file references]
- **Риск:** LOW / MEDIUM / HIGH
- **Рекомендация:** [what to do to fix it]

---

## 4. Соответствие архитектурным требованиям

| Требование | Статус | Заметки |
|---|---|---|
| Clean Architecture | ✅ / ⚠️ / ❌ | ... |
| [Other arch requirements] | ... | ... |

---

## 5. Приоритизированные рекомендации

### 🔴 Высокий приоритет
1. ...

### 🟡 Средний приоритет
1. ...

### 🟢 Низкий приоритет / Nice-to-have
1. ...
```

---

## Audit Best Practices

- **Be factual, not speculative.** Only mark something ❌ MISSING if you have verified it's not in the code (use grep to confirm).
- **Cite evidence.** For every ✅ and ⚠️, link to the specific file and describe what the code does.
- **Check both paths.** For crossplatform code (conditional imports), verify the feature works in all relevant platform implementations.
- **Look for dead code.** Data models or enum values that exist but are never wired up to the UI are effectively MISSING from the user's perspective.
- **Check the task list** (`.agent/plans/task.md`) to see what was planned — this helps separate intentional omissions from bugs.
- **Separate spec versions.** If the project has multiple ТЗ documents (original spec + later updated docs), note which version you are auditing against and flag conflicts between spec versions.

---

## Coverage Score Formula

```
Score = (IMPLEMENTED * 1.0 + PARTIAL * 0.5) / TOTAL_REQUIREMENTS * 100%
```
