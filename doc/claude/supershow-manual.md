# Supershow System Manual for Claude

This is the codebase you're working in. It is a custom 2D game engine called **Supershow** (housed within the VFXLand5 workspace, codename "Starling"), written in **VFX Forth** with Allegro 5 bindings. There is no mainstream equivalent. Read this file before writing any code.

---

## What This Is

The stack: **Engineer** (base runtime/IDE) → **Supershow** (game middleware) → **game projects**. You are almost always working in the Supershow layer or a sandbox/test program that imports it. The entry point for any program is `import %supershow%/src/supershow.vfx` at the top, then define your stuff, then call `main`.

The working directory is `supershow/`. Key subdirs:
- `forge/` — core dialect, NIBS OOP, module system, arrays, fixed-point
- `engineer/` — frame loop, input, windowing, delta time, go/show
- `allegro5/` — Allegro 5 FFI bindings; `graphics.vfx` has pen/color/drawing; `input.vfx` has keyboard/mouse; `keys.vfx` has `<A>` etc.; `vga13h.vfx` has `color` (palette index)
- `src/` — actor system (`actor.vfx`, `stage.vfx`, `sprites.vfx`), traits (`traits.vfx`), tilemaps, collision, audio, border, mode
- `addons/shapes.vfx` — circle, rect, line, oval drawing primitives
- `test/` — worked demos and test programs (`eyes.vfx`, `treats.vfx`, `crowd.vfx`, `boxland.vfx`, `coldemo.vfx`, `shapetest.vfx`); read these for usage patterns
- `sandbox/` — scratch programs (`dictionary.vfx`, `playable.vfx`)
- `lib/` — utilities: `mersenne.vfx` (RNG), `rsort.vfx`, `lstring.vfx`, etc.
- `doc/claude/` — this file and other docs for Claude

---

## VFX Forth: The Language

VFX Forth is a commercial Forth with some non-standard extensions. The dialect is further customized by Forge and Engineer.

**Absolutely critical rule**: VFX Forth has NO forward references. If you call a word before it is defined in the file, it is a hard compile error — not a silent noop, not a stale call, a crash. Before writing any word, verify every word it calls is already defined above it or in an imported module. This is the most common mistake Claude makes. Check this before writing, not after.

**Fixed-point arithmetic** is used everywhere. The format is 16.16: integer bits in the high 16, fraction in the low 16.

- Literals: `15.` is a fixed-point literal (= 15.0). `0.5` works too.
- `>p` — integer to fixed: `15 >p` = `15.`
- `>i` — fixed to integer (truncate): `15. >i` = `15`
- `2>p` — pair of integers to fixed pair: `x y 2>p` → `x. y.`
- `2>i` — pair of fixed to integer pair
- `p>f` — fixed to float (for Allegro calls)
- `f>p` — float to fixed
- `p*` — fixed multiply: `a. b. p*` = `a*b` in fixed
- `p/` — fixed divide

**Float literals** go on the separate float stack: `1e` = 1.0, `0e` = 0.0, `255e`, `0.5e`, `25e-20`. Used when calling Allegro APIs directly. Convert with `p>f` (fixed→float) or `s>f` (integer→float). `f>p` and `f>s` go back. `f>sf`/`sf>f` transfer between float stack and data stack as a 32-bit float cell.

**Stack notation** used in this codebase:
- `n` = integer, `p` = fixed-point (often written with `.` suffix), `f` = float (separate float stack), `a` = address, `b` = boolean flag, `xt` = execution token, `$` = counted string (address of count byte followed by characters)

**Key word forms** you must know:

`2@` and `2!` in this dialect are redefined for coordinate pairs — they fetch/store two adjacent cells as (x, y):
- `addr 2@` → `( x y )` where x is at addr, y is at addr+4
- `x y addr 2!` → stores x at addr, y at addr+4

`2+` and `2-` are redefined for coordinate pairs: `x1 y1 x2 y2 2+` → `x1+x2 y1+y2`

`2*` and `2/` similarly operate on pairs element-wise.

`for` is equivalent to `0 ?do`: `n for ... loop` iterates n times, `i` is the loop counter (0-based). Do not declare `i` as a local — it's provided automatically.

`?exit` — exits the current word if top of stack is non-zero (truthy). `( n - )`
`-exit` — exits the current word if top of stack is zero (null guard). `( n - )`

`?execute` — `( xt - )` executes xt if non-zero, otherwise drops it.  Important: any parameters on the stack are NOT dropped, so this is intended to be used only when xt takes no parameters.

`?dup` — duplicates top of stack only if non-zero.

`not` = `0=` (boolean negation).

`aka` = `synonym` (create an alias for a word - new name first, old name second).

`redef` — suppresses the redefinition warning for the rest of the line.

`||` — single-line private marker: `|| : helper ... ;` compiles `helper` into the private wordlist even if currently in a `public` section.

`fast{ ... fast}` — block with native-code optimizations enabled. Used in performance-critical code. No semantic difference for your purposes.

`f>sf` — `( f:n - n )` moves float from float stack to data stack as single-cell IEEE 754. Use this to pass a float to Allegro APIs that take a 32-bit float arg.
`sf>f` — `( n - f:n )` reverse.

`['] word` — compiles the XT of `word` (works at both compile-time and interpret-time in this codebase; redefined in core.vfx).

`continuation:` — defines a word that, when called, takes the rest of the caller's code as its argument (like `does>` but for control flow). `act>`, `physics>`, `show>`, `work>`, `batch>`, `timer>`, `task>` are all continuations. The continuation body IS the remainder of the enclosing word — it runs every iteration/call, not just once.

`{: params | locals :}` — MPE-style locals. Only one locals block per word, must be at the top. Do not use locals inside continuation bodies (`act>`, `physics>` etc.) — they don't work there. Use values instead.

