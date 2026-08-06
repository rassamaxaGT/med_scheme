# Таск-трекер: МедРисунок v2.0

> Статус: `[ ]` — не начато | `[/]` — в процессе | `[x]` — выполнено

---

## 🔴 Этап 1 — Правки визуала существующих маркеров

### 1.1 Инфильтрат (ShapeAction / `shapeType == 'infiltrate'`)
- [x] **`canvas_painter.dart`**: заливка — сделать непрозрачной `0xFF5C4033` (убрать `0x66`)
- [x] **`draw_action.dart`**: добавить поле `double rotation` в `ShapeAction` (угол поворота в радианах, по умолчанию 0.0)
- [x] **`draw_action_model.dart`**: добавить сериализацию `rotation` в `toJson`/`fromJson`
- [x] **`canvas_painter.dart`**: применять `canvas.rotate(shape.rotation)` перед отрисовкой инфильтрата
- [x] **`canvas_widget.dart`**: добавить поворот двумя пальцами (rotation gesture) для выбранного объекта типа `infiltrate`

### 1.2 Эндометриома (ShapeAction / `shapeType == 'endometrioma'`)
- [x] **`canvas_painter.dart`**: изменить форму с `drawOval` на `drawCircle` (рисовать вписанный круг в `rect`)
- [x] **`canvas_painter.dart`**: граница — красная `0xFFD32F2F` (было темно-коричневая)
- [x] **`canvas_painter.dart`**: заливка — `0xCC7B4F35` (~80% непрозрачности, светлее инфильтрата)
- [x] **`canvas_painter.dart`**: толщина контура — 3.0

### 1.3 Спайки (StrokeAction / `brushType == 'adhesions'`)
- [x] **`canvas_painter.dart`**: убрать `canvas.drawPath(path, paint)` (основная линия), оставить только паутину
- [x] **`draw_bloc.dart`**: изменить цвет по умолчанию для `ToolType.adhesions` → серый `0xFF9E9E9E` (было зелёный)
- [x] **`floating_toolbox.dart`**: обновить `customColor` кнопки спаек → серый `0xFF9E9E9E`

### 1.4 Фиброз (StrokeAction / `brushType == 'fibrosis'`)
- [x] **`canvas_painter.dart`**: уменьшить `hatchSpacing` до 12.0 (было 15.0)
- [x] **`canvas_painter.dart`**: добавить второй штрих под 90° к первому (крестообразная штриховка)
- [x] **`draw_state.dart`**: установить `currentStrokeWidth: 2.0` по умолчанию при выборе фиброза
- [x] **`draw_bloc.dart`**: в `SelectToolEvent` для `ToolType.fibrosis` — форсировать `strokeWidth: 2.0`

### 1.5 Миома (ShapeAction / `shapeType == 'myoma'`)
- [x] **`canvas_painter.dart`**: убрать отрисовку номера FIGO (весь блок `TextPainter` в ветке `myoma`)
- [x] **`canvas_painter.dart`**: убрать гибридную раскраску (блок `figo == '2-5'`)
- [x] **`canvas_painter.dart`**: заливка по умолчанию — розовая `0x4DFF69B4` (30% непрозрачности), контур `0xFFFF69B4` (фуксия)
- [x] **`draw_bloc.dart`**: убрать `ChangeFigoTypeEvent` из логики или оставить как deprecated
- [x] **`draw_bloc.dart`**: убрать `_getColorForTool` логику для FIGO-типов 0–8
- [x] **`draw_state.dart`**: убрать поле `currentFigoType` (или сохранить для обратной совместимости — пометить `@Deprecated`)
- [x] **`draw_event.dart`**: убрать / пометить `ChangeFigoTypeEvent` как устаревший
- [x] **`floating_toolbox.dart`**: убрать FIGO-селектор из `SettingsBubble`
- [x] **`floating_toolbox.dart`**: добавить простую палитру для миом (4–5 цветов: фуксия, розовый, синий, зелёный, серый)
- [x] **`draw_action_model.dart`**: `figoType` — сохранить в JSON для обратной совместимости (но не использовать в UI)

