# HONE Word Design Discussion
*Session: 2025-07-30*

## User Question

i'm thinking about a new word HONE that does what UPDATE does, and potentially also make one or both of the following changes:

- UPDATE no longer enables honing.  HONE calls UPDATE and sets up honing to reload the class as UPDATE currently does
- HONE will be planned to be enhanced to "detect" what kind of item you're trying to hone.  so it can be used with classes, events, and other text-file-based assets.  currently RUN is used to load events and enables honing to reload the event with the F5 key which calls ?RELOAD > TRY-AGAIN

think through both ideas and discuss 

## Claude Response

Both ideas work well together and would improve the development workflow:

### Idea 1: Separate UPDATE and HONE

**Benefits:**
- **Cleaner separation**: UPDATE becomes a pure "reload once" operation, HONE becomes "iterative development mode" 
- **More explicit**: Developers know when they're entering honing mode vs just doing a one-shot reload
- **Flexible**: Can reload classes without setting up F5 honing if you just need a quick refresh

**Implementation:**
```forth
: update ( - <class> )  \ Just reload class and reinit instances, no honing
: hone ( - <class> )    \ Call update + set up F5 honing mode
```

### Idea 2: Smart HONE detection

**Excellent extension** - could detect asset type and set up appropriate honing:

**Detection logic:**
1. Look for `name%` class → class honing (current UPDATE behavior)
2. Look for `name` event → event honing (current RUN behavior) 
3. Future: bitmap files, audio samples, etc.

**Benefits:**
- Single entry point: `HONE ship`, `HONE test1`, `HONE background-music`
- Less cognitive overhead - one word for all iterative development
- Extensible to new asset types

### Combined approach:
```forth
UPDATE ship     \ Reload ship% once, no honing setup
HONE ship       \ Detect it's a class, reload + setup class honing  
HONE test1      \ Detect it's an event, setup event honing
HONE music.ogg  \ Future: detect audio file, setup audio honing
```

This preserves existing UPDATE functionality while making HONE the universal "I want to iterate on this thing" command. The detection makes the interface more intuitive - you don't need to remember whether something is a class, event, or other asset type.

## User Question

suggest a mechanism for extending HONE (and restoring it to the default fallback behavior on EMPTY)

## Claude Response

Here's a clean extension mechanism using a chain of detection handlers:

### Extension Mechanism

```forth
\ Chain of hone detection handlers
variable hone-chain  0 hone-chain !

: hone-handler: ( - <name> )
    \ Define a hone detection handler
    \ Stack effect: ( name-addr name-len -- handled? )
    create here hone-chain @ , hone-chain !
    does> cell+ @ execute ;

: try-hone-handlers ( name-addr name-len -- handled? )
    hone-chain @ begin ?dup while
        >r 2dup r@ cell+ @ execute if
            2drop r> drop -1 exit  \ handled
        then
        r> @  \ next in chain
    repeat
    2drop 0 ;  \ not handled

: hone ( - <name> )
    bl parse 2dup try-hone-handlers if exit then
    \ Default fallback - assume it's a class
    default-class-hone ;
```

### Built-in Handlers

```forth
hone-handler: try-class-hone ( name-addr name-len -- handled? )
    2dup f" %s%%" >pad find if
        2drop class-hone-setup -1
    else
        2drop 0
    then ;

hone-handler: try-event-hone ( name-addr name-len -- handled? )
    2dup s" events.vfx" search-file-for if
        2drop event-hone-setup -1  
    else
        2drop 0
    then ;

\ Future extensions:
hone-handler: try-bitmap-hone ( name-addr name-len -- handled? )
    2dup f" %s.png" fexists? if
        2drop bitmap-hone-setup -1
    else  
        2drop 0
    then ;
```

### Reset on EMPTY

```forth
: init-default-hone-chain ( - )
    0 hone-chain !
    \ Re-register built-in handlers in reverse order
    ['] try-bitmap-hone hone-chain link
    ['] try-event-hone hone-chain link  
    ['] try-class-hone hone-chain link ;

\ Add to existing EMPTY cleanup
: empty ( - )
    \ ... existing cleanup ...
    init-default-hone-chain
    \ ... rest of empty ... ;
```

### Benefits

- **Extensible**: Games can add `hone-handler: try-custom-asset`
- **Automatic restore**: EMPTY resets to default handlers
- **Order matters**: Handlers tried in registration order (most specific first)
- **Clean fallback**: If no handler matches, could either error or assume class
- **Inspectable**: Can walk the chain for debugging

Users can extend it easily:
```forth
hone-handler: try-music-hone ( name-addr name-len -- handled? )
    2dup f" %s.ogg" fexists? if
        2drop music-hone-setup -1
    else 2drop 0 then ;
```