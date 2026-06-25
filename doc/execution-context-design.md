# Execution Context Design Problem

## Overview

VFXLand5 implements execution contexts (ECs) to allow objects to have environment-like state that can be inherited through a stack of scopes. EC fields (like variables) can "inherit" values from parent contexts when not explicitly set.

## Core Mechanism

### Object Structure
Each object has an `ecp` (execution context pointer) field:
```forth
0
    cell field cla   \ class pointer
    cell field ecp   \ execution context pointer
dup constant s/objectbase
    cell field magic
constant s/magicbase
```

### EC Fields
Defined with `ec-cell`:
```forth
ec-cell fnt    \ Creates fnt@ (getter) and fnt! (setter)
```

Fields store values in the execution context, not in the object itself:
- `fnt!` stores at `ecp + offset`
- `fnt@` searches for value via `>ecfa`

### Inheritance via >ecfa

The `>ecfa` function searches up the **object stack** for non-sentinel values:

1. Check current object's EC at `ecp + offset`
2. If value is `$DEADBEEF` (sentinel), search up object stack
3. Check previous object's EC for the field
4. Repeat until finding a non-sentinel value or reaching stack bottom

**Key insight**: Inheritance works through the object stack (`osp`), not through EC chaining.

## The Design Problem

### Initial Approach: c{ and {{

Originally provided two ways to switch contexts:

```forth
c{ ( ec - )   \ Switch current object's ecp to new EC
c}           \ Restore previous ecp

t{           \ Create temporary EC, switch to it
t}           \ Restore and discard temp EC
```

**Problem**: These change the current object's `ecp` field without pushing a new object onto the object stack.

### Why This Breaks Inheritance

Example test case:
```forth
\ Setup
ec-cell fnt
123 fnt!              \ Store in rootec (global's default EC)

econtext test-ec
test-ec c{ -1 fnt!  c}  \ Store -1 in test-ec

\ Later...
test-ec c{
    fnt@ .            \ Expected: 123 (inherit from rootec)
                      \ Actual: -1 (only sees test-ec)
c}
```

What happens:
1. `global` object has `ecp = rootec` initially
2. `test-ec c{` changes global's ecp to test-ec (overwrites rootec reference)
3. Object stack still only has one object: global
4. `>ecfa` searches up object stack, finds nothing (only global)
5. Can't find rootec anymore - no inheritance!

### Attempted Solutions

#### 1. Global ECP Pointer (Rejected)

Make `ecp` a global value (like `me`) instead of reading from `me ecp @`:
```forth
0 value current-ec

: ecp@ ( - ec ) current-ec ;
: ecp! ( ec - ) dup to current-ec  me ecp ! ;  \ Update both!
```

**Problem**: Coherence nightmare
- `ecp!` (the word) must update both global and object field
- `{` must sync global ecp with new object's ecp field
- Easy to get out of sync
- Confusing semantics

#### 2. Smart Copy for {{ (Complex)

Have `t{` copy non-sentinel values to temp EC:
- Copy all `$DEADBEEF` → keep searching
- Copy actual values → use them
- Allows inheritance through copied sentinels

**Problem**: Complex copy logic, unclear semantics

#### 3. Use Object Stack Properly (Current Direction)

Just use object scoping correctly:
```forth
global {             \ Push global onto object stack
    other-obj {      \ Push other-obj with different EC
        fnt@ .        \ Can inherit up the object stack
    }
}
```

**Advantage**:
- Works with current >ecfa implementation
- Simple, clear semantics
- EC inheritance via object stack is explicit

**Trade-off**:
- Must push objects to get EC inheritance
- Can't switch EC of current object for inheritance
- c{ and {{ become useless or misleading

## Current Resolution

### Keep It Simple
- ECP is object-field-only (no global pointer)
- Comment out c{ and {{ to avoid confusion
- EC switching requires object scoping with `{` ... `}`
- Each object carries its own EC, inheritance via stack

### Future Consideration
If lightweight EC switching is needed without full object scoping, consider:
- Making EC a separate stack-based concept (disconnected from objects)
- Or: shallow copy semantics for {{ (snapshot, no inheritance)
- Or: EC parent chain (each EC has parent pointer)

## Implementation Notes

### Key Functions
- `ecp@` → `me ecp @` (read current object's EC pointer)
- `ecp!` → `me ecp !` (set current object's EC pointer)
- `>ecfa` → search object stack for EC field value
- `{` / `}` → push/pop objects (and implicitly their ECs)

### Sentinel Pattern
- Unset EC fields contain `$DEADBEEF`
- `>ecfa` treats sentinels as "not set, search parent"
- First non-sentinel value up the stack is returned

### Default Context
- `rootec` is the global default EC
- Created at nib2.vfx load time
- Classifiers get `ecp = rootec` by default
- Objects inherit EC from their class template

## Lessons Learned

1. **Object stack is the inheritance chain** - trying to bypass it breaks the model
2. **Global state coherence is hard** - keeping global ecp synced with object fields adds complexity
3. **Explicit is better** - requiring `{` for scoping makes inheritance path clear
4. **Field-only design is simpler** - ecp as pure object field avoids synchronization issues
