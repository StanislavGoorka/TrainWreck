# Testy automatyczne (GdUnit4)

Testy są napisane w [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) v6.2.3 (`addons/gdUnit4`) i uruchamiane na Godot 4.7.2.
Na GitHubie odpalają się przy każdym pushu i pull requeście (`.github/workflows/tests.yml`). Wynik widać jako check „Tests”, a raport HTML/XML jest do pobrania jako artefakt.

## Struktura

| Katalog | Co testuje |
|---|---|
| `unit/resources` | `StatusEffect`, `ItemData` (ikony, opisy statystyk), `DialogueData`, domyślne wartości statystyk |
| `unit/player` | `Player` (przedmioty, statystyki, obrażenia, pickupy), stany Idle/Move/Dash, stany broni i odrzut |
| `unit/enemy` | `Enemy`, `StatusComponent` (burn/poison/freeze/bleed), AI walkera, latający wróg, boss (SpinBossChase/SpinAttack), boss Summoner (okno podatności, limit obrażeń, fale, stany) |
| `unit/state_machine` | `StateMachine` i `State` |
| `unit/game_state` | progresja, odblokowywanie postaci, zapis/odczyt, koniec runu, piętra, zegar runu |
| `unit/audio`, `unit/settings` | `Audio` (głośności, crossfade, SFX), `GameSettings`, panel i overlay ustawień |
| `unit/ui` | HUD (serca, statystyki, waluta, wspólny zegar runu, piętro, przytrzymanie Tab, przedmioty, popup, pasek bossa), dialogi, prompt interakcji, Game Over, ekran zwycięstwa, menu-książka, wybór postaci, credits (dane, przewijanie, pomijanie), asynchroniczny loader scen (sukces, błąd, ponowienie, blokada kolejnych żądań) |
| `unit/interactables` | `Interactable`, `NPC`, `CharacterStation`, `TrainDoor`, `Portal` |
| `unit/world` | pickupy, piedestały, pociski, pokoje i pokój bossa (także zwycięstwo na ostatnim piętrze), generator poziomu i przejścia między piętrami, kamera |
| `integration` | integralność projektu (kompilacja, sceny, zasoby, ścieżki `res://`, sygnały, akcje wejścia, autoloady), dane `.tres`, testy dymne prawdziwych scen |
| `helpers` | klasa bazowa, fabryka fixture'ów, dublery testowe |

## Uruchamianie lokalnie

**Z edytora:** plugin GdUnit4 jest włączony. Prawy klik na folder `tests` w FileSystem i wybierz *Run Tests* (albo użyj panelu GdUnit).

**Z linii poleceń (Windows):**

```
addons\gdUnit4\runtest.cmd --godot_binary "C:\...\Godot_v4.7.2-stable_win64_console.exe" -a res://tests -c
```

Na Linux/macOS użyj `addons/gdUnit4/runtest.sh`. `-c` uruchamia wszystkie suity zamiast zatrzymać się na pierwszym błędzie. Raport trafia do `reports/` (katalog jest w `.gitignore`).
Przekierowanie wyjścia do pliku (`> wynik.txt 2>&1`) wyraźnie przyspiesza przebieg, bo TileSety pokoi i huba wypisują tysiące błędów (patrz znane bugi).

Testy nie ruszają Twojego zapisu: `user://save.json` i `user://settings.cfg` są odkładane przed suitą i przywracane po niej.

Po pobraniu zmian przenoszących skrypty uruchom najpierw Godota z `--headless --editor --import`, aby odświeżyć cache klas i UID. Bez tego lokalny cache może nadal wskazywać usunięte ścieżki.

Przebieg bez okna uruchom bezpośrednio przez Godota:

```
"C:\...\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c --ignoreHeadlessMode
```

`--ignoreHeadlessMode` pozwala GdUnit4 działać bez okna. Testy wejścia używają `Input.action_press()` lub bezpośredniego przekazania zdarzenia, nie symulacji urządzeń.

W środowisku z ograniczeniami zapisu można odizolować dane użytkownika dla procesu Godota: przed uruchomieniem ustaw w PowerShell `$env:APPDATA = Join-Path (Get-Location).Path 'reports\isolated-user-data'` i utwórz ten katalog. Zapis gry i ustawienia testów trafią wtedy pod `reports/`, poza rzeczywistym profilem gracza.

## Zasady pisania testów