Do not name locals after global words. Bad: `{: x :}` shadows the property `x`. Bad: `{: i :}` shadows the loop counter. Avoid: `count`, `x`, `y`, `z`, `i`, `j`, `k`, `max`, `min`.

`udup` = `over swap` (useful utility for duplicating the second stack item while preserving TOS).
`umod` — unsigned modulo.
`clamp` — `( n lo hi - n' )`.

---

## Module System

Every file that is not just a raw include starts with `module` or `module [name]`.

After `module`, the default section is **private**. Definitions go into the private wordlist until `public` is declared.

```forth
module               \ bare: uses filename as module name
module [supershow.task]   \ named module

private              \ default; words go into private wordlist
: helper ... ;       \ private

public               \ switch to public wordlist
: api-word ... ;     \ public

|| : one-liner ... ;  \ private even inside a public section
```

`import [name]` or `import path/file.vfx` — loads and adds a module's public words to search order.
`reexport [name]` — makes imported module visible to anyone who imports the current module.

Files in a game/sandbox must start with:
```forth
module
import %supershow%/src/supershow.vfx
```

`%idir%` — macro that expands to the current project directory (the directory containing the file being compiled).
`%supershow%` — macro for the Supershow root directory.

To add a private helper interleaved with public defs: use `||`.

---

## NIBS OOP System

NIBS is the custom OOP layer. It is trait-based. Classes hold data; traits hold protocols (methods). Every object's first cell is a pointer to its class.

### Defining classes and traits

```forth
class: %myclass
    prop foo :int        \ integer property (1 cell)
    prop bar :fixed      \ fixed-point property (1 cell)
    prop baz :xt         \ execution token property (1 cell)
    prop ref :ref %actor \ object reference property (1 cell)
    prop addr :addr      \ raw address property (1 cell)
class;

class: %child  %parent derive   \ copy parent layout + protocols
    prop extra :int
class;

trait: %mytrait
    :: myprotocol ( - ) ;    \ defines protocol with default body
trait;

class: %myclass
    is-a %mytrait            \ apply trait (identity + protocols + props)
    works-with %mytrait      \ apply without identity (CAN? yes, IS? no)
class;
```

Property type annotations (`:int`, `:fixed`, `:float`, `:xt`, `:ref`, `:addr`) are metadata for display/serialization only. They do not affect the cell size — all properties are one cell. They affect `<save` (which props get serialized) and introspection.

`<save` after a prop declaration marks it as serializable.
`<readonly` marks it as read-only.

`nprop` (or `nproperty`) — like `prop` but takes an explicit byte size first: `256 nprop buf :cstring`. Use when you need a multi-byte field (buffers, structs) rather than a single cell. `prop` is just `cell nprop`.

**Property names are late-bound and reusable across classes.** Declaring a property whose name already exists does NOT create a conflicting word or error — `nproperty` detects the existing property (`%property already?`) and maps it into the new class. The single accessor word resolves the right offset per-class at runtime (via `->property`). So defining `x`/`y`/`bmp`/etc. in several unrelated classes is fine and intended: each class gets its own slot, and `obj -> x @` reads whichever class `obj` is. You do NOT need to invent unique field names (e.g. `bx1`/`sx`) to avoid collisions — reuse the natural name. (Caveat: a same-named property must be the same logical thing; the offset differs per class but the accessor is shared.)

**Embedding a record object inline (manual, no special feature):** reserve the bytes with `nprop` sized to the record class, and stamp its class pointer in the owner's template so the inline buffer is a valid object:
```forth
%box-params sizeof nprop box-params       \ inline storage for an embedded %box-params
%owner template { %box-params box-params ! }   \ stamp class ptr -> valid object
\ then: box-params -> x1 !   (access like any scoped object)
```
This only stamps the class pointer, not the record class's own template defaults — fine for flat records, insufficient if the record class has template defaults.

### Protocols

A protocol is a late-bound method. Defined with `::` inside a trait (creates the slot) or a class (overrides it).

```forth
%myclass :: draw ( - )
    ... draw code ... ;

%myclass :: start ( - )
    ... startup code ... ;
```

`start` is run by `spawn` (see Spawning) — **not** by `one` and **not** by the constructor. It's where you install `act>` and do per-instance setup.
`draw` is called by `render` to draw the actor relative to the pen position.
`render` is the engine-facing entry: positions the pen and calls `draw`. Usually you only override `draw`.
`unload` is called when the actor is removed.

### Object instantiation

```forth
%myclass object myobj      \ named dictionary object (compile-time)
%myclass spawn             \ pool-allocate + construct AND run start, returns it
%myclass one               \ pool-allocate + construct only (NO start), returns it
%myclass make              \ allocate unnamed object (in dict or heap), returns it on stack
```

`spawn` is the usual way to create a *running* actor: it does `one`, then calls the actor's `start` protocol. Both pull a node from the pool and run the constructor (template + `:construct` → `init-actor`, which sets `(x,y)` from the pen and stamps the clock); the only difference is whether `start` runs. Use `one` when you must set properties **before** `start` reads them — then call `start` yourself:

```forth
%myclass spawn                            \ create and start (uses defaults)
%myclass one { foo ! bar ! this start }   \ configure first, THEN start
%myclass one to myvalue                   \ create without starting; start later
```

### Object scoping and property access

**This is the most important section to get right.** There are four forms:

**Form 1: scoped with `{ }`**
`{ }` pushes the object as `this`, making properties accessible by name directly.
```forth
myobj { foo @ bar . }     \ reads foo and bar from myobj
myobj { 42 foo ! }        \ writes 42 to foo
```
Inside a `{ }` block: bare property names work. `this` = the object. `me` = same as `this`.

Inside a protocol (`:: name`), constructor (`:construct`), or destructor (`:destruct`), `this` is already bound — bare property names work directly without any `{ }` wrapper.

