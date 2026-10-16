# Сводка проекта tactics-rpg (для AI / разработчиков)

## 1. Общие сведения и движок
- **Движок:** Godot 4.7 (Forward Plus, рендер Windows: `d3d12`, 3D физика: `Jolt Physics`).
- **Главная сцена:** `res://menu.tscn`.
- **Живой путь игры:** `menu.tscn` → `scripts/overworld3d.gd` → `scripts/explore3d.gd` → `scripts/world3d.gd`.
  - Тактический бой, который рассчитывается: `scripts/world3d.gd`.
  - Реалтайм-бой от 1-го лица (экспериментальный тестовый режим): `scripts/explore3d.gd` + `scripts/fp_melee.gd`.
- **Autoload (синглтоны):**
  - `Game` (`scripts/game.gd`)
  - `ConHotkey` (`scripts/con_hotkey.gd`)

---

## 2. Ключевые архитектурные правила (AGENTS.md)
- `scripts/archive_unused/` не подключать к сценам, не дописывать, не переносить обратно в `scripts/`.
- Не открывать и не переписывать `data/locations.json`, `data/world_terrain.json`, `scripts/terrain.gd`, `locs_edit/`.
- Не восстанавливать код из бэкапов и не править скрипты поиском подстроки.
- Переноса на Unity нет. `docs/ARCHITECTURE.md` — сводка четырех docs. Помеченные там расхождения не схлопывать в одну правку.
- Одно задание на чат. Не резать `scripts/world3d.gd`, `scripts/overworld3d.gd`, `scripts/work3d.gd` и `scripts/constructor.gd` попутно.
- В сообщении коммита писать только тот симптом, который исчез в коде.
- Перед правкой скрипта прочитать живой путь. UI, который собирается из кода через `Button.new()`, не выносить в сцены отдельной задачей.
- Перед правкой читать `docs/COMBAT.md`, `docs/DATA.md`, `docs/EDITORS.md` и `AGENT.md`.

---

## 3. Структура проекта (Files & Folders)

```text
tactics-rpg/
├── .cursor/
│   └── rules/tactics-rpg.mdc
├── addons/
│   ├── godot_mcp/             # MCP плагин для инспекции и автоматизации
│   └── loc_bridge/            # Внутренний редакторский плагин моста локаций
├── art/                       # 2D спрайты, портреты, текстуры и 3D модели (.fbx/.obj)
├── data/
│   ├── chars.json             # Характеристики и описания персонажей
│   ├── classes.json           # Классы бойцов
│   ├── config.json            # Базовые параметры
│   ├── groups.json            # Группы врагов
│   ├── items.json             # Предметы и экипировка
│   ├── locations.json         # Локации (НЕ ТРОГАТЬ)
│   ├── loc_catalog.json
│   ├── loc_types.json
│   ├── materials.json
│   ├── objects.json
│   ├── perks.json
│   ├── quests.json
│   ├── world_decor.json
│   ├── world_lights.json
│   ├── world_sun.json
│   ├── world_terrain.json     # Террейн (НЕ ТРОГАТЬ)
│   ├── dialogs/               # JSON файлы диалогов
│   └── maps/                  # Карты
├── docs/
│   ├── ARCHITECTURE.md        # Сводка архитектуры
│   ├── COMBAT.md              # Правила тактического боя
│   ├── DATA.md                # Схемы данных
│   ├── EDITORS.md             # Инструкции к редакторам
│   └── PROJECT.md
├── scenes/
│   └── CloudBorder.tscn
├── scripts/
│   ├── airship.gd             # Управление дирижаблем
│   ├── camp_ui.gd             # Интерфейс привала
│   ├── cliff_bridge.gd        # Мосты и расчет высот
│   ├── con_hotkey.gd          # Автолод горячих клавиш (F3, F6, C)
│   ├── config_tools.gd
│   ├── constructor.gd         # Редактор-конструктор
│   ├── data_loader.gd
│   ├── day_night.gd           # Суточный цикл освещения
│   ├── dialog.gd              # Рендер диалогов
│   ├── dialog_editor.gd
│   ├── dialog_scheme.gd
│   ├── explore3d.gd           # Исследование 3D и реалтайм-бой
│   ├── explore_tools.gd
│   ├── fog_border.gd
│   ├── fp_melee.gd            # Оружие от 1-го лица (удары, блок, парирование)
│   ├── game.gd                # Автолод состояния игры
│   ├── game_hub.gd            # Окно хаба (I)
│   ├── global_map_editor.gd
│   ├── graphics_settings.gd
│   ├── journal.gd             # Журнал заданий
│   ├── loc_editor.gd
│   ├── loc_grid.gd
│   ├── locspace.gd
│   ├── map_canvas.gd
│   ├── menu.gd                # Главное меню (включая Тест Боя)
│   ├── overworld3d.gd         # Глобальная карта 3D
│   ├── party_tools.gd
│   ├── party_ui.gd
│   ├── preview.gd
│   ├── prologue_2d.gd         # 2D пролог
│   ├── quest_editor.gd
│   ├── shop.gd                # Лавка торговца
│   ├── stats_tools.gd
│   ├── tavern.gd              # Таверна
│   ├── terrain.gd             # (НЕ ТРОГАТЬ)
│   ├── work3d.gd              # 3D мастерская
│   ├── world3d.gd             # Пошаговый тактический бой
│   └── archive_unused/        # (НЕ ИСПОЛЬЗОВАТЬ)
├── shaders/
│   ├── sprite_ambient_lighting.gdshader
│   └── tree_ambient_lighting.gdshader
├── AGENTS.md
├── AI_CONTEXT.md
├── export_presets.cfg
├── menu.tscn
├── overworld3d.tscn
├── explore3d.tscn
├── world3d.tscn
├── work3d.tscn
├── constructor.tscn
├── locspace.tscn
├── project.godot
└── README.md
```

---

## 4. Содержимое project.godot
```ini
config_version=5

[application]
config/name="Пошаговый бой 8 (пересбор структуры2)"
run/main_scene="res://menu.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]
Game="*res://scripts/game.gd"
ConHotkey="*res://scripts/con_hotkey.gd"

[display]
window/subwindows/embed_subwindows=false
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[editor_plugins]
enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg", "res://addons/loc_bridge/plugin.cfg")

[physics]
3d/physics_engine="Jolt Physics"

[rendering]
rendering_device/driver.windows="d3d12"
```

---

## 5. Текущий статус проекта (Релиз v0.7.0 — Тест боя)
- **Ошибки компиляции / парсера:** 0 (проект чисто компилируется и стартует в Godot 4.7 без красных ошибок).
- **Экспериментальный реалтайм-бой:**
  - Вход: меню → вкладка «ТЕСТ БОЯ» (спавн на `bandit_road`).
  - Клавиши отладки: `[1]` Спавн, `[2]` Бессмертие героя, `[3]` Бессмертие врагов, `[4]` 100% HP, `[5]` Очистить врагов, `[F1]` Скрыть HUD.
  - Бой: ЛКМ — быстрый / сильный удар, ПКМ — блок и активное парирование (со шкалой тайминга), `F` — пинок ноги (стан и сбивание щита), `[Alt]`/`[Q]`/`[C]` — рывок с кадрами неуязвимости (i-frames).
