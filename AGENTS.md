# Zasady Pracy Agentów w Repozytorium TrainWreck (AGENTS.md)

## 1. Bezwzględny Zakaz Analizy i Zapamiętywania Grafik (CRITICAL)

Agenci pracujący w tym repozytorium **POD ŻADNYM POZOREM** nie mogą oglądać, analizować wizualnie ani zapamiętywać wyglądu jakichkolwiek plików graficznych.

- **ZAKAZ ODCZYTU OBRAZÓW:** Nigdy nie wywołuj `read_file` ani narzędzi wizyjnych/przeglądarkowych na plikach graficznych (`.png`, `.jpg`, `.jpeg`, `.webp`, `.svg`, `.bmp`, `.tga`, `.gif`, `.dds`, `.ktx`, `.exr`, `.hdr`, `.aseprite`, `.psd`, `.ctex`, `.stex`).
- **ZAKAZ ANALIZY ZAWARTOŚCI:** Nigdy nie uruchamiaj skryptów ani poleceń próbujących analizować piksele, kolory, kształty lub zawartość wizualną grafik. Nie zlecaj tego również subagentom.
- **ZAKAZ ZAPAMIĘTYWANIA:** Nigdy nie opisuj ani nie zapisuj informacji o wyglądzie grafik w kontekście rozmowy, artefaktach (`brain/`), plikach reguł, komentarzach w kodzie czy wiadomościach commitów.
- **ZARZĄDZANIE WYŁĄCZNIE JAKO ASSETAMI:** Pliki graficzne traktuj wyłącznie jako nieprzezroczyste zasoby plikowe (zarządzanie ścieżkami, nazwami plików, katalogami `Final Assets/`, `Placeholders/`, `Test/Assets/`, plikami `.import` oraz referencjami `res://` i `uid://` w plikach `.tscn`, `.tres`, `.gd`).
- **OBOWIĄZKOWY SKILL:** Przy każdym zadaniu dotykającym plików graficznych, tekstur, sprite'ów, UI, tilesetów lub plików `.import`, **obowiązkowo aktywuj i stosuj skill `asset-management`** (`.agents/skills/asset-management/SKILL.md`). W razie braku informacji technicznych (np. wymiarów klatki spritesheetu lub liczby klatek) w plikach tekstowych — zapytaj użytkownika.