**Form 2: `->` prefix (stack-based)**
For objects on the stack without a full scope:
```forth
myobj -> foo @            \ read foo from myobj (object stays on stack momentarily)
myobj -> foo !            \ write; stack: ( val obj - )
```
`-> propname` computes `(obj + class-offset-of-prop)`, leaving the field address. Then `@` or `!` as usual.

**Form 3: `>propname` accessor (auto-generated)**
Each property `foo` automatically gets a `>foo` word that computes the field address (equivalent to `-> foo`):
```forth
myobj >foo @              \ same as myobj -> foo @
myobj >foo 2@             \ get foo and the adjacent next prop as a pair
```

**Form 4: bare property name inside `act>`, `physics>`, etc.**
Inside continuation bodies, `this` is the current actor. Property names work directly:
```forth
%myclass :: start ( - )
    act>
        foo @ .           \ reads foo from current actor (this)
        42 bar ! ;        \ writes bar
```

**Critical property access rules:**

Single `:fixed` property: use `@` and `!` — NOT `2@`/`2!`:
```forth
prop speed :fixed
speed @    \ correct: fetches one cell (the fixed value)
speed 2@   \ WRONG: fetches speed AND the next prop as a coordinate pair
```

Adjacent `:fixed` pair (like `x`/`y` or `vx`/`vy`): use `2@` and `2!` on the FIRST:
```forth
prop vx :fixed  prop vy :fixed   \ adjacent in memory
vx 2@            \ correct: gets (vx, vy) as a pair
x 2@             \ correct: gets (x, y) because x and y are adjacent in %xy
vx @   vy @      \ also correct: get each individually
vx 2@ vy 2@      \ WRONG: fetches (vx, vy) twice — never do this
```

`x 2@` gives both x AND y. `x @` gives only x. Only use `2@` when you want BOTH.

**`as>`** — continuation form: `actor as> ... ;` scopes the actor for the rest of the caller. Example: `%treat one as> 4. -2. 2rnd vx 2!`

**`as`** — dev/REPL tool only; do not use in game code.

**`you`** — the previous object on the object stack (one level up from current `{ }`).

---

## The Actor System

The actor system is built on a pool of `%node` objects backed by `%actor`. All actors live in `actors` (a `%stage`). The engine loop calls `step` (behave + physics + time) and `sprites` (draw).

### %actor properties (from traits and class)

`prop x :fixed`, `prop y :fixed` — position, as adjacent pair → `x 2@` / `x 2!`
`prop vx :fixed`, `prop vy :fixed` — velocity pair → `vx 2@` / `vx 2!`
`prop en` — enabled flag (non-zero = alive)
`prop beha :xt` — per-frame behavior XT (set by `act>`)
`prop phys :xt` — per-frame physics XT (set by `physics>`)
`prop _time :fixed` — internal gametime stamp (16.16 seconds). Don't read directly: use the `time` getter (secs since last stamp) and `/time` to re-stamp. See Timing.
`prop prio :int` — draw priority (0 = draw behind BG via `backsprites`)
`prop lyr :int`, `prop msk :int` — collision layer/mask bitmasks
`prop bmp :int` — bitmap ID for sprite rendering
`prop anm`, `prop a.ts`, `prop a.spd`, etc. — frame animation

The `simple-motion` physics (default): each frame adds `(vx, vy)` to `(x, y)`.

### Starting and scripting actors

```forth
class: %myactor  %actor derive
    prop mydata :int
class;

%myactor :: start ( - )
    42 mydata !           \ one-time setup
    act>                  \ per-frame behavior — everything after this IS the body
        mydata @ . ;      \ runs every frame; ends at ;

: launch
    160 120 at  %myactor spawn drop ;
```

`act>` is a continuation — the code following it in the same word is the per-frame body. It also re-stamps the actor's clock (via `/time`), so `time` reads 0 at install.

**Multiple `act>` in one word = a state machine.** Because `act>` reassigns `beha` to "the rest of the word," a second `act>` reached at runtime simply swaps the actor into a new behavior. The actor keeps running the current `act>` body until execution actually reaches the next `act>`, so guard a later `act>` with a condition + `?exit`/`-exit` to delay the transition. And since every `act>` re-stamps via `/time`, `time` measures how long the actor has been in its *current* state:

```forth
%foe :: start
    act>                      \ state 1: approach
        move-toward-target
        reached? -exit        \ not there yet → stay in state 1 this frame
        act>                  \ state 2: attack (installed on arrival; clock resets)
            time 1.0 passed? if fire then ;
```

For separate physics and behavior, use `physics>` for physics and `act>` for logic.

`physics>` is also a continuation — sets the physics XT. The physics body runs before `beha`. Default physics (`simple-motion`) is installed in the template; override it by calling `physics>` in `start`.

```forth
%myactor :: start ( - )
    physics>
        x @ 5 + x ! ;    \ custom physics: this replaces simple-motion
```

Each continuation (`act>`, `physics>`) terminates the enclosing word at `;`. You can chain them by having one continuation call another — but be aware this locks both hooks to the same word, since the first continuation's body IS the word that installs the second:

```forth
%myactor :: start ( - )
    physics>
        x @ 5 + x !
        act>
            ... behavior ... ; \ act> is called once by the physics body, locking them together
```

If you need them independent (reinstallable separately / the most typical use case), extract into helper words:

```forth
: my-physics ( - )
    physics>
        x @ 5 + x ! ;

%myactor :: start ( - )
    my-physics
    act>
        ... behavior ... ;
```

`act>` and `physics>` do NOT execute immediately — they store the XT and exit the current word at `;`. Everything before them runs once at startup and are referred to as the "preamble" of the word.

### Spawning

`spawn ( class - actor )` = `one` + the actor's `start`; it's the normal way to create a live actor. `one ( class - actor )` constructs without starting — use it to configure before `start`.