- Każda suita dziedziczy z `res://tests/helpers/tw_test_suite.gd`. Klasa bazowa przed każdym testem robi snapshot `GameState` (także piętra i zegar runu), `Audio`, głośności szyn, `SceneLoader.busy` i `current_scene`, a po teście je przywraca, zwalnia akcje wejścia i wyłącza pauzę. Nadpisując hooki, wołaj `super.before_test()` / `await super.after_test()`.
- Fixture'y buduj przez `Factory` (`helpers/factory.gd`). Tekstury to `PlaceholderTexture2D`, więc testy nie otwierają plików graficznych (zasady z `AGENTS.md`).
- Nie wywołuj metod zmieniających scenę (`GameState.start_run/go_to_hub/go_to_menu`, przyciski, które je wołają): podmieniłyby scenę runnera testów. Do `go_to_hub` użyj `helpers/game_state_double.gd`.
- Wyjątek: `scene_loader_test` ustawia tymczasową scenę przez `use_as_current_scene()`, ładuje prostą scenę z `tests/fixtures/` i usuwa ją po teście. Sprząta też zadania błędnego ładowania w globalnym cache `ResourceLoader`. Dzięki temu sprawdza prawdziwe ładowanie asynchroniczne, zachowując runner. Testy wyjścia z credits ustawiają `SceneLoader.busy`, aby wykonać prawdziwą obsługę wyjścia bez zamiany sceny.
- Tweeny przesuwaj ręcznie `tween.custom_step(czas)`. W trybie headless jedna klatka potrafi trwać dłużej niż cała animacja. Callback na końcu tweena wykona się dopiero w kroku, w którym zostaje nadwyżka czasu (`czas + 0.01`).
- Timery ręczne kroku z krokiem `0.125` (dokładnym w binarnym float), a nie `0.1`.
- Sceny hub i pokoi ładuj przez `load_pinned(...)`, żeby wczytywały się raz na cały przebieg.
- Jeśli test wciska akcję (`Input.action_press`), klasa bazowa ją zwolni i odczeka klatkę, bo `is_action_just_pressed` zostaje `true` do końca klatki.

## Znane bugi

Po przywróceniu skanowania `testing_room.tscn` aktywny test `test_scene_signal_connections_reach_existing_methods` wykrywa dwa połączenia `EnemyArea.body_entered/body_exited` do nieistniejących metod `_on_enemy_area_body_entered/_on_enemy_area_body_exited`. Zależności tej sceny są już poprawne, więc scena nie jest wykluczana z kontroli. Błąd sygnałów pozostaje raportowany przez test.

Pozostałe, wcześniej zarejestrowane bugi mają pominięte testy (`do_skip := true` z opisem `KNOWN BUG` w `skip_reason`). Ich lista jest poniżej. Nowo wykryte problemy pozostają aktywnymi niepowodzeniami; aktualizacja testów nie dodaje nowych pominięć.
Po naprawieniu buga usuń `do_skip`/`skip_reason` z testu (a dla skanów integralności także wpis z tabeli `KNOWN_*`), żeby test pilnował poprawki.

| Bug | Test |
|---|---|
| `character.gd`: `dash_distance_add` doliczane dwa razy | `player_test` › `test_dash_distance_bonus_is_applied_once` |
| `start_dash_cooldown()` czyta nieistniejące `dash_cooldown`, dash nie ma cooldownu | `player_test` › `test_start_dash_cooldown_uses_the_character_stats` |
| `GameState.CHARACTER_FOLDER` wskazuje folder bez postaci | `game_state_test` › `test_characters_folder_contains_character_definitions` |
| `SlingerStats.tres` ma stare nazwy pól (statystyki ignorowane) | `resource_data_test` › `test_known_stale_resources_are_fixed` |
| Gracz: `DashTimer` → nieistniejące `_on_dash_timer_timeout` | `project_integrity_test` › `test_known_bad_connections_are_fixed` |
| `enemy_shoot.gd` preloaduje usuniętą scenę | `project_integrity_test` › `test_known_broken_scripts_compile` |
| TileSet huba ma kafle poza atlasem (tysiące błędów przy ładowaniu) | `project_integrity_test` › `test_hub_tileset_fits_inside_its_texture` |
| Stany walkera grają `idle`/`run`/`attack`, a sceny mają `Idle`/`Chase`/`Attack` | `scenes_test` › `test_walker_state_animations_exist` |
| Boss prosi o `idle`/`run`/`spin`, a ma `Idle`/`Chase`/`SpinAttack` | `scenes_test` › `test_spin_boss_animations_exist` |
| Stany Summonera proszą o `idle`/`summon`, a `boris.tscn` ma `Idle`/`Summon`/`Vulnerable` | `scenes_test` › `test_summoner_boss_animations_exist` |
| `SummonerBoss.spawn_wave()` nie zwalnia instancji z `enemy_pool`, która nie jest `Enemy` (wyciek węzłów) | `summoner_boss_test` › `test_pool_entries_that_are_not_enemies_are_skipped_without_leaking` |
| `Dash.gd` gra `Dash`, a Body ma `Roll` | `scenes_test` › `test_player_body_has_a_dash_animation` |
| `boss_01.tscn` i `boss_02.tscn` nie dają nagrody przed ostatnim piętrem (`reward_pedestal_scene = null`) | `scenes_test` › `test_boss_rooms_reward_the_player` |
| `room.gd:86` woła `_on_enemies_spawned()` raz na każdego wroga | `room_test` › `test_room_hook_receives_all_spawned_enemies_once` |
| `InventorySpread` gubi węzły ukrytych stron (wyciek) | `book_menu_test` › `test_freeing_the_inventory_frees_hidden_pages` |
| Godot 4.7: prompt pokazuje `[E - Physical]` zamiast `[E]` | `dialogue_and_prompts_test` › `test_key_name_is_the_bare_key_of_the_interact_binding` |