### 1.6 ВМС (StampAction / `stampType == 'iud'`)
- [x] **`canvas_painter.dart`**: убрать отрисовку спирали (блок `spiralPath`)
- [x] **`canvas_painter.dart`**: изменить размер: `width = 29.0` (+20% от 24), `height = 36.0` (+20% от 30)
- [x] **`draw_bloc.dart`**: изменить цвет по умолчанию для `ToolType.iud` → чёрный `0xFF000000` (было синий)
- [x] **`floating_toolbox.dart`**: убрать палитру цветов для ВМС (цвет фиксирован)

### 1.7 Очаг (StampAction / `stampType == 'foci'`)
- [x] **`canvas_painter.dart`**: изменить форму с клякзы на **восьмиконечную звезду** (вычислить 16 точек)
- [x] **`canvas_painter.dart`**: цвет по умолчанию — вишнёвый `0xFF880E4F`
- [x] **`draw_bloc.dart`**: изменить цвет по умолчанию `ToolType.foci` → вишнёвый `0xFF880E4F`
- [x] **`floating_toolbox.dart`**: добавить переключатель «Свежий / Старый» очаг (вишнёвый / бледно-жёлтый `0xFFFFF9C4`)
- [x] **`floating_toolbox.dart`**: добавить ползунок размера очага (влияет на `currentStrokeWidth` как прокси для размера штампа)
- [x] **`canvas_painter.dart`**: масштабировать звезду по `strokeWidth` (радиус = `strokeWidth * 2`)

### 1.8 Стрелка / TextAction
- [x] **`draw_bloc.dart`**: установить цвет по умолчанию для `ToolType.arrow` → чёрный `0xFF000000`
- [x] **`draw_state.dart`**: минимальная толщина при выборе arrow — 1.5
- [x] **`canvas_painter.dart`**: добавить горизонтальную «полку» под текст (опциональная черта у основания текста стрелки)
- [x] **`floating_toolbox.dart`**: разделить инструмент на 2 кнопки: «Линия расстояния» (dashed) и «Линия-указатель» (solid arrow)
- [x] **`draw_event.dart`**: добавить флаг `bool isPointer` в `DrawEvent` для стрелки-указателя

---

## 🔴 Этап 2 — Тулбокс: порядок, UX, ползунок

- [ ] **`floating_toolbox.dart`**: переупорядочить инструменты согласно ТЗ:
  1. Инфильтрат (с подменю: Инфильтрат / Инфильтрат кишки / ГУИ)
  2. Эндометриома
  3. Очаг
  4. Спайки
  5. Фиброз
  6. Линия расстояния
  7. Линия-указатель
  8. Аденомиоз
  9. Миома
  10. ВМС
  11. Полип
  12. Фолликул
  13. Кисть (в конец)
  14. Ластик (в конец)
- [ ] **`floating_toolbox.dart`**: реализовать **подменю** для «Инфильтрат» (раскрывающаяся группа с «+»)
- [ ] **`editor_screen.dart`**: вынести кнопку «Движение» в постоянно видимую область (floating action button или отдельная иконка над тулбоксом)
- [ ] **`floating_toolbox.dart`**: добавить опцию пунктира к обычной кисти (`pencil`) через переключатель в `SettingsBubble`
- [ ] **`canvas_painter.dart`**: реализовать пунктирный режим для `brushType == 'pencil'` (аналогично `TextAction.isDashed`)
- [ ] **`floating_toolbox.dart`**: убедиться, что ползунок `currentStrokeWidth` влияет на **размер** штампов (foci, follicle, polyp, gui) — не только на толщину линий

---

## 🟡 Этап 3 — Новые инструменты (рисуются кодом)

### 3.1 Инфильтрат кишки (`ToolType.bowelInfiltrate`)
- [ ] **`draw_action.dart`**: добавить `ToolType.bowelInfiltrate` в enum
- [ ] **`draw_action.dart`**: добавить `shapeType == 'bowelInfiltrate'` в `ShapeAction` (поддерживает `rotation`)
- [ ] **`draw_bloc.dart`**: обработать `SelectToolEvent(ToolType.bowelInfiltrate)` → цвет `0xFF5C4033`, форсировать тип
- [ ] **`draw_action_model.dart`**: сериализация для `bowelInfiltrate`
- [ ] **`canvas_painter.dart`**: нарисовать **дугу эллипса** (~180° нижняя половина) с фестончатым контуром и коричневой заливкой
- [ ] **`floating_toolbox.dart`**: добавить кнопку в подменю «Инфильтрат»