```forth
%myactor spawn            \ ( - actor ) construct AND start, returns actor
%myactor spawn drop       \ start without keeping reference
gamew rnd gameh rnd at  %myactor spawn drop   \ start at a random position
%myactor one { 5 mydata ! this start }        \ configure first, then start
%myactor spawn to myvalue                     \ keep the handle

\ from: position relative to another actor
another-actor  dx dy  from  %myactor spawn drop
\ `from` sets the pen to (another-actor.x + dx, another-actor.y + dy)
```

The pen position at construct time becomes the actor's initial `(x, y)` (set by `init-actor`); `start` runs afterward (under `spawn`, or when you call it). An actor made with `one` and never started exists with physics (`simple-motion`) but no behavior — its `act>` is never installed.

### Removing actors

```forth
me unload        \ inside act>: mark self for removal
myactor unload   \ mark any actor for removal
```

Actual removal is deferred to `sweep` (called at end of each `step`).

`exists? ( actor - flag )` — safe check; returns 0 for null or freed actors.

### Frame loop integration

`step` — runs one frame of actor logic: all actors' `beha`, then `phys`, then advances the game clock (`+gametime`). Called once per frame from your `think` word.

`animate` — advances frame animations for all actors with `anm` set.

`sprites` — draws all active actors sorted by Y (for depth), filtered to `prio <> 0`.
`backsprites` — draws actors with `prio = 0` (behind tilemap/BG).

`stg@` — returns the current stage.

`just` — clears all actors from the stage, resets pen to center.

Typical main:
```forth
: think  step animate ;
: ~render  sprites ;
: main
    just
    ... spawn actors ...
    show> ~render
    work> think ;   \ if you need separate draw and logic callbacks; otherwise show> alone works
```

Wait — `show>` alone means think AND render run together. `work>` + `show>` splits them. But if using `mode.vfx`, `show>` sets the draw callback and `work>` sets the logic callback separately.

Actually the simplest pattern (from `treats.vfx`):
```forth
: ~test  sprites ;
: think  step ;
: main
    just
    3 0 do  %spewer spawn drop  loop
    show> think ~test ;   \ show> takes EVERYTHING after it as the body
main
```

---

## Drawing

### The pen position

All drawing is relative to a pen position. Set it before drawing:

```forth
160 120 at        \ set pen to pixel (160, 120) — integer args
160. 120. atp     \ same with fixed-point args
at@               \ ( - x y ) get pen as integers
at@p              \ ( - x. y. ) get pen as fixed-point
+at  dx dy +at    \ offset pen by integer delta
+atp dx. dy. +atp \ offset pen by fixed-point delta
```

### Colors

```forth
$RRGGBBAA rgba8   \ set color from packed hex: $ff8800ff = opaque orange
0 color           \ set color from VGA palette index 0 (black)
15 color          \ index 15 = white
1. 0. 0. 1. rgba  \ set color from fixed RGBA components directly
```

Colors are stored in execution context (`ec-cell`) — they persist until changed. The color affects all subsequent drawing calls.

### Shapes (addons/shapes.vfx — must be imported separately)

All shapes draw at the current pen position. Must `import %supershow%/addons/shapes.vfx`.

```forth
15. circf         \ filled circle, radius 15. (fixed-point)
30. circ          \ outlined circle
80. 50. rectf     \ filled rect, width 80. height 50.
80. 50. rect      \ outlined rect
130. 200. line    \ line from pen to fixed-point endpoint
38. 18. ovalf     \ filled ellipse rx=38. ry=18.
38. 18. oval      \ outlined ellipse
1. thick          \ set outline thickness (default 0.5)
pixel             \ draw a single pixel at pen
```

The rectangle and line words treat the pen as the top-left / start point respectively.

**Naming symbol conventions** — prefix/suffix meanings used throughout this codebase:

| Symbol | Position | Meaning |
|--------|----------|---------|
| `~` | prefix | draw/render word (`~lids`, `~test`) |
| `%` | prefix | class name (`%actor`, `%eyeball`) |
| `#` | prefix | count of something (`#items`, `#boxes`) |
| `#` | suffix | index or ID (`classifier#`, `bmp#`) |
| `*` | prefix | create/instantiate (`*stacks`, `*zbuf`) |
| `-` | prefix | destroy, negate, clear, remove (`-albmp`, `-exit`) |
| `+` | prefix | add, increment, push (`+at`, `+gametime`) |
| `/` | prefix | initialize/setup (`/object-base`) |
| `s/` | prefix | size of in bytes (`s/node`, `s/ec`) |
| `?` | prefix | conditional execution (`?exit`, `?execute`, `?dup`) |
| `?` | suffix | returns a boolean (`free?`, `exists?`, `held?`) |
| `&` | prefix | address of (rare) |
| `>` | prefix | convert to / compute address of (`>p`, `>i`, `>foo`) |
| `@` | suffix | fetch (`at@`, `penx@`) |
| `!` | suffix | store (`backdrop!`, `kxt!`) |
| `.` | prefix | print (`p.`, `.s`, `.summary`) |
| `$` | suffix | counted string buffer (`tag$`, `name$`) |

### Sprites

```forth
bmpid cput        \ draw centered sprite at pen
bmpid put         \ draw sprite with top-left at pen
```

`%actor :: draw` default: `bmp @ -exit  bmp @ cput` — draws centered if bmp is set.
`%actor :: render` default: `x 2@ 2>i at  this draw` — positions pen from actor coords (rounded down to nearest integers), calls draw.

### Batch drawing

`batch>` is a continuation that wraps drawing in `al_hold_bitmap_drawing`:
```forth
0 batch>  ... drawing ...  ;   \ 0 = flush and restore previous holding state 
-1 batch>  ... drawing ...  ;  \ -1 = enable/maintain hold
```

### Screen clearing

```forth
cls                \ clear to `backdrop` color (variable, default black)
$c8a080ff backdrop !  \ set backdrop color
$181818ff rgba8 screen \ clear to specific color (doesn't affect backdrop)
```

