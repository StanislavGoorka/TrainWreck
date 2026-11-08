---
name: asset-management
description: >-
  Mandatory protocol for handling graphic files and visual assets in the TrainWreck repository.
  Activate this skill whenever a task involves graphic files, sprites, textures, icons, UI elements,
  tilesets, backgrounds, Godot .import files, or asset directories (Final Assets, Placeholders, Test/Assets).
  Enforces a strict ban on viewing, analyzing, or memorizing the visual content of any graphic.
---

# Asset Management Protocol (No Visual Analysis / No Memorization)

> [!CAUTION]
> **BEZWZGLĘDNY ZAKAZ ANALIZY WIZUALNEJ I ZAPAMIĘTYWANIA GRAFIK**
> Agenci pracujący w tym repozytorium **POD ŻADNYM POZOREM** nie mogą oglądać, analizować zawartości wizualnej ani zapamiętywać wyglądu jakichkolwiek plików graficznych. Pliki graficzne wolno traktować **wyłącznie jako nieprzezroczyste zasoby plikowe (assety)**.

## 1. Bezwzględne Zakazy (Zero Visual Inspection & Zero Memorization)

1. **Zakaz odczytu wizualnego (`read_file` / Vision):**
   - **NIGDY** nie używaj narzędzia `read_file` (ani żadnego innego narzędzia podglądu obrazu/wideo/przeglądarki) bezpośrednio na plikach graficznych: `.png`, `.jpg`, `.jpeg`, `.webp`, `.svg`, `.bmp`, `.tga`, `.gif`, `.dds`, `.ktx`, `.exr`, `.hdr`, `.aseprite`, `.psd`, ani na skompilowanych teksturach Godota w `.godot/imported/` (`.ctex`, `.stex`).
2. **Zakaz analizy zawartości obrazu:**
   - **NIGDY** nie uruchamiaj skryptów ani poleceń próbujących analizować piksele, kolory, kształty, postacie czy wygląd grafik (np. OCR, detekcja obiektów, próbkowanie kolorów, konwersja obrazu do ASCII/base64 w celu obejrzenia).
3. **Zakaz zapamiętywania i opisywania wyglądu:**
   - **NIGDY** nie zapisuj, nie podsumowuj ani nie przechowuj informacji o wyglądzie grafik w:
     - pamięci konwersacji / kontekście agenta,
     - artefaktach (`brain/<id>/`), plikach `GEMINI.md` / `AGENTS.md`,
     - komentarzach w kodzie (`.gd`, `.tscn`, `.tres`, `.gdshader`),
     - opisach commitów i wiadomościach do subagentów.
4. **Zakaz delegowania podglądu:**
   - **NIGDY** nie zlecaj subagentom (`research`, `self` itp.) otwierania ani analizowania zawartości plików graficznych.

---

## 2. Dozwolone Operacje (Zarządzanie Plikami jako Assetami)

Agenci mogą zarządzać grafikami **wyłącznie na poziomie systemu plików oraz metadanych silnika Godot**, traktując sam obraz jako czarną skrzynkę (opaque asset):

1. **Operacje na plikach i katalogach:**
   - Listowanie plików po nazwach, ścieżkach i rozszerzeniach (np. `Get-ChildItem`, `git status`) w katalogach takich jak `Final Assets/`, `Placeholders/`, `Test/Assets/`.
   - Przenoszenie, zmiana nazw, kopiowanie i usuwanie plików assetów zgodnie z poleceniami użytkownika lub strukturą projektu.
2. **Zarządzanie plikami `.import` w Godot 4:**
   - Odczyt i edycja tekstowych plików `.import` (np. `plik.png.import`) w celu sprawdzenia identyfikatora `uid://...`, ścieżek `remap` lub parametrów importu (kompresja, filtrowanie tekstur, mipmapy).
   - **Zasada spójności Godot UID:** Przy każdym przenoszeniu lub zmianie nazwy pliku graficznego **zawsze** przenoś/zmieniaj nazwę odpowiadającego mu pliku `.import` razem z nim (lub zaktualizuj referencje `res://`), aby nie uszkodzić powiązań `uid://` w scenach i zasobach.
3. **Podpinanie assetów w scenach i skryptach (`.tscn`, `.tres`, `.gd`):**
   - Operowanie na referencjach `ExtResource` (`path="res://..."`, `uid="uid://..."`) w plikach tekstowych scen (`.tscn`), zasobów (`.tres`, np. `SpriteFrames`, `AtlasTexture`, `TileSet`, `Theme`) oraz skryptów GDScript (`.gd`).
   - Tworzenie i modyfikowanie węzłów `Sprite2D`, `AnimatedSprite2D`, `TextureRect`, `NinePatchRect` czy `TileMapLayer` wyłącznie na podstawie nazw plików, ścieżek i wytycznych od użytkownika.

---

## 3. Procedura Postępowania w Sytuacjach Niejednoznacznych

Jeżeli wykonanie zadania wymaga informacji wynikających z zawartości grafiki (np. liczba klatek na arkuszu spritesheet, układ wierszy/kolumn animacji, rozmiar pojedynczej klatki, punkt obrotu/pivot lub dopasowanie kolizji `CollisionShape2D` do kształtu sprite'a):

1. **NIE otwieraj pliku graficznego.**
2. Sprawdź, czy informacja nie znajduje się już w istniejących plikach tekstowych (`.tscn`, `.tres`, `.gd`, `.import`).
3. Jeśli informacji nie ma w plikach tekstowych — **zapytaj użytkownika** o dokładne parametry techniczne (np. wymiary klatki w pikselach, liczbę klatek animacji lub docelową nazwę pliku).