### 3.2 Фолликул (`ToolType.follicle`)
- [ ] **`draw_action.dart`**: добавить `ToolType.follicle`
- [ ] **`draw_action.dart`**: добавить `stampType == 'follicle'` in `StampAction`
- [ ] **`draw_bloc.dart`**: цвет по умолчанию — голубой `0xFF29B6F6`, без заливки
- [ ] **`draw_action_model.dart`**: сериализация
- [ ] **`canvas_painter.dart`**: рисовать `drawCircle` только stroke (без fill), голубой контур, радиус из `strokeWidth`
- [ ] **`floating_toolbox.dart`**: добавить кнопку + ползунок размера

### 3.3 Аденомиоз (`ToolType.adenomyosis`)
- [ ] **`draw_action.dart`**: добавить `ToolType.adenomyosis`
- [ ] **`draw_action.dart`**: добавить `shapeType == 'adenomyosis'` в `ShapeAction`
- [ ] **`draw_bloc.dart`**: цвет по умолчанию — вишнёвый `0xFF880E4F`
- [ ] **`draw_action_model.dart`**: сериализация
- [ ] **`canvas_painter.dart`**: рисовать `drawCircle` с `MaskFilter.blur(BlurStyle.normal, 8.0)` — размытые края
- [ ] **`floating_toolbox.dart`**: добавить кнопку

---

## 🟡 Этап 4 — Новые штампы, рисуемые кодом

### 4.1 ГУИ — «Головной убор индейца» (`ToolType.gui`)
- [ ] **`draw_action.dart`**: добавить `ToolType.gui`
- [ ] **`draw_action.dart`**: добавить `stampType == 'gui'` в `StampAction` (поддерживает `scaleX`, `scaleY`)
- [ ] **`draw_bloc.dart`**: цвет по умолчанию — фиолетовый `0xFF7B1FA2`
- [ ] **`draw_action_model.dart`**: сериализация
- [ ] **`canvas_painter.dart`**: нарисовать ГУИ кодом:
  - Горизонтальная широкая дуга (поля)
  - Треугольник/конус наверху (тулья)
  - Масштабируется через `scaleX` (ширина) и `scaleY` (высота)
- [ ] **`floating_toolbox.dart`**: добавить кнопку в подменю «Инфильтрат» (или отдельным пунктом)

### 4.2 Полип (`ToolType.polyp`)
- [ ] **`draw_action.dart`**: добавить `ToolType.polyp`
- [ ] **`draw_action.dart`**: добавить `stampType == 'polyp'` в `StampAction` (поддерживает `scaleX`, `scaleY`, `rotation`)
- [ ] **`draw_bloc.dart`**: цвет по умолчанию — `0xFFFF8A65` (телесно-розовый)
- [ ] **`draw_action_model.dart`**: сериализация
- [ ] **`canvas_painter.dart`**: нарисовать полип кодом (округлая капля на ножке + штриховка):
  - Ножка: вертикальная линия
  - Головка: заполненный овал сверху
  - Масштабируется и разворачивается
- [ ] **`floating_toolbox.dart`**: добавить кнопку

---

## 🔵 Этап 5 — Архитектура: мультихолст

### 5.1 Новая сущность `PageData`
- [ ] **`page_data.dart`** [NEW]: создать класс `PageData` с полями: `id`, `pageType`, `title`, `backgroundPath`, `history`, `undoStack`, `redoStack`
- [ ] **`project_data.dart`**: заменить `backgroundPath + List<DrawAction>` на `List<PageData> pages` + `String patientId`