---

## Input

Key state words (`allegro5/input.vfx`, `allegro5/keys.vfx`):

```forth
<A> held?         \ ( - flag ) is key held down
<A> pressed?      \ ( - flag ) just pressed this frame
<A> letgo?        \ ( - flag ) just released this frame
```

Mouse (and joystick) buttons are treated as virtual keys so they also work with these.

Key constants: `<A>` through `<Z>`, `<0>` through `<9>`, `<F1>` through `<F12>`, `<up>`, `<down>`, `<left>`, `<right>`, `<space>`, `<enter>`, `<esc>`, `<lshift>`, `<rshift>`, `<lctrl>`, `<rctrl>`, `<lmb>`, `<rmb>`, `<mmb>`.

Mouse state:
```forth
mouse             \ ( - x y ) mouse position as integers
mousex            \ address of fixed-point x (mousex 2@ for both as fixed pair)
pmouse            \ ( - x. y. ) mouse as fixed-point pair
lmb?              \ ( - flag ) left button held (also: <lmb> held?)
rmb?              \ right button
mmb?              \ middle button
```

Global modifier flags: `alt?`, `ctrl?`, `shift?` — updated each frame.

---

## Timing

### Where time comes from (Engineer)

Engineer owns the real clock. Once per frame, `update-delta` (engineer/go.vfx) samples the kernel microsecond counter `ucounter` (a `QueryPerformanceCounter`-based monotonic wall clock) and recomputes a set of global time values, all defined in engineer/variables.vfx:

`ustime` — `( - d )` double, absolute time in **microseconds**. A monotonic wall-clock snapshot taken once per frame. Does NOT pause.
`mstime` — `( - n )` integer, `ustime` in milliseconds.
`usdelta` — `( - n )` integer microseconds elapsed since the previous frame, **clamped to `max-usdelta`**.
`pdelta` — `( - n. )` fixed-point seconds elapsed since the previous frame (derived from clamped `usdelta`).
`fdelta` — `( - f:seconds )` float seconds elapsed since the previous frame (derived from clamped `usdelta`). On the float stack.
`max-usdelta` — `( - n )` value; cap on `usdelta` (default `250000`, i.e. 0.25 s). Absorbs dev stalls / frame hitches so the deltas — and everything derived from them, including `gametime` — can't lurch forward. Note `ustime` itself is **not** clamped; it always holds true wall time.
`tps` — `( - f )` float target ticks (frames) per second (default `60e`); the Allegro frame timer fires at this rate.
`ticks` — `( n - ms )` convert a count of frames to milliseconds at the current `tps`.

These are the framerate-independence primitives: scale per-frame movement by `pdelta`/`fdelta` so motion is time-based, not frame-based. The `max-usdelta` clamp also prevents physics from exploding or tunnelling on a single slow frame.

### The game clock (Supershow)

Layered on top of Engineer's `usdelta`, Supershow keeps a pausable **game clock** (src/actor.vfx):

`gametime` — `( - d )` double **microseconds** of accumulated game time. Each frame `+gametime` adds `usdelta` to it, but **only while `clock` is on** — so it freezes when the game is paused.
`clock` — variable gating `gametime`; `clock off` pauses game time, `clock on` resumes.
`gamelife` — frame counter, incremented every frame regardless of `clock`.

`gametime` (not the wall clock) is what actor timers are built on, so actor timers automatically pause with the game.

### Per-actor timer

Each actor carries `_time` (internal `:fixed` property) — a 16.16 **stamp** of `gametime` (in seconds), not an accumulator. Two words operate on it (both require an active `this`, i.e. inside `act>` or a protocol):

`/time` — `( - )` stamp the current actor's clock to now. Called automatically when `act>` is installed and when the actor spawns.
`time` — `( - n. )` fixed-point seconds elapsed since the last `/time`.
`passed?` — `( n. - flag )` true if `time >= n.`; when it fires it re-stamps via `/time`, so it behaves as a repeating interval. Useful for timeouts inside `act>`.

```forth
act>  2.0 passed? if ... then ;   \ do something every 2 seconds
act>  time 0.5 >= if ... then ;   \ test elapsed without resetting
```

For a one-shot timed callback:
```forth
5. timer> ... ;     \ execute once after 5 seconds
```

---

## Asset Loading

Assets are declared at the top level of a file (outside any word definition). They are compile-time operations that embed the file data and register the asset.

```forth
bitmap %idir%/dat/gfx/mysprite.png    \ declares word `mysprite.png` → bmpid
bitmap %idir%/dat/gfx/player.png

mysprite.png 16 16 tileset-from  player-ts   \ ( bmpid tw th <name> ) → tileset
20 15 tilemap the-map                         \ ( w h <name> ) → tilemap

sample %idir%/dat/smp/jump.ogg       \ declares word `*jump*` → plays sample
bgm mytrack  %idir%/dat/bgm/music.ogg \ declares word `mytrack` → streams BGM

ttf-font 12 %idir%/dat/fnt/myfont.ttf  \ loads TTF font, sets as default
bitmap-font %idir%/dat/fnt/font.png     \ bitmap font
```

After `bitmap myfile.png`, the word `myfile.png` exists and returns the bmpid when called.
After `sample jump.ogg`, `*jump*` returns the sample ID. Call `*jump* sound` to play it.
`hush` — stop all audio.
`softice` (or whatever bgm name) — stream that BGM.

The `%idir%/dat/gfx/` path is conventional. `%idir%` is the project root.

---

## Trig and Math (src/utilities.vfx)

```forth
vec   ( deg. len. - x. y. )      \ polar to cartesian
angof ( x. y. - deg. )           \ angle of vector in degrees (0=right, CW)
dist  ( x. y. x. y. - n. )       \ distance between two points (fixed)
hypot ( x. y. - n. )             \ magnitude of vector
uvec  ( deg. - x. y. )           \ unit vector from degrees
```

