# The Step Change: You Stop Being the Event Loop

## The idea

Almost every agent-harness improvement (verifiers, security levels, multi-model
debate, observability) improves the *quality per turn* of an agent you sit in
front of. That compounds, but keeps the same shape: one human, serially
prompting, waiting, reading, correcting. The binding constraint is not model
capability or harness quality — it is **your attention**.

A step change, by definition, changes the constraint. The only thing that does
that is a system where work enters a queue, gets executed, verified, and lands
as reviewable output without you in the middle. Your job collapses to two
inputs:

1. **What to build** — well-specified, queue-able tasks.
2. **What counts as done** — acceptance rules the verifier enforces.

Three pillars make this work:

1. **Autonomous execution** — headless pi goal runs + autonomous system prompt
   (mostly already built).
2. **Automated acceptance** — the verifier extension (spec:
   `specs/verify-extension.md`). This is the load-bearing trust layer:
   unattended execution without automated acceptance just produces slop
   faster.
3. **Private evals over your own work** — keep every (task, result, verdict)
   triple the system produces. That corpus becomes a regression suite for the
   harness itself: every change (new prompt, cheaper model, new verifier rule)
   becomes measurable against your real task distribution instead of vibes.
   It is also what lets you push most tasks down to cheap/local models with
   proof they pass your acceptance bar.

Once all three exist, a flywheel forms: tasks flow unattended → the verifier
accepts/rejects → every outcome enriches the eval corpus → the corpus lets you
improve the harness and cheapen the models → which lets you queue more task
types. That loop compounds **without your time as the input** — the actual
definition of a step change here.

## The diagram

```
                          THE STEP CHANGE: YOU STOP BEING THE EVENT LOOP
 ═══════════════════════════════════════════════════════════════════════════════════

   BEFORE (attention-bound)                      AFTER (queue-bound)
   ┌─────────────────────────┐                   ┌─────────────────────────┐
   │  you → prompt → wait →  │                   │  you → define work +    │
   │  read → correct → wait  │                   │  define "done", then    │
   │  ... (serial, all day)  │                   │  review what lands      │
   └─────────────────────────┘                   └─────────────────────────┘
   constraint: YOUR ATTENTION                    constraint: TASK SUPPLY


                                YOUR TWO JOBS (only inputs)
                ┌──────────────────────┐     ┌───────────────────────────┐
                │  WHAT to build       │     │  what counts as DONE      │
                │  (well-specified     │     │  (acceptance rules in     │
                │   tasks)             │     │   VERIFIER.md)            │
                └──────────┬───────────┘     └────────────┬──────────────┘
                           │                              │
 ══════════════════════════▼══════════════════════════════▼═════════════════════════
                           │        THE MACHINE           │
                           ▼                              │
                ┌─────────────────────┐                   │
                │  ① TASK QUEUE       │                   │
                │  dir of task .md    │                   │
                │  files / gh issues  │                   │
                └──────────┬──────────┘                   │
                           │ drained overnight            │
                           ▼                              ▼
                ┌─────────────────────┐  work   ┌─────────────────────┐
                │  ② EXECUTION        │────────▶│  ③ ACCEPTANCE       │
                │  headless pi        │         │  verifier extension │
                │  goal runs +        │◀────────│  (read-only, cold   │
                │  APPEND_SYSTEM.md   │ bounded │  context, claims-   │
                │  [mostly built ✓]   │ retries │  based)  [spec ✓]   │
                └─────────────────────┘         └────┬───────────┬────┘
                                                    fail        pass
                                                     │           │
                                     rejected, ◀─────┘           ▼
                                     logged why          ┌───────────────┐
                                          │              │ branch/PR     │
                                          │              │ lands for     │
                                          │              │ morning review│
                                          │              └───────┬───────┘
                                          │                      │
 ═════════════════════════════════════════▼══════════════════════▼══════════════════
                                THE FLYWHEEL (compounds without you)
                          ┌────────────────────────────────────┐
                          │  ④ EVAL CORPUS                     │
                          │  every (task, result, verdict)     │
                          │  triple, logged from day one       │
                          └──────────────┬─────────────────────┘
                                         │ your real task distribution
                                         │ = private regression suite
                                         ▼
                          ┌────────────────────────────────────┐
                          │  ⑤ MEASURED HARNESS CHANGES        │
                          │  new prompt? verifier rule? swap   │
                          │  gpt-5.5 → local qwen? → run evals,│
                          │  keep only what scores             │
                          └──────────────┬─────────────────────┘
                                         │ cheaper models + higher trust
                                         ▼
                          ┌────────────────────────────────────┐
                          │  ⑥ MORE TASK TYPES QUEUE-ABLE      │
                          │  wider scope runs unattended ──────┼──┐
                          └────────────────────────────────────┘  │
                                         ▲                        │
                                         └──── back to ① with ────┘
                                               bigger appetite

 ═══════════════════════════════════════════════════════════════════════════════════
  BUILD ORDER          ③ verifier → ④ start logging → ① dumb queue → ⑤⑥ fun stuff
                       (trust gate)  (free now,        (a directory   (fusion, p2p —
                                      costly later)     is enough)     only if evals
                                                                       say they help)

  FAILURE MODE TO WATCH: the machine stalls at ① — not plumbing, but running out
  of well-specified tasks. Under-specified intent is the one thing ③ can't check.
```

How to read it: everything above the double line is the only place your
attention goes; everything below runs on its own. The verifier (③) is
deliberately the first brick because both loops — the nightly work loop and
the improvement flywheel — pass through it.

## Second-order effect

Once execution is cheap and unattended, the bottleneck moves to **task supply
and specification**. The scarce skill stops being "operating an agent well"
and becomes "decomposing goals into queue-able, verifiable tasks". Most agent
factories stall there, not on plumbing: under-specified tasks are exactly
where verifiers cannot save you, because you cannot verify against an intent
that was never written down.

## Build order

1. **Verifier** (`specs/verify-extension.md`) — the trust gate; nothing else
   matters without it.
2. **Log (task, result, verdict) triples from day one** — the eval corpus
   costs nothing to collect and everything to reconstruct later.
3. **Wire a dumb queue** — a directory of task markdown files or GitHub
   issues that a goal-run pi drains overnight, verifier-gated, landing
   branches for morning review.
4. **Fun stuff last** (multi-model fusion, p2p comms) — as *measured*
   upgrades against the evals, not vibes.

One-sentence version: the game changer is not a smarter agent — it is a
system where your attention is spent only on *what to build* and *what counts
as done*.