### 5.2 Рефакторинг `DrawBloc`
- [ ] **`draw_state.dart`**: добавить `int currentPageIndex`, `List<PageData> pages`; убрать отдельные `history`, `backgroundPath` (они теперь в `pages[currentPageIndex]`)
- [ ] **`draw_state.dart`**: добавить вычисляемые геттеры `currentHistory`, `currentBackground` для удобства
- [ ] **`draw_bloc.dart`**: `AddActionEvent` — работает с `pages[currentPageIndex].history`
- [ ] **`draw_bloc.dart`**: `UndoEvent`/`RedoEvent` — работают со стеками текущей страницы
- [ ] **`draw_bloc.dart`**: `SetBackgroundEvent` — устанавливает `backgroundPath` текущей страницы
- [ ] **`draw_event.dart`**: добавить `SwitchPageEvent(int index)`
- [ ] **`draw_event.dart`**: добавить `AddPageEvent({String pageType, String title})`
- [ ] **`draw_event.dart`**: добавить `RemovePageEvent(String pageId)`
- [ ] **`draw_bloc.dart`**: обработчики `SwitchPageEvent`, `AddPageEvent`, `RemovePageEvent`

### 5.3 Tab-навигация в `EditorScreen`
- [ ] **`editor_screen.dart`**: добавить горизонтальную строку табов под AppBar (список страниц проекта)
- [ ] **`editor_screen.dart`**: при создании нового проекта — создавать 2 страницы по умолчанию: «Таз» (`pelvis`) и «Матка» (`uterus`)
- [ ] **`editor_screen.dart`**: кнопка «+» в строке табов — добавляет произвольный лист
- [ ] **`editor_screen.dart`**: свайп между страницами через `PageView` / `TabBarView`
- [ ] **`canvas_widget.dart`**: проверить, что `CanvasWidget` корректно получает `backgroundPath` активной страницы
- [ ] **`canvas_painter.dart`**: проверить, что `CanvasPainter` получает `history` активной страницы

---

## 🔵 Этап 6 — Обновление сериализации `.meddraw`

- [ ] **`draw_action_model.dart`**: добавить `PageDataModel.toJson()` / `fromJson()` (сериализует `PageData` включая `history`)
- [ ] **`project_repository_impl.dart`**: обновить `saveProject` — упаковывать `pages[]` в `project.json`
- [ ] **`project_repository_impl.dart`**: обновить `loadProject` — читать `pages[]` из `project.json`
- [ ] **`project_repository_impl.dart`**: **обратная совместимость**: если в `project.json` нет поля `pages`, читать `actions` + `backgroundPath` → создать одну страницу типа `'custom'` с этими данными
- [ ] **`project_repository_web.dart`**: аналогичные изменения для Web-репозитория
- [ ] **`project_repository_web.dart`**: обратная совместимость — то же что для impl
- [ ] Написать / обновить тест в **`draw_bloc_test.dart`**: проверить `SwitchPageEvent`, `AddPageEvent`
- [ ] Написать тест: загрузка старого формата `.meddraw` (без `pages`) — должна создать 1 страницу корректно

---

## 🟢 Этап 7 — Предустановленные схемы (заглушки + TODO)

- [ ] **`pubspec.yaml`**: добавить путь `assets/schemes/` в секцию `assets`
- [ ] Создать папку `assets/schemes/` с файлами-заглушками:
  - [ ] `assets/schemes/pelvis_ls.png` — пустой placeholder (серый PNG 1x1)
  - [ ] `assets/schemes/pelvis_sagittal.png`
  - [ ] `assets/schemes/pelvis_anterior.png`
  - [ ] `assets/schemes/pelvis_ileocecal.png`
  - [ ] `assets/schemes/uterus_sagittal.png`
  - [ ] `assets/schemes/uterus_frontal.png`
  - [ ] `assets/schemes/uterus_transverse.png`
- [ ] **`editor_screen.dart`**: создать виджет `_SchemeSelector` — горизонтальная прокручиваемая панель с чипами схем
- [ ] **`editor_screen.dart`**: `_SchemeSelector` отображает схемы для текущей страницы (таз / матка / пусто для custom)
- [ ] **`editor_screen.dart`**: при нажатии на чип — устанавливает `backgroundPath` через `SetBackgroundEvent`
- [ ] **`editor_screen.dart`**: добавить `// TODO(schemes): заменить Container-заглушку на Image.asset('assets/schemes/<name>.png') после получения PNG` над каждым placeholder
- [ ] **`canvas_widget.dart`** / **`canvas_painter.dart`**: убедиться, что asset-пути (`assets/schemes/...`) корректно загружаются через `image_loader.dart` (IO + Web)