RNG (`lib/mersenne.vfx`, `forth-public` so always visible):
```forth
10 rnd    \ ( n - n' ) random integer 0..n-1
2rnd      \ ( n n - n' n' ) two independent rands
```

`clamp ( n lo hi - n' )` — standard clamp.
`umod ( n n - n' )` — unsigned modulo (always non-negative result).

---

## String Formatting (forge/format.vfx)

`f" format-string"` — immediate word; consumes arguments from the stack according to the format string and leaves `( a u )` (addr/len of result in a rotating buffer). Use anywhere a string is needed.

```forth
42 f" value is %n" type
s" world" f" hello %s!" type
```

Format specifiers (each consumes one stack item unless noted):

| Specifier | Stack consumed | Output |
|-----------|---------------|--------|
| `%%` | — | literal `%` |
| `%c` | `n` | single character |
| `%n` | `n` | signed decimal integer |
| `%u` | `u` | unsigned decimal integer |
| `%dn` | `d` (2 cells) | double-cell signed |
| `%du` | `d` (2 cells) | double-cell unsigned |
| `%p` | `n.` | fixed-point number |
| `%f` | `f:n` | float (from float stack) |
| `%s` | `a u` (2 cells) | addr/len string |
| `%z` | `z$` | zero-terminated string |
| `%$` | `$` | counted string |
| `%[code]` | varies | evaluates `code`, inserts result |

Optional flags between `%` and specifier: `-` left-justify, `0` zero-pad, decimal number = minimum field width. Example: `%05n` formats an integer in a zero-padded 5-wide field.

`sformat ( n*x c-addr1 u1 -- c-addr2 u3 )` — runtime version; takes format string as explicit addr/len.
`fe"` — like `f"` but processes escape sequences (`\n`, `\t`, etc.) in the format string.

---

## String Output Capture (lib/lstrout.vfx)

Capture output (from `emit`, `type`, `cr`, `.`, etc.) into a dynamic lstring buffer. Used for special cases where you need to capture console output - `f"` handles most string formatting needs.

```forth
lstrout ( xt - lstr )   \ Execute xt with output redirected, return lstring
```

**Important:** Caller must free the returned lstring with `lfree`.

**Usage:**
```forth
create buf 256 allot
[: actor .summary ;] lstrout   ( - lstr )
dup lcount buf place
lfree
```

**Common pattern - capture to log:**
```forth
create msg-buf 256 allot
[: ." Error in " actor .summary ;] lstrout
dup lcount msg-buf place
lfree
f" %s" msg-buf count log
```

**Inline pattern:**
```forth
[: actor .summary ;] lstrout
dup lcount type
lfree
```

---

## Cooperative Multitasking (src/task.vfx)

Part of the standard engine — included automatically by `import supershow`. Available to all programs that import supershow.

It extends `%actor` with four props: `task.sp`, `task.rp`, `task.ds`, `task.rs` (stack pointers and heap-allocated stack buffers).

Key words:
```forth
yield           \ switch execution to host; resume on next frame's act>
fyield          \ yield while preserving a float on the data stack
wait ( n. - )  \ yield for n. seconds

task> ( n - <body;> )  \ continuation: install body as coroutine with n as initial stack value
```

Example usage:
```forth
%myactor :: start ( - )
    physics>
        ... physics code ... ;  \ must be separate word
    0 task>
        begin
            5. wait  do-something
            3. wait  do-other-thing
        again ;
```

Inside the task body, `yield` and `wait` are legal. Properties of `this` (the actor) are accessible normally. The task body runs as a true coroutine — it blocks at `yield`/`wait` and resumes the next frame.

`fyield` pattern — preserve a float across a yield:
```forth
f>sf yield sf>f   \ or just: fyield
```

The `%eyeball :: start` pattern (extract physics to separate word so both `physics>` and `task>` can appear):
```forth
: eyeball-physics ( - )
    physics>
        ... ;

%eyeball :: start ( - )
    eyeball-physics
    0 task>
        begin ... yield ... again ;
```

---

## Patterns and Idioms

### Minimal program structure

```forth
module
import %supershow%/src/supershow.vfx

: main
    show> sprites ;   \ sprites draws all actors every frame

main
```

### Actor with custom draw

```forth
class: %ball  %actor derive  class;

%ball :: draw ( - )         \ pen is already at actor position (set by render)
    $ff4400ff rgba8
    10. circf ;

%ball :: start ( - )
    act>  0.1 vy +! ;       \ accelerate downward each frame

: launch
    160 120 at  %ball spawn drop ;
```

### Relative positioning with `from`

```forth
\ `from` ( actor x y - ): sets pen to actor.pos + (x,y)
parent-actor  10 5  from  %child spawn drop
```

### Owner-relative positioning via physics>

```forth
\ Factor the *concept* into a private vocabulary word — `follow` is a verb with
\ meaning, so the behavior reads as prose. (`follow` hides the arithmetic detail.)
|| : follow  owner @ >x 2@  lx 2@ 2+  x 2! ;   \ self pos = owner's + local (lx,ly)

%child :: start ( - )
    physics>
        owner @ -exit  follow ;     \ no owner -> skip; else follow it
```

### Spawning from within an actor's act>

```forth
act>
    this 0 0 from  %sparkle one { 2. rnd 1. - vx ! this start } ;
\ `this 0 0 from` = pen at self position; spawns sparkle there
```

### Loading assets and using them

```forth
bitmap %idir%/dat/gfx/player.png
player.png 16 16 tileset-from player-ts

%myactor :: start ( - )
    player.png bmp !     \ set actor's sprite (bmpid)
    act>  ... ;
```

### Sorting and drawing by depth

`sprites` already sorts by Y. For custom sorting:
```forth
[: >y @ >i ;] sorted-actors>  this render ;
```

