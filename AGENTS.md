# tactics-rpg

Движок Godot 4.7. Вход: `res://menu.tscn`.

Живой путь: `menu.tscn` → `scripts/overworld3d.gd` → `scripts/explore3d.gd` → `scripts/world3d.gd`. Бой, который реально считается, находится в `scripts/world3d.gd`.

Autoload только `Game` (`scripts/game.gd`) и `ConHotkey` (`scripts/con_hotkey.gd`).

## Запреты

- `scripts/archive_unused/` не подключать к сценам, не дописывать, не переносить обратно в `scripts/`.
- Не открывать и не переписывать `data/locations.json`, `data/world_terrain.json`, `scripts/terrain.gd`, `locs_edit/`.
- Не восстанавливать код из бэкапов и не править скрипты поиском подстроки.
- Переноса на Unity нет. `docs/ARCHITECTURE.md` — сводка четырёх docs. Помеченные там расхождения не схлопывать в одну правку.
- Одно задание на чат. Не резать `scripts/world3d.gd`, `scripts/overworld3d.gd`, `scripts/work3d.gd` и `scripts/constructor.gd` попутно.
- В сообщении коммита писать только тот симптом, который исчез в коде.
- Перед правкой скрипта прочитать живой путь. UI, который собирается из кода через `Button.new()`, не выносить в сцены отдельной задачей.

Перед правкой читать `docs/COMBAT.md`, `docs/DATA.md`, `docs/EDITORS.md` и `AGENT.md`.
