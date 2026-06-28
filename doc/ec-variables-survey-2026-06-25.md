# EC Variables Survey
_2026-06-25_

Survey of all `ec-cell` declarations in Supershow and how their state is preserved.

---

## Variables

### `allegro5/graphics.vfx`

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `ppenr` | fixed | `rgba`, `rgba8` | pen color red |
| `ppeng` | fixed | `rgba`, `rgba8` | pen color green |
| `ppenb` | fixed | `rgba`, `rgba8` | pen color blue |
| `ppena` | fixed | `rgba`, `rgba8` | pen color alpha |
| `ppenx` | fixed | `at`, `atp`, `+at`, `+atp`, `<at` | pen X position |
| `ppeny` | fixed | `at`, `atp`, `+at`, `+atp`, `<at` | pen Y position |

Defaults: `1. 1. 1. 1. rgba` at module load.

### `addons/shapes.vfx`

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `thickness` | fixed | `thick` | outline width for `circ`, `rect`, `line`, `oval` |
| `ppenu` | fixed | `uv` | texture U coord for `texrectf`, `poly` |
| `ppenv` | fixed | `uv` | texture V coord for `texrectf`, `poly` |

Default: `0.5 thickness!` at module load.

### `allegro5/vga13h.vfx`

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `pal` | addr | `pal!` | active VGA palette array for `color` |

Default: `vga13h pal!`.

### `src/tileset.vfx` (used also in `src/tilecol.vfx`)

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `pile` | int | `pile!` | tileset base ID for `meta` tile index lookups |

### `src/level.vfx`

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `scrollx` | fixed | `scrollx!` | camera X scroll offset |
| `scrolly` | fixed | `scrolly!` | camera Y scroll offset |

---

## Save/Restore Mechanisms

### 1. `e{` / `e}` — full EC snapshot (the mechanism actually in use)

Copies the entire current EC into a temp slot from a ring buffer (`tcs`, 4096 bytes,
16 slots of 256 bytes each). Changes made inside the scope are **discarded on exit**.

Used by:

- `engineer/go.vfx` — `process-tick` wraps `draw-game` in `e{ ... e}`. This is the
  frame-level safety net: any EC mutation during a frame's draw phase is undone before
  the next frame.
- `allegro5/graphics.vfx` — `cls` saves EC to change color for the clear, then restores.
- `allegro5/graphics.vfx` — `clip{` / `clip}` saves pen + color across stencil setup.
- `src/border.vfx` — saves EC for a temporary color change.

### 2. `VAR>` savers — single-field save onto return stack (defined, never used)

`ec-cell` generates an immediate word `VAR>` (e.g. `ppenr>`, `scrollx>`) that saves the
field's value on the return stack and restores it when the enclosing word returns, via
`ec-save` / `ec-restore`. The mechanism compiles correctly but **no word in the codebase
calls any of these savers**. Dead infrastructure.

### 3. Direct overwrite — no save/restore (the common case)

Most callers (`rgba8`, `at`, `scrollx!`, `pile!`, etc.) write EC fields directly without
saving. State persists until the next write. The `e{`/`e}` around `process-tick` is the
only systematic guard — everything within a frame can mutate freely and the snapshot
undoes it at frame end.

---

## Summary

EC save/restore in practice is almost entirely handled by the `e{`/`e}` wrapper on
`process-tick`. Per-variable savers (`VAR>`) exist but are unused. Most EC writes are
fire-and-forget, relying on frame-boundary restoration.