### Tilemap usage (brief — see src/tilemap.vfx, test/tmwalk.vfx)

```forth
20 15 tilemap the-map            \ 20 wide, 15 tall
myts the-map >ts !               \ assign its tileset (one store — no { } needed)
map-data >data @ count 20 the-map set-tilemap
0 0 at  the-map draw             \ draw at pen position
```

`tile@ ( col row tilemap - id )` — get tile ID.
`tile! ( id col row tilemap - )` — set tile ID.
`tmslide` — slide-collision with tilemap (see `src/tilecol.vfx`).

### Collision shapes (brief — see src/collision.vfx, test/coldemo.vfx)

All coordinates fixed-point. Functions: `pt-rect?`, `rect-rect?`, `pt-circ?`, `circ-circ?`, `rect-circ?`, `pt-poly?`, `circ-poly?`, `rect-poly?`, `poly-poly?`, `line-rect?`, `line-circ?`, etc.

Broad-phase AABB grid: `cgrid` (see `src/cgrid.vfx`, `test/boxland.vfx`).

### Audio (brief — see src/waveplay.vfx, test/audiotest.vfx)

```forth
sample %idir%/dat/smp/jump.ogg   \ creates word *jump*
*jump* sound                     \ play sample
bgm mymusic %idir%/dat/bgm/track.ogg   \ creates word mymusic
mymusic                           \ stream BGM
hush                              \ stop all audio
```

---

## Worked Examples

### shapetest.vfx — shapes + animation without actors

Triangular wave animation using a frame counter, all drawing done procedurally. No actor system. `show> demo` — the show callback does everything.

Pattern: `show> thing ;` where `thing` draws and updates state. No `step`, no `animate`, no actor pool.

### treats.vfx — minimal actor spawning + self-removal

```forth
%treat :: start
    bmp !                         \ set sprite at spawn time
    act>
        in? not if me unload exit then   \ remove if off-screen
        0.3 vy +! ;               \ gravity

%spewer :: start
    act>
        gamew rnd gameh rnd at    \ random position
        %treat spawn as>          \ spawn treat (runs start), scope it
            4. -2. 2rnd  -2. -2. 2+  vx 2! ;   \ set random velocity
```

Pattern: parent spawns children from inside `act>` using `as>` to scope them.

### crowd.vfx — classes, animations, animation control

Shows: `tileset-from`, `animation`, `range,`, `frame,`, `cycle` for frame animation. The `face` helper switches animation sets. `h|` flips sprite horizontally. `sorted-actors>` for custom render order. Spritebank (`bcput`) for batched GPU sprite rendering.

### boxland.vfx — no actor system, collision grid

Uses `cgrid` directly. Player state is `value`s, not actor properties. Demonstrates: `work> think show> ~test` split, `check-cbox` with callback, axis-separated slide response.

### coldemo.vfx — collision shape tests, mouse input

Reads `mouse  my !  mx !` for mouse position. Uses `ctype @` switch for cursor shape. Demonstrates all collision primitives. Text rendering: `vga-8x8 default-font!` then `x y at  s" text" print`.

### eyes.vfx — comprehensive actor patterns

The most complete example. Shows: owner-relative positioning (`eyeball-physics`); the strategy-XT pattern (`kxt`/`trigger?` — one class, 14 blink behaviors `blink-1?`..`blink-14?`); cooperative multitasking via `0 task>` running `?close`/`?open` to animate the eyelids (`lid`) with `yield`; smoothed target tracking (`target` + `lag`/`laggard` via `2plerp`); the `iris` offset computed from `angof`/`dist`/`vec`; the `~lids` draw helper; and shape-based drawing under `0 batch>`. Spawns eyeballs with `one { … this start }` (configure before `start`), and uses `from` for relative sparkle spawn position.

Note: `0 task>` takes an initial stack value (passed to the task body). `begin ... yield ... again` is the standard infinite-loop task pattern.

---

## VFX Forth / Forge Dialect Glossary

Words you'll encounter that are not standard ANS Forth:

