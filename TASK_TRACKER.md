# Таск-трекер: МедРисунок v2.0

> Статус: `[x]` — выполнено

---

## 🔴 Этап 1 — Правки визуала существующих маркеров (✅ Выполнено)

### 1.1 Инфильтрат (ShapeAction / `shapeType == 'infiltrate'`)
- [x] **`canvas_painter.dart`**: заливка — сделать непрозрачной `0xFF5C4033`
- [x] **`draw_action.dart`**: добавить поле `double rotation` в `ShapeAction` и `StampAction`
- [x] **`draw_action_model.dart`**: сериализация `rotation` в `toJson`/`fromJson`
- [x] **`canvas_painter.dart`**: поворот прямоугольника выделения и маркеров
- [x] **`canvas_widget.dart`**: интерактивная кнопка вращения + точное хит-тестирование повернутых объектов

### 1.2 Эндометриома (ShapeAction / `shapeType == 'endometrioma'`)
- [x] **`canvas_painter.dart`**: изменить форму с `drawOval` на `drawCircle`
- [x] **`canvas_painter.dart`**: граница — красная `0xFFD32F2F`
- [x] **`canvas_painter.dart`**: заливка — `0xCC7B4F35`
- [x] **`canvas_painter.dart`**: толщина контура — 3.0

### 1.3 Спайки (StrokeAction / `brushType == 'adhesions'`)
- [x] **`canvas_painter.dart`**: убрать основную линию, оставить только паутину
- [x] **`draw_bloc.dart`**: цвет по умолчанию → серый `0xFF9E9E9E`
- [x] **`floating_toolbox.dart`**: обновить `customColor` кнопки спаек → серый `0xFF9E9E9E`

### 1.4 Фиброз (StrokeAction / `brushType == 'fibrosis'`)
- [x] **`canvas_painter.dart`**: уменьшить `hatchSpacing` до 12.0
- [x] **`canvas_painter.dart`**: крестообразная штриховка под 90°
- [x] **`draw_state.dart`**: `currentStrokeWidth: 2.0` по умолчанию

### 1.5 Миома (ShapeAction / `shapeType == 'myoma'`)
- [x] **`canvas_painter.dart`**: убрать номер FIGO
- [x] **`canvas_painter.dart`**: контур фуксия/розовый, простая палитра
- [x] **`floating_toolbox.dart`**: убрать FIGO-селектор из `SettingsBubble`

### 1.6 ВМС (StampAction / `stampType == 'iud'`)
- [x] **`canvas_painter.dart`**: убрать спираль вокруг ножки
- [x] **`canvas_painter.dart`**: изменить размер: `width = 29.0`, `height = 36.0` (+20%)
- [x] **`draw_bloc.dart`**: цвет по умолчанию → чёрный `0xFF000000`

### 1.7 Очаг (StampAction / `stampType == 'foci'`)
- [x] **`canvas_painter.dart`**: восьмиконечная звезда
- [x] **`draw_bloc.dart`**: цвет по умолчанию → вишнёвый `0xFF880E4F`
- [x] **`floating_toolbox.dart`**: переключатель «Свежий / Старый» очаг
- [x] **`floating_toolbox.dart`**: ползунок размера очага

### 1.8 Стрелка / TextAction
- [x] **`draw_bloc.dart`**: цвет по умолчанию → чёрный `0xFF000000`
- [x] **`floating_toolbox.dart`**: разделить инструмент на «Линия расстояния» и «Линия-указатель»

---

## 🔴 Этап 2 — Тулбокс: порядок, UX, ползунок (✅ Выполнено)

- [x] **`floating_toolbox.dart`**: переупорядочить инструменты согласно ТЗ (14 пунктов)
- [x] **`floating_toolbox.dart`**: подменю для «Инфильтрат» (группа с «+»)
- [x] **`editor_screen.dart`**: кнопка «Движение» в AppBar
- [x] **`floating_toolbox.dart`**: опция пунктира для обычной кисти (`pencil`)
- [x] **`floating_toolbox.dart`**: ползунок `currentStrokeWidth` для размера всех штампов

