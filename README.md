# Supershow

A 2D pixel art game engine written in [VFX Forth](https://www.mpeforth.com/).

> **Status:** Pre-1.0. Core systems are functional but several subsystems are still in progress. Not yet recommended for general use.

---

## Overview

Supershow is built in three layers, each extending the one below.

### Forge
A modernized dialect of VFX Forth. Forge's goal is to bring Standard Forth up to date with features expected from a contemporary language:

- **Module system** — explicit imports, exports, and re-exports; controlled namespacing
- **OOP (NIBS)** — trait-based object system with classes, protocols, properties, inheritance, and late binding
- **Fixed-point math** — 16.16 format throughout, with a literal recognizer so `1.5` is a fixed-point constant
- **Arrays** — typed, bounds-checked, with compact allocation syntax
- **Execution contexts** — scoped dynamic variables without stack discipline overhead
- **Validations** — contract-oriented zero-cost runtime checks (stripped in release builds)
- **String formatting** — printf-style output
- **JSON** — parse and query JSON data
- **Logging** — structured log output
- **Trees** — doubly-linked tree structure (dltree)

### Engineer
The development runtime. Engineer hosts an Allegro 5 graphics window that runs alongside VFX Forth's interactive console, so you can write and evaluate code while the game is running.

- **Allegro 5 bindings** — graphics, input, audio, and windowing via Allegro 5
- **Pen/color model** — position and color as execution-context variables; `at`, `rgba8`, etc.
- **VGA text** — built-in 8x8 font for on-screen output
- **Live REPL** — evaluate code against the running game at any time; redefine words and reload files without restarting
- **Project loading** — `cartridge` loads `main.vfx` from the working directory; `boot` vector for game-specific startup
- **Build system** — produce release, debug, or standalone dev executables via `save-release`, `save-debug`, `save-dev`

### Supershow
The game engine middleware. Builds on Engineer to provide the systems a 2D game needs:

- **Actor/sprite system** — pooled actors with per-frame behavior scripts, fixed-point positions, velocity, and AABB collision detection
- **Tilemap rendering** — single-call CPU vertex renderer (`al_draw_prim`), H/V flip support, multiple tilesets
- **Tileset management** — load and reference tilesets independently per tilemap
- **Assets autoloading** — assets in `dat/` are loaded and registered automatically at startup
- **Input** — keyboard and mouse; gamepad planned
- **Waveplay** — sample-based audio engine
- **Addons** — optional extras that depend on the engine but aren't part of the core (e.g. `addons/shapes.vfx` for primitive drawing)

---

## In Progress / Planned

- **Tiled map editor support** — import `.tmj` tilemaps from [Tiled](https://www.mapeditor.org/)
- **Scrolling tilemaps** — camera/viewport offset for large worlds
- **Joystick/gamepad support**
- **WorkZone** — UI framework and visual composition environment for building and laying out interfaces at runtime, currently a WIP
- **Spunk** — framework for screen-by-screen games with an integrated level editor
- **ASU** — Csound 6-powered audio engine for music and sound design

---

## Requirements

- Windows
- [VFX Forth](https://www.mpeforth.com/) (free community edition available)
