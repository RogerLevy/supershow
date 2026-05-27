# Audio Plugin System — Design Notes

## Core Idea

Audio engines are pluggable modules. Including an engine module is the act of
registering it — top-level code at load time hooks it into the plugin system,
claims a bus, and sets up any init/update hooks. No explicit wiring call needed
from game code.

```forth
include %supershow%/audio/waveplay.vfx   \ loads, registers, hooks itself in
```

## Layering

```
Game code
    ↓  named sounds / sound events
Bus system  (gain, mute, routing)
    ↓  sound instances
Engine plugins  (waveplay, MOD, synth, ...)
    ↓
Allegro 5 / OS audio
```

## Engines

Each engine is a module that:
- Self-registers into the plugin system at include time
- Exposes its own words directly (`waveplay/gain`, `waveplay/sound`, etc.)
- Also hooks into the abstract plugin API (`gain`, `sound`, etc.)
- Implements an engine protocol: `init`, `update`, `destroy`, `play`, `stop`,
  `set-gain`, `mute`, `unmute`

Multiple engines can be loaded and active simultaneously. "Switching" is just
routing policy — mute all but one. No separate mechanism needed.

## Busses

A bus is a named mix point with gain, mute state, and routing to a parent bus.
Busses form a tree rooted at master:

```
master
├── sfx
│   ├── ui
│   └── world
├── music
└── voice
```

Each engine is wired to one or more busses at load/init time. The abstract words
(`gain`, `hush`, etc.) operate on whatever bus is currently bound in the
execution context.

## Call Styles

Two legitimate styles coexist:

```forth
\ Module that knows its engine — calls directly, no dispatch
waveplay/gain

\ Generic code — talks to whatever is currently bound
gain
```

The abstract words are deferred/vectored to the bound engine's implementation.
No overhead for code that bypasses them.

## Context Binding

The current bus/engine is an execution context variable. Binding is scoped and
restores automatically on return — including early exits via `?EXIT`.

```forth
: >bus  s" bus> bus!" evaluate ; immediate

: ?quiet   sfx-bus >bus   0.5 gain   foo? ?exit   hush ;
```

## Module-Level Defaults

A module (e.g. a minigame) can assume a bus is bound by having its entry point
set the context once:

```forth
: start-minigame   sfx-bus >bus   minigame-main ;
```

Everything called from `minigame-main` operates in `sfx-bus` context. No
annotations needed inside the module.

For stronger isolation, a module imports the specific engine it uses, calling
its words directly. The plugin system is then only relevant at the wiring level,
not at the call site.

## Sound Instances

`sound` (or the engine-specific equivalent) returns a handle to the live voice.
For fire-and-forget calls the handle is ignored. For tracked sounds (looping
ambience, engine hum) you keep the handle and use it to stop, fade, or query:

```forth
: start-engine-hum   engine-hum sound  to hum-handle ;
: stop-engine-hum    hum-handle stop-sound ;
```

`last-sound` is also available to retrieve the handle of the most recently
played sound without changing existing call sites.

## Globals That Become Context-Sensitive

These currently operate on the master mixer. Under the plugin system they
operate on the bound bus/engine:

- `gain` — master/bus gain
- `stream-gain` — stream gain (music bus)
- `hush` / `stop-sounds` — stop all on bound bus
- `voice?` — playback gate predicate, becomes per-bus

`hush-samples` and `hush-stream` as separate words provide finer control when
needed without changing the combined `hush`.

## What the Plugin System Provides

- Registration and bookkeeping of loaded engines
- Per-frame `engine-update` dispatch for engines that need it
- Abstract words (`gain`, `sound`, `hush`, etc.) vectored to bound engine
- Bus tree with hierarchical gain multiply
- Snapshots — saved mixer states for scene transitions, pause, etc.
- Ducking — bus A attenuates bus B when active (e.g. voice ducks music)

## What It Does Not Need To Provide

- Compile-time engine selection — just include what you need
- Runtime plugin loading — engines are static/monolithic modules
- Effect chains, 3D audio, voice priority — future concerns
