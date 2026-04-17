# RadioKit Skin Format — `.rkskin`

A `.rkskin` file is a **ZIP archive** containing a single file: `manifest.json`.

## Structure

```
my-skin.rkskin  (ZIP)
└── manifest.json
```

## Packaging

```bash
cd sample-rkskin/
zip ../my-skin.rkskin manifest.json
```

To install: open the RadioKit app → System tab → Import Skin, then select the `.rkskin` file.

---

## `manifest.json` Reference

### Root fields

| Field     | Type   | Description                              |
|-----------|--------|------------------------------------------|
| `name`    | string | Unique skin ID — must match the filename |
| `version` | string | Semantic version, e.g. `"1.0.0"`        |
| `author`  | string | Your name or handle                      |
| `tokens`  | object | Design token groups (see below)          |

---

### `tokens.colors`

All values must be hex strings: `"#RRGGBB"` or `"#AARRGGBB"`.

| Key          | Applies to                                                 |
|--------------|------------------------------------------------------------|
| `primary`    | Default button fill, slider track, active states           |
| `surface`    | Widget container background, slider rail                   |
| `background` | Canvas/screen background (reserved — not yet wired to UI) |
| `success`    | Buttons/LEDs with `style = success`                        |
| `warning`    | Buttons/LEDs with `style = warning`                        |
| `danger`     | Buttons/LEDs with `style = danger`                         |
| `dim`        | Buttons/LEDs with `style = dim`, slider foreground         |

---

### `tokens.typography`

| Key          | Type   | Description                                                   |
|--------------|--------|---------------------------------------------------------------|
| `fontFamily` | string | Any Google Font name — e.g. `"Inter"`, `"Roboto"`, `"VT323"` |
| `fontWeight` | string | `"400"` (normal), `"700"` (bold), `"900"` (black)             |

---

### `tokens.shapes`

| Key            | Type  | Description                               |
|----------------|-------|-------------------------------------------|
| `borderRadius` | float | Corner rounding in logical pixels         |
| `borderWidth`  | float | Border thickness; active state adds `+1`  |

---

## Built-in Skin IDs

Set `RadioKit.config.theme` in your firmware to apply one automatically:

| ID        | Description                          |
|-----------|--------------------------------------|
| `default` | Dark orange — the standard RadioKit theme |
| `retro`   | CRT green phosphor on pure black     |

Custom skins use their `name` field as the ID.
