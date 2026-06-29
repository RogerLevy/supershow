# Level Setups (Scene Setups)

Status: **design / on the table** (not yet built). A way to store multiple
"levels" in one level source file by separating shared *content* from named,
callable *configurations* — inspired by Nintendo's scene-setup tables (one base
area, many ways of loading and arranging it).

## The split

- **Base level** = the content. The layers / tile grids — one shared canvas.
  Authored in gs (the editor) exactly as today.
- **Setup** = a named, callable *framing* of that base. You "call up" a setup to
  play or view it.

## What a setup carries

- a **region** — a rectangle into the shared canvas (the "screen"/"room" this
  setup shows). This is also what the editor pans to.
- **role assignments** — which layer is hit / tread / spawn / sprite.
- **view tweaks** — per-layer visibility, parallax, offset.
- a **spawn filter** — which part of the spawn layer actually spawns (usually
  the region rect).
- optional **behavior** — a script (cutscenes, test rigs).

## Why it's useful — one mechanism, three jobs

- **multiple levels** — several region setups over one shared canvas.
- **cutscenes** — a setup that hides gameplay layers and scripts the camera.
- **test rigs** — a setup that drops you in somewhere with freemove on
  (what `me freemove` / `spispopd` in mogo were reaching for).

## Loading a setup (runtime)

1. Copy the pristine base into **one reused "active level" slot**.
2. Refill its tilemaps from JSON (re-baselines the per-layer view props).
3. Stamp the setup's config onto the active level (region/bounds, roles, view
   tweaks, spawn-rect).
4. Run its behavior script, if any.
5. Spawn tiles (now limited to the region rect) and start actors.

Only **one setup is active at a time**. No tilemap cloning, no concurrency, no
reference fixup, no heap leak (single reused slot).

### Why copy-into-a-slot is enough

There's an asymmetry in the existing flow:

- **View props self-heal.** `enter` → `load` → `refill-tilemaps` → `layer-view!`
  re-applies parallax / visx / visy / repeat / vis from JSON every load. So
  stamping them onto the (shared) tilemaps is wiped and re-baselined next enter.
- **Roles / bounds do NOT self-heal.** They're set in `on-built` at *build* time,
  never re-read by `load`. So stamping them onto the resident base would pollute
  it for the next setup.

So a **shallow copy of the level object** protects exactly the non-self-healing
fields (roles, bounds, name), while `load` keeps handling the view props on the
shared tilemaps. No pointer fixup is needed because the copied role refs keep
pointing at the shared tilemaps, which is consistent. The heavy tile-cell data
stays shared (which is the point of one base).

This is single-active by construction (shared tilemaps) — fine, because we
decided we never need two configured versions of the same base live at once.

## Spatial model: regions of one shared canvas

Multiple "levels" in a file are **rectangular regions of the same big tilemaps**,
not separate layer sets. Consequences:

- Panning between levels in gs = moving the camera within one coordinate space.
- Moving / copying tiles between levels is *free* — it's all one canvas.
- The spawn-rect filter falls out naturally (a setup's region).
- "Different tileset per level" becomes a per-layer-view tileset *reassignment*,
  not genuinely different art in the same screen-space. (Fine unless two levels
  must show different content at the same coordinates — then this model breaks.)

## Editor (gs) — two paradigms

- **standalone gs** — tile editing only; no setup awareness. (Consistent with its
  current tile-only, in-progress scope.)
- **dev-time gs** (resident alongside a loaded game) — the game's Forth is live,
  so gs can read the live `%setup` objects, draw their region rects, and rapidly
  pan between them.

Mechanism: each setup **registers itself on its base level** (`%level` gains a
`setups` list; `setup:` adds itself to its base's list — mirroring how tilemaps
register into `layers` and autoloads into `autoloads`). dev-gs walks
`the-level`'s setups to list / pan / call them up.

## Where setups are defined — dual source matching gs's two paradigms

- **content / level setups → JSON.** gs can draw, drag, and save their region
  rects; works even in standalone. (`save-level` already preserves unknown JSON
  keys, so a `setups` array survives editor saves before gs even understands it.)
- **behavior setups → Forth** (`setup:` … `setup;`). Cutscenes and test rigs;
  dev-mode only.

Both sources produce the same `%setup` object, and `enter` treats them
identically — it doesn't care which source a setup came from.

## Proposed object shape (sketch)

```
class: %setup
    prop base   :ref %level   \ the content it frames
    prop apply  :xt           \ arrangement script, run on enter
    \ + region rect, role refs, view overrides, spawn-rect (declarative fields)
class;
```

A setup is fundamentally *a small script that arranges a base level*, with a
vocabulary of declarative helper words (`bounds` / `hit` / `tread` / `spawn` /
`sprite` / `layer{…}` / `parallax` / `offset` / `spawn-rect` / `hide` / `show` /
`camto`) so simple setups read like data and complex ones drop into full Forth.

## Authoring sketch

```
mogo_01.json level mogo-base          \ the content (base)

mogo-base setup: 1-1                   \ a normal level framing
    5120 2400 bounds
    "main" hit  "main" tread  "spawns" spawn  "main" sprite
    "bg" layer { 0.66 parallax  109 0 offset }
    0 0 160 60 spawn-rect ;

mogo-base setup: intro                 \ a cutscene over the same content
    "main" hide  "bg" show
    clock off  400 200 camto  intro-controller spawn drop ;

mogo-base setup: test-jump             \ a test rig
    "main" hit
    100 100 at  %mogo spawn spispopd ;
```

Then `1-1 enter`, `intro enter`, `test-jump enter`.

## The one open question

Should gs **author** the level/region setups (so their name + rectangle live in
JSON, draggable and savable), or just **navigate / call up** setups written in
Forth (Forth-first, dev-mode only)? That choice decides whether the declarative
part needs to live in JSON.

## Touch points if/when built

- `%level` (src/level.vfx) — add `setups` list; possibly region/active-slot support.
- `enter` (sandbox/mogogame.vfx) — take a `%setup`: copy base → load → apply →
  spawn-tiles → action.
- `spawn-tiles` (sandbox/mogogame.vfx) — optional rect clip on the scan loop.
- New `%setup` class + `setup:` / `setup;` defining words + helper vocabulary.
- dev-time gs — enumerate `the-level`'s setups; pan to a setup's region.
- (if author route) JSON `setups` array + gs UI to drag/rename/save region rects.
