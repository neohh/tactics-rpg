# Агент: tactics-rpg

Godot 4.7. Вход: `res://menu.tscn`. Имя в `project.godot`: «Пошаговый бой 8 (пересбор структуры2)».

Этот файл — куда смотреть. Формулы боя, формат сейва и устройство редакторов здесь не пересказаны.

- Бой: [docs/COMBAT.md](docs/COMBAT.md)
- Сейв, флаги, диалоги, квесты: [docs/DATA.md](docs/DATA.md)
- Редакторы: [docs/EDITORS.md](docs/EDITORS.md)
- Карта сцен и пути: [docs/PROJECT.md](docs/PROJECT.md)
- Сводка устройства и расхождения документов: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Живой путь

`menu.tscn` → `scripts/overworld3d.gd` → `scripts/explore3d.gd` → `scripts/world3d.gd`.

Бой, который реально считается, находится в `scripts/world3d.gd`. Сцена боя — `world3d.tscn`.

| Сцена | Скрипт | Роль |
|---|---|---|
| `menu.tscn` | `scripts/menu.gd` | Старт. «ИГРАТЬ», «КОНСТРУКТОР», «3D ТЕСТ», «ТЕСТ ЛЕСТН». |
| `overworld3d.tscn` | `scripts/overworld3d.gd` | Глобальная карта. Тот же файл при `Game.edit_world` строит редактор карты. |
| `explore3d.tscn` | `scripts/explore3d.gd` | Ходьба, подбор, случайная встреча, старт боя. |
| `world3d.tscn` | `scripts/world3d.gd` | Пошаговый бой. Сюда же «3D ТЕСТ», «ТЕСТ ЛЕСТН» и «В БОЙ» редактора локации. |
| `work3d.tscn` | `scripts/work3d.gd` | Мастерская локации. Открывает `ConHotkey.show_work()`. |
| `constructor.tscn` | `scripts/constructor.gd` | Полный экран конструктора. Кнопка меню и `C` эту сцену не грузят: окно создаёт тот же скрипт. Сцена — запасной возврат из `locspace.tscn`, если `Game.return_scene` пуст. |
| `locspace.tscn` | `scripts/locspace.gd` | Полноэкранная мастерская локаций, внутри `loc_editor.gd`. |

Окна хаба, отряда, привала, таверны, лавки, журнала и диалога своих `.tscn` не имеют. Их создают скрипты и вешают на текущую сцену.

