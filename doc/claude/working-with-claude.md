# Working With Claude — a delegation checklist

A reminder to myself (Roger) about when to hand work to Claude, when to keep the
pen, and — when I do delegate — what a prompt must contain so the result doesn't
need the kind of manual rework `level.vfx` did.

This is about the shape of the collaboration, not about it being an AI.

---

## The split

**Claude is reliable at:**
- Bespoke, self-contained machinery with a local, checkable contract — collision
  math, NIBS internals, spritebanks, tilemap helpers, a single well-specified word.
- **Changing and maintaining an existing contract** — refactors, extensions, edits
  to code whose shape is already established.
- Pure advisory work with no code from it — bug-spotting, knowledge, judgment.

**Claude is unreliable at:**
- Integrating into a whole system — ownership, lifecycle, where data belongs, API
  cohesion.
- The compile-time / runtime paradigm (autoloads, defining words, build-at-
  definition, templates, on-built). It defaults to runtime assumptions.
- Holding the project gestalt — applying all the paradigms, principles, and style
  consistently at once.

**Why:** left to improvise an underspecified task, its instinct is to *make it
work*. It optimizes toward the only thing it can verify closes — compiles / runs /
test passes. Maintainability and usability have no signal it can close against, so
it collapses to the narrowest reading it can confirm and silently skips them. They
aren't weighed and discounted; nothing tells it whether it hit or missed.

---

## Do it myself vs. delegate

**Do it myself when:**
- The work is exploratory and the design is still forming (mogogame — one day, lots
  of rapid course changes).
- Explaining the contract would cost more than writing the code.
- I want maximal tightness — my code will be tighter than a delegated round-trip,
  because the design lives in my head and a prompt almost always falls short of it.

**Delegate when:**
- Changing / extending / maintaining an **already-established** contract.
- Mechanical refactors across many call sites.
- A bespoke, self-contained piece with a clear spec.
- Bug-hunting or design review (no code — use it as a reviewer/oracle freely).

The sweet spot: **I write the contract for complex low-level machinery; Claude
changes and maintains it.**

---

## The delegation contract — include these or expect revision

The `level.vfx` rework went sideways because the prompt carried the *what* but not
the system constraints. To avoid that, a delegation needs:

1. **Signature / contract.** Stack effects, protocol signatures, types, in/out.
   (My strength; it executes this well.)

2. **Ownership & lifecycle.** Who allocates, who frees; dict vs. heap; behavior
   across hot-reload / reset; and *when the code runs* — compile-time/definition vs.
   runtime, and which phase (`construct` / `start` / `load` / `build`). Unstated, it
   assumes runtime and writes leak-prone "make it work" allocation.

3. **Where the state lives.** Which object / class / module owns each datum. It
   won't reliably pick the right home (spawners belong on the tileset, not the
   level — that was non-obvious to it).

4. **The call site (usability target).** Show how it should *read* at the call
   site. It optimizes toward whatever compiles unless the call site is the named
   goal.

5. **Invariants (maintainability target).** The non-negotiables: "no global mutable
   side-channels," "must not leak across reload," "must round-trip with the editor,"
   "same-named property = same logical thing." These have no internal signal for it;
   unstated = skipped.

6. **Exemplar to mirror.** Point at the file or word whose idioms and style to
   match. It matches local patterns well; it does not infer the gestalt.

7. **Scope fence.** What NOT to touch. Prevents cascading changes.

Items 4 and 5 are the ones I'll forget to write and then be annoyed about — they're
exactly the axes it can't sense on its own.

---

## Reviewing its output

- "It compiles" is not "it's right." Check the invariants explicitly, not just
  behavior.
- **High locals usage** = it was reasoning step-by-step instead of thinking in the
  language's idioms. A smell.
- The worse case is the opposite: terse, idiomatic-*looking* code that quietly
  breaks a system invariant. Locals count won't catch it — read for ownership and
  lifecycle.
- **Don't trust its prose about authorship or history.** It will narrate "I wrote
  X" / "I had Y" about code it only reviewed, to build a tidy story. Verify against
  the diff, not its narration.

---

## One-line version

It will make it *work*. Whether it's maintainable and usable is on me to specify or
to catch — so either name those axes in the prompt, or review for them. Naming them
turns "make it work" into "make *this* work."
