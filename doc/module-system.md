# Module System

Provides per-module public/private wordlists, explicit imports, reexports, circular-import detection, and qualified module access.

---

## Declaring / Entering a Module

```forth
module [name]
```

Creates the module if it doesn't exist; otherwise re-enters it. Both cases set the search order and compilation target for the remainder of the file (or until the next `module` / `global`).

**Re-entry is intentional.** The same `module [name]` that declares a module can be written in a second file to add words to it, in a build script to bring it into scope, or at the REPL for interactive access.

**Filename fallback.** A bare `module` with no bracketed name uses the current source file's basename as the module name.

**Qualified names in files.** A file may declare a module name whose basename differs from the filename — for example, `al-utils.vfx` declaring `module [allegro5.utils]`. In this case `import path/to/al-utils.vfx` will correctly find the declared module even though the name doesn't match the filename.

---

## Sections

| Word | Compilation target | Search order |
|------|-------------------|--------------|
| `private` | `priv-wl` | priv, pub, imports, forth |
| `public` | `pub-wl` | priv, pub, imports, forth |
| `forth-public` | `forth-wordlist` | priv, pub, imports, forth |
| `\|\|` | `priv-wl` for one line, then restores | — |

Default after `module` is private (compilation target = `priv-wl`).

**`forth-public`** is for words that must be globally visible — extern declarations, C struct field accessors — anything that needs to land in the Forth wordlist rather than the module's public wordlist.

**`||`** is a single-line private escape. Useful for helper values or words that need to interleave with public definitions without a full `private` / `public` toggle.

**`global`** exits module context entirely (`only forth definitions`, `current-module` = 0). Use for code that must be at the Forth top level.

---

## Imports

```forth
import [name]                    \ by name (loads %idir%/name.vfx if not yet loaded)
import path/to/file.vfx          \ by explicit path
import: [a] [b] [c] ;            \ batch syntax
```

- Adds `name`'s public wordlist (and its reexports) to the current search order.
- Idempotent: importing the same module twice has no effect. `import-as` also skips the file load if the module is already registered.
- Triggers load if the module hasn't been declared yet. The file must contain a `module` declaration or an error is thrown.
- **Circular imports are detected** and abort with an error. The check is transitive: if A imports B and B imports C, then C cannot import A.

### `import-as`

```forth
import-as path/to/file.vfx [localname]
```

Loads the file with its full path as the registry key, then creates a `[localname]` alias in the current module's private wordlist. This lets you load the same file multiple times under different names (e.g., two instances of the same component).

---

## Reexports

```forth
reexport [name]
reexport: [a] [b] ;   \ batch syntax
```

Makes an already-imported module's public wordlist visible to any module that imports the current one. Used to bundle dependencies: `engineer.vfx` imports `allegro5.vfx` and reexports `[allegro5]`, so callers of `[engineer]` automatically get the Allegro bindings.

Only directly or transitively accessible modules can be reexported.

Reexports are **transitive**: if A reexports B and B reexports C, then importers of A also see C's public words.

Modules imported via `import-as` (which live as aliases in the private wordlist) can also be reexported using their bracketed local name.

---

## Accessing Module Words

```forth
[name] word
```

The bracketed module name is an immediate word. When executed:
- If already inside that module: no-op (word is parsed normally by the current search order).
- If the module is not imported: aborts with "not imported".
- Otherwise: parses the next word and interprets it in the module's **public** wordlist.

```forth
[forth] word
```

Special form: interprets `word` in the Forth wordlist directly. Use to call a global word that would otherwise be shadowed.

---

## REPL Navigation: `^`

```forth
^ name
^ path/to/file.vfx
```

Opens a module at the REPL: sets `current-module` to it and rebuilds the search order. Brackets are not required. If the module isn't loaded yet, the file is included first (the file must declare a `module`). `.vfx` extension is optional for bare names.

`^` never creates a new module — it aborts if the file doesn't declare one.

```forth
^ tilemap          \ opens [tilemap] (loads %idir%/tilemap.vfx if needed)
^ engine/foo.vfx   \ opens module declared in that file
```

---

## Package System (Dotted Names)

Module names may contain dots:

```forth
module [foo.bar]
```

The parent prefix (up to the last dot — `foo` for `foo.bar`) becomes the **current package**. Subsequent bare-name `import`s are tried package-qualified first:

```forth
import [baz]    \ looks for [baz] first, then [foo.baz]
```

This allows package-relative imports without fully qualifying every name.

---

## Search Order Detail

`build-module-search-order` sets:

```
priv-wl  ← compilation target
pub-wl
imported pub-wls (+ their reexports, recursively)
forth-wordlist
```

Imports are added in declaration order; later imports shadow earlier ones (list is walked tail-first so last-declared has highest priority).

---

## Interactive Access: `^`

```forth
^ [name]          \ scope into an already-loaded module
^ path/file.vfx   \ load file if not yet loaded, then scope into its module
```

Designed for REPL debugging. Sets `current-module` and builds the module's search order so you can call its private words interactively. If the module isn't loaded yet, includes the file first (once only — won't reload).

---

## Diagnostics

```forth
[name] module.   \ prints module name and its direct imports
```

---

## `include` / `require` Behavior

The module system wraps `include`, `require`, and `included` to save and restore `current-module` and `current-package` across file loads. Sub-files loaded during an include chain don't corrupt the outer module context.

---

## Examples

### Single-file module

```forth
module [mymod]

private
: helper  ." private" cr ;

public
: thing   helper ." public" cr ;
```

### Multi-file module (add words in a second file)

```forth
\ second-file.vfx
module [mymod]    \ re-enters existing module

public
: more-stuff  ." added later" cr ;
```

### Importing and reexporting

```forth
module [engine]

import [allegro5]
reexport [allegro5]   \ callers of [engine] see allegro5 automatically

import [mymod]
```

### Batch imports

```forth
module [game]

import:
    [engine]
    [physics]
    [audio]
;
```

### `import-as` for multiple instances

```forth
module [main]

import-as lib/component.vfx [comp-a]
import-as lib/component.vfx [comp-b]

[comp-a] init
[comp-b] init
```

### `||` single-line private

```forth
module [foo]

public
|| value internal-counter   \ private despite being between public definitions
: increment  internal-counter 1+ to internal-counter ;
```

### `forth-public` for extern declarations

```forth
module [window]

forth-public
HWND GetForegroundWindow EXTERN
void SetForegroundWindow ( HWND ) EXTERN

public
: focus?  GetForegroundWindow display = ;
```