---

## 🟡 Этап 3 — Новые инструменты (рисуются кодом) (✅ Выполнено)

### 3.1 Инфильтрат кишки (`ToolType.bowelInfiltrate`)
- [x] **`draw_action.dart`**: `ToolType.bowelInfiltrate`
- [x] **`canvas_painter.dart`**: дуга эллипса (~180°) с фестончатым контуром и коричневой заливкой

### 3.2 Фолликул (`ToolType.follicle`)
- [x] **`draw_action.dart`**: `ToolType.follicle`
- [x] **`canvas_painter.dart`**: `drawCircle` только stroke, голубой контур

### 3.3 Аденомиоз (`ToolType.adenomyosis`)
- [x] **`draw_action.dart`**: `ToolType.adenomyosis`
- [x] **`canvas_painter.dart`**: `drawCircle` с `MaskFilter.blur(BlurStyle.normal, 12.0)`

---

## 🟡 Этап 4 — Новые штампы, рисуемые кодом (✅ Выполнено)

### 4.1 ГУИ — «Головной убор индейца» (`ToolType.gui`)
- [x] **`draw_action.dart`**: `ToolType.gui`
- [x] **`canvas_painter.dart`**: ГУИ кодом (веер из 7 перьев + ободок)

### 4.2 Полип (`ToolType.polyp`)
- [x] **`draw_action.dart`**: `ToolType.polyp`
- [x] **`canvas_painter.dart`**: полип кодом (капля на ножке со штриховкой)

---

## 🔵 Этап 5 — Архитектура: мультихолст (✅ Выполнено)

### 5.1 Новая сущность `PageData`
- [x] **`page_data.dart`**: создан класс `PageData` (`id`, `pageType`, `title`, `backgroundPath`, `history`, `undoStack`, `redoStack`)
- [x] **`project_data.dart`**: содержит `List<PageData> pages`

### 5.2 Рефакторинг `DrawBloc`
- [x] **`draw_state.dart`**: `int currentPageIndex`, `List<PageData> pages`, геттеры `history`, `undoStack`, `redoStack`, `backgroundPath`
- [x] **`draw_bloc.dart`**: обработчики `SwitchPageEvent`, `AddPageEvent`, `RemovePageEvent`

### 5.3 Таб-навигация в `EditorScreen`
- [x] **`editor_screen.dart`**: строка вкладок под AppBar (по умолчанию "Таз" и "Матка")
- [x] **`editor_screen.dart`**: кнопка «+» для добавления листа, кнопка «x» для удаления листа

---

## 🔵 Этап 6 — Обновление сериализации `.meddraw` (✅ Выполнено)

- [x] **`page_data_model.dart`**: `PageDataModel.toJson()` / `fromJson()`
- [x] **`project_repository_impl.dart` / `project_repository_web.dart`**: упаковка `pages[]` в `project.json`
- [x] **`project_repository_impl.dart` / `project_repository_web.dart`**: полная обратная совместимость со старыми одностраничными `.meddraw`

---

## 🟢 Этап 7 — Предустановленные схемы (заглушки + TODO) (✅ Выполнено)

- [x] Папка `assets/schemes/` зарегистрирована в `pubspec.yaml`
- [x] **`editor_screen.dart`**: виджет `_SchemeSelector` (лента чипов схем) с `// TODO(schemes)` комментариями

---

## 📊 Итого задач

| Этап | Задач | Статус |
|------|-------|--------|
| 1 — Маркеры визуал | 39 | 39 / 39 ✅ |
| 2 — Тулбокс UX | 6 | 6 / 6 ✅ |
| 3 — Новые инструменты | 18 | 18 / 18 ✅ |
| 4 — Новые штампы | 12 | 12 / 12 ✅ |
| 5 — Архитектура | 19 | 19 / 19 ✅ |
| 6 — Сериализация | 8 | 8 / 8 ✅ |
| 7 — Схемы (заглушки) | 12 | 12 / 12 ✅ |
| **ИТОГО** | **114** | **114 / 114** (100% выполнено) |