| Word | Signature | Meaning |
|------|-----------|---------|
| `kb` | `( n - n*1024 )` | Kilobytes: `16 kb` = 16384. VFX Forth built-in. |
| `?constant` | `( n - )` | Define constant only if name not already defined |
| `?value` | `( n - )` | Define value only if name not already defined |
| `redef` | `( - )` | Suppress redefinition warning for next definition |
| `screate` | `( a len - )` | `create` from a counted string |
| `sfind` | `( a len - xt -1/0/1 )` | Find word by addr/len |
| `sfind nip` | `( a len - flag )` | Simplified: found? |
| `body>name` | `( a - a' len )` | Get name of word from body |
| `f"` | `( n*x - a u )` | Format string — see String Formatting section for full specifier list |
| `>pad` | `( a n - $ )` | Copy to PAD as counted string, return PAD |
| `>zpad` | `( a n - z$ )` | Copy to PAD as zero-terminated, return PAD |
| `*zbuf` | `( a n - z$ )` | Heap-allocate z-string copy (caller frees) |
| `lshift` | | VFX alias; use `<<` (also available) |
| `rshift` | | VFX alias; use `>>` (also available) |
| `?exit` | `( n - )` | Exit word if n nonzero |
| `-exit` | `( n - )` | Exit word if n zero |
| `?execute` | `( xt - )` | Execute xt if nonzero |
| `link` | `( list - )` | Add `here` to backward-linked list |
| `pagealign` | `( - )` | Align dict pointer to 256 bytes |
| `aligned-page` | `( - )` | Align + allot 256 bytes, define constant |
| `each` | `( xt - )` | Array/iterable iteration protocol; `[: ... ;] array each` |
| `udup` | `( a b - b a b )` | `over swap` |
| `umod` | `( n n - n' )` | Unsigned (always positive) modulo |
| `clamp` | `( n lo hi - n' )` | Clamp value to range |
| `toggle` | `( addr - )` | Toggle boolean at addr |
| `strin?` | `( hay hlen needle nlen - flag )` | Substring search |
| `fast{` `fast}`| `( - )` | Enable/disable native code optimization (VFX built-in) |
| `optimising on/off` | | Toggle optimizer (VFX built-in) |
| `h.` | `( n - )` | Print as hex |
| `h.8` | `( n - )` | Print as 8-digit hex |
| `#.` | `( n - )` | Print as decimal |
| `.-` | `( n - )` | Print without trailing space |
| `p.` | `( n. - )` | Print fixed-point |
| `p?` | `( addr - )` | Fetch and print fixed-point at addr |
| `2?` | `( addr - )` | Fetch and print pair at addr |
| `preword` | `( - $ )` | Peek next word from input stream (without consuming) |
| `preparse` | `( c - a len )` | Like `parse` but doesn't consume |
| `s=` | `( a1 n1 a2 n2 - flag )` | String equality |
| `z$=` | `( z$ z$ - flag )` | Zero-string equality |
| `ext?` | `( fn len ext len - flag )` | File has this extension? |
| `strin?` | | Substring test |
| `fexists?` | | VFX: file exists? |
| `within?` | `( n lo hi - flag )` | Is n in [lo, hi)? |
| `InForth?` | `( addr - flag )` | Is address in dictionary? |
| `fvalue` | `( f: n - )` | Like `value` but for floats |
| `2value` | `( n n - )` | Like `value` but double-cell |
| `errdef` | `( - <name> <msg> )` | Define named error code with message |
| `.throw` | `( n - )` | Print and swallow an exception |
| `bail` | `( - )` | Throw `err_bailed` (benches actor) |
| `count` | `( $ - a n )` | Counted string to addr/len |
| `lcount` | `( $ - a n )` | Heap-allocated lstring to addr/len |
| `place` | `( a n $ - )` | Copy addr/len into counted string buffer |
| `zplace` | `( a n z$ - )` | Copy addr/len into zero-terminated buffer |
| `$create` | | Create word from counted string |
| `evaluate` | `( a n - )` | Interpret string as Forth code |
| `shout"` | `( - )` | Evaluate string, silently swallow errors |

If you encounter a word not in this list and not findable in supershow/, check VFX Forth's built-ins or the VFX Forth manual at `doc/claude/vfxman.txt`.

---

## Critical Rules and Common Mistakes

**Forward references are hard errors.** Every word you call must be defined above the call site. This is the single most common mistake. Before writing any word, trace through every call to verify definition order.

**Single prop = `@`/`!`, never `2@`/`2!`.** Only use `2@`/`2!` on the first of a consecutive PAIR of properties (like `x`/`y`, `vx`/`vy`, `lx`/`ly`). Using `x 2@` when you only want `x` is wrong — it also reads `y`.

**`act>` and `physics>` are continuations, not function calls.** The code after them IS the body. They terminate the enclosing word at `;`. Don't try to put code after a continuation in the same word unless it's the continuation body.

**Module default is private.** After `module`, all definitions are private until you write `public`. If a word isn't visible, check if it's in the wrong section.

**`->` syntax requires an object on the stack.** `myobj -> foo @` — the object must be on stack before `->`. Inside `{ }` or `act>` (where `this` is implicit), bare `foo @` works. But `->` always needs an explicit object.

**Locals can't be used inside continuation bodies.** `{: ... :}` inside `act>`, `physics>`, `task>` etc. doesn't work. Use `value` declarations at the module level instead.

**Commit rule: read the full diff before writing a commit message.** Never name a function from a changed line alone — always read the surrounding context. Always check for new assets or referenced files that need staging.

---

## Where to Look For More

| Topic | File |
|-------|------|
| Full NIBS spec | `doc/nibs/nib2-spec.txt` |
| Module system detail | `doc/module-system.md` |
| VFX Forth manual | `doc/claude/vfxman.txt` |
| Stack comment conventions | `doc/claude/stack-comment-conventions.txt` |
| Word naming conventions | `doc/claude/word-naming-conventions.txt` |
| Collision primitives API | `src/collision.vfx` |
| Tilemap/tilecol API | `src/tilemap.vfx`, `src/tilecol.vfx` |
| Cgrid broad-phase | `src/cgrid.vfx` |
| Audio (samples + BGM streaming) | `src/waveplay.vfx` |
| Allegro 5 drawing calls | `allegro5/allegro-5.2.10.vfx` (raw), `allegro5/graphics.vfx` (wrapped) |
| OpenGL direct calls | `allegro5/opengl.vfx` |
| Spritebank (batched GPU sprites) | `src/spritebank.vfx` |
| EC (execution context) system | `forge/nibs.vfx` |
| Array/stack/iterable collections | `forge/array.vfx` |
| Doubly-linked tree | `forge/dltree.vfx` |
| Logging (`log`, `.info`, `.warn`, `.error`, `.debug`) | `forge/logging.vfx` |
| JSON parsing/building (cJSON wrapper) | `cjson/cjson.vfx` |
| Runtime checks / Oversight system | `forge/oversight.vfx`, `forge/checks.vfx`, `src/checks.vfx` |
| String formatting | `forge/format.vfx` |
| Lstrings (32-bit-counted strings; dictionary-allocated `lstring` `l$,` `l,"` `lplace` variants have overflow protection, heap-allocated `*lstring` variants can grow) | `lib/lstring.vfx` |
| Dialog / UI system | `src/dialog.vfx` |
| Tweak (persistent variable UI) | `src/tweak.vfx` |
| TV border / display framing | `src/border.vfx` |
| Game modes | `src/mode.vfx` |
| Asset autoloading | `src/autoload.vfx` |
| Backtick syntax sugar | `forge/backtick.vfx` |