`change_scene_to_file` в `.gd` вызывают только: `menu.gd`, `overworld3d.gd`, `explore3d.gd`, `world3d.gd`, `game_hub.gd`, `con_hotkey.gd`, `constructor.gd`, `locspace.gd`, `loc_editor.gd`, `global_map_editor.gd`. Других вызовов нет. Кто куда и когда — таблица в [docs/PROJECT.md](docs/PROJECT.md). Про `locspace` два документа говорят по-разному: см. расхождение в [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Autoload

Только два.

- `Game` — `scripts/game.gd`. Живёт всё время. Группа `live`. В `_ready` читает `data/quests.json` и `data/chars.json`. Партия, квесты, флаги, сейв, переход между режимами.
- `ConHotkey` — `scripts/con_hotkey.gd`. Подпись «РЕЖИМ: …» по имени сцены: `World3D` → «БОЙ», `Work3D` → «МАСТЕРСКАЯ», `Overworld3D` → «КАРТА», иначе «МЕНЮ». `Explore3D` поэтому тоже «МЕНЮ». Клавиша `C` открывает или прячет окно «Конструктор». `show_work()` грузит `work3d.tscn`.

## Какие скрипты трогать

Живая игра: `game.gd`, `con_hotkey.gd`, `menu.gd`, `overworld3d.gd`, `explore3d.gd`, `world3d.gd`, `dialog.gd`, `game_hub.gd`, `party_ui.gd`, `camp_ui.gd`, `tavern.gd`, `shop.gd`, `journal.gd`, `party_tools.gd`, `stats_tools.gd`, `explore_tools.gd`, `config_tools.gd`, `data_loader.gd`.

Редакторы: `constructor.gd`, `work3d.gd`, `locspace.gd`, `loc_editor.gd`, `global_map_editor.gd`, `map_canvas.gd`, `quest_editor.gd`, `dialog_editor.gd`, `dialog_scheme.gd`, `preview.gd`. `loc_grid.gd` ни одна сцена и ни один скрипт не создают. `addons/loc_bridge/loc_bridge.gd` — плагин редактора Godot, в игровые сцены не входит.

Одно задание на чат. Не резать попутно `scripts/world3d.gd`, `scripts/overworld3d.gd`, `scripts/work3d.gd` и `scripts/constructor.gd`. Перед правкой скрипта прочитать живой путь. UI, который собирается из кода через `Button.new()`, не выносить в сцены отдельной задачей.

Не подключать к сценам, не дописывать и не переносить обратно в `scripts/` каталог `scripts/archive_unused/`. К семи сценам эти файлы не привязаны: `battle_ai.gd`, `battle_coordinator.gd`, `battle_state_manager.gd`, `unit_manager.gd`, `battle_ui.gd`, `action_resolver.gd`.

Не открывать и не переписывать `data/locations.json`, `data/world_terrain.json`, `scripts/terrain.gd`, `locs_edit/`. Не восстанавливать код из бэкапов и не править скрипты поиском подстроки.

`scripts/terrain.gd` создают `explore3d.gd`, `world3d.gd`, `overworld3d.gd`, `work3d.gd` и `loc_grid.gd`. Файл не открывался, роль внутри не описана.

## Куда смотреть за боем

Сцена `world3d.tscn`, скрипт `scripts/world3d.gd`.

Число активаций, производные статы и опыт — `scripts/stats_tools.gd`. Константы — `scripts/config_tools.gd` из `data/config.json`. База классов — `data/classes.json`. Перки и предметы в производных — `data/perks.json`, `data/items.json`.

Вход в бой решает `Game.explore_start`, его пишет `explore3d.gd`. Возврат — `Game.explore_return` и `Game.explore_ground`. Случайная встреча — `Game.enc`: исследование забирает её раньше, ветка `enc` внутри `world3d.gd` выполняется только при заходе не из исследования.

Спецификация: [docs/COMBAT.md](docs/COMBAT.md).

## Куда смотреть за сейвом

`Game.save_game` / `Game.load_game` в `scripts/game.gd`. Файл слота пишет и читает `scripts/data_loader.gd`. Слоты `user://save_0.json` … `user://save_9.json`. Клавиша `G` и автосейв — слот 0. Хаб — номер кнопки. Клавиша `L` — самый свежий слот.

В слот входят `day`, `hour`, `cur_loc`, `gold`, `food`, `fatigue`, `inventory`, `quests`, `flags`, `party`, `party_pool`, `loc_state`. Переходные поля и редактор в слот не входят. `load_game` их не очищает.

Конфиг читает `config_tools.gd` своим `FileAccess`, не через `DataLoader`. Для партии, земли, респавна и автосейва важны `party_max`, `ground_ttl_days`, `respawn_days`, `autosave`, `defeat_mode`.

Спецификация: [docs/DATA.md](docs/DATA.md).

## Куда смотреть за редакторами

Окно конструктора — `ConHotkey.open()` по `C` и по кнопке меню. Узел `scripts/constructor.gd`, `embedded = true`. Сцена игры при этом не меняется. `constructor.tscn` с меню и с `C` не открывается.

Вкладки `CATS` в `constructor.gd`. Локация (`locs`, `catalog`) уводит игру в `work3d.tscn` и оставляет окно конструктора. Карта мира: `global_map_editor.gd` и `map_canvas.gd`; «→ в 3D» ставит `Game.edit_world` и грузит `overworld3d.tscn`. «В БОЙ» в `loc_editor.gd` пишет `Game.cur_loc` и грузит `world3d.tscn`.

Редакторское состояние лежит в `Game.editor` и снаружи видно как `edit_loc`, `edit_active`, `edit_data`, `edit_tool`, `edit_what`, `edit_obj`, `edit_cls`, `edit_world`, `return_scene`. В сейв не пишется. `clear_transient_state()` его не сбрасывает.

Спецификация: [docs/EDITORS.md](docs/EDITORS.md).

## Переходные поля Game

Сбрасывает `clear_transient_state()`: `explore_start`, `explore_return`, `explore_ground`, `enc`, `battle_snap`.

Кто вызывает очистку: меню «ИГРАТЬ» и «3D ТЕСТ»; `M` на карте и в исследовании; хаб при уходе на карту или в меню; поражение и уход из боя без возврата в исследование; кнопка «На глобальную карту».

Кто пишет `battle_snap`, [docs/PROJECT.md](docs/PROJECT.md) и [docs/DATA.md](docs/DATA.md) описывают по-разному. Оба утверждения — в [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
