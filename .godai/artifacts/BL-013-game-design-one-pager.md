# DANTE TERMINAL - Game Design One-Pager

> **BL-013** | Created: 2026-03-25 | Audience: founding team + AI Game Master prompt design
>
> Purpose: Define what playing DANTE TERMINAL actually feels like before coding the game loop (BL-005). This document is the shared design vision that prompt engineering, context management, and content planning all reference.

---

## 1. Core Loop Anatomy

### What Happens Each Turn

A single turn follows this exact sequence:

1. **Player acts.** Types a freeform natural language command or taps one of 3 suggestion chips.
2. **GM narrates.** The AI Game Master responds with a narrative paragraph describing what happens, advancing the story. The response streams character-by-character via the typewriter effect.
3. **World updates.** Behind the scenes, the game state (location, inventory, quest flags) is updated based on the GM's response.
4. **Suggestions appear.** Exactly 3 contextual action suggestions fade in below the narrative, giving the player clear forward momentum if they're stuck.
5. **Loop.** Player reads, decides, and acts again.

The player should never be stuck asking "what do I type?" Suggestions ensure forward motion. But freeform input is always available and encouraged — the suggestions are a floor, not a ceiling.

### Pacing Targets

These numbers are derived from technical constraints (BL-014 latency budget, BL-012 context collapse findings) and UX research on mobile reading behavior.

| Metric | Target | Hard Limit | Rationale |
|--------|--------|------------|-----------|
| **Words per GM response** | **60-90 words** | 120 words max | At 4-8 tok/s decode (BL-014 floor), 80-120 tokens takes 10-30s to generate. 60-90 words (~80-120 tokens) streams in a comfortable reading-speed window. BL-012 found Phi-3 produced 350-500 tokens unconstrained — must be capped. Mobile screens show ~50-60 words without scrolling; staying under 90 keeps the latest response fully visible. |
| **Turns per session** | **15-25 turns** | 30 turns max | A satisfying play session on mobile is 10-15 minutes. At ~30-45 seconds per turn cycle (read + think + type + generate), 15-25 turns fills that window. Context window management (BL-020) must sustain coherence across this range. |
| **Sessions per adventure** | **3-6 sessions** | 8 sessions max | A complete adventure spans 60-120 total turns (3-6 sessions x ~20 turns). This is long enough for meaningful narrative arc but short enough to feel completable in a week of casual play. Saves between sessions are mandatory. |
| **Suggestion word count** | **3-7 words each** | 10 words max | Suggestions must be scannable at a glance. "Examine the locked chest" not "Walk over to the old wooden chest in the corner and try to open it." |
| **Time-per-turn (wall clock)** | **25-40 seconds** | 60 seconds max | TTFT (<=3s) + streaming (10-20s) + player reading/deciding (10-15s). If a turn exceeds 60s, the pacing is broken. |

### Tone & Voice

The Game Master persona: **sardonic, atmospheric, fair.** Think a combination of the Zork narrator's dry wit and a noir detective's economy of language. The GM should:
- Describe scenes with sensory specificity (sound, smell, texture) not generic fantasy prose
- Acknowledge creative player inputs with genuine consequences, never "you can't do that"
- Maintain tension through what is *not* described (what's behind that door?) rather than exposition dumps
- Reward exploration and lateral thinking over brute-force approaches

---

## 2. Adventure Structure

### How an Adventure Begins

Every adventure starts with the **Cold Open**: the player is dropped into a situation with no preamble. No character creation screen. No "you are a brave hero." The first GM response establishes:

1. **Where you are** — a concrete, vivid location (a rain-slicked fire escape, a collapsed tunnel, a frozen cargo bay)
2. **What's wrong** — an immediate tension (an alarm, a locked door, a sound you can't explain)
3. **What you have** — one or two starting items mentioned naturally ("your flashlight cuts a weak beam through the dust")

The player is acting within 10 seconds of starting. Zero friction from concept to play.

### Adventure Progression: The Three-Act Arc

Adventures follow a **three-act structure** enforced by the GM system prompt via quest flag checkpoints:

**Act I: Orientation (turns 1-8)**
- Establish setting, introduce 1-2 key characters or environmental mysteries
- Player collects 2-3 essential items and learns the core mechanic of this adventure's genre
- Ends with a **revelation** — a discovery that reframes what the player thought was happening
- Gate: the player cannot progress to Act II without triggering at least one key discovery flag

**Act II: Escalation (turns 9-18)**
- Stakes increase. New areas open. The central puzzle or threat becomes clear.
- Introduce a **complication** — something that makes the obvious solution not work
- Player must combine items, information, or NPC relationships in non-obvious ways
- A **midpoint reversal** around turn 12-14 raises tension (ally betrayal, environment shift, resource loss)
- Gate: player must solve at least one major puzzle to reach Act III

**Act III: Resolution (turns 19-25+)**
- The final challenge. All threads converge.
- Multiple valid endings based on accumulated state (items held, NPCs helped/ignored, paths chosen)
- The ending should feel earned — a consequence of choices, not a coin flip

**Total: 20-30 turns for a complete adventure.** This fits in 1-2 sessions for fast players, 3-4 for explorers.

### Win/Fail Conditions

DANTE TERMINAL does **not** use hard failure states. The adventure always continues, but outcomes vary in quality:

| Outcome | Trigger | Player Experience |
|---------|---------|-------------------|
| **Triumph** | Player solved the central challenge with skill and creativity | Satisfying narrative climax, clear victory, hint at deeper lore |
| **Survival** | Player reached the end but missed key discoveries or took brute-force path | Bittersweet ending — you made it out, but at what cost? Questions unanswered |
| **Pyrrhic** | Player made critical mistakes (lost key items, antagonized NPCs) | You "won" but the world is worse for it. Dark ending. |
| **Time-out** | Player hits turn 30 without resolving Act III | GM narrates a cliffhanger ending — "the tunnel collapses behind you, and everything goes dark. But you're still breathing." Adventure marked incomplete. |

No game-over screens. No "you died, restart?" The narrative always adapts and finds an ending. This keeps mobile sessions feeling productive — a player who picks up the game for 5 minutes should never lose progress or hit a wall.

### Branching vs. Linear

**Philosophy: wide paths, narrow gates.** Adventures are structurally linear (three acts, fixed ending zone) but *experientially* branching. The player feels like they're exploring freely because:

- Multiple valid approaches exist for every obstacle (fight, sneak, talk, hack, ignore)
- The GM adapts its narrative to whatever the player tries, even unexpected inputs
- The 3 suggestion chips gently steer toward the critical path without blocking alternatives
- Key items can be found via different routes (the key is in the office OR the guard has it OR you can pick the lock)

This avoids the "combinatorial explosion" problem that kills AI-driven branching narratives. The AI doesn't need to track 50 branching paths — it needs to track a flat state object (location, inventory, quest flags) and narrate responsively.

---

## 3. Genre/Theme Menu

DANTE TERMINAL launches with **4 adventure themes**. Each theme provides the GM with a different system prompt overlay that sets setting vocabulary, item types, NPC archetypes, and tonal register. The underlying three-act structure and turn mechanics remain identical.

### Theme 1: The Sunken Archive (Classic Dungeon Crawl)

You awaken on a stone floor, torch guttering, with no memory of how you descended this far. The Sunken Archive was once a vast underground library — now it's a labyrinth of flooded corridors, collapsed reading rooms, and things that have been reading in the dark for centuries. Your goal: find the Codex Umbra, the book that started the collapse, and bring it to the surface before the water rises to seal the final exit. Expect crumbling puzzles, rusted mechanisms, and a librarian who has been down here far too long to be entirely human. This is DANTE TERMINAL's flagship theme — the one that feels most like Zork, but with teeth.

### Theme 2: Cold Signal (Sci-Fi Survival)

Your cryopod opened 140 years early. The ship's AI is gone — not malfunctioning, *gone*, like something carved it out. Emergency lighting paints every corridor in red and the hull groans like it's breathing. You're 6.2 light-years from Earth with a crew of 2,000 still frozen and a distress signal that isn't coming from your ship. Cold Signal is isolation horror meets engineering puzzle: reroute power, access sealed compartments, piece together what happened from crew logs, and decide whether to answer that signal or run. The ship is the dungeon. Oxygen is your torch timer.

### Theme 3: Last Call at the Avalon (Noir Mystery)

It's 1947 and someone just died in the back office of the Avalon Club. You're not a detective — you're the bartender, and you have exactly one hour before the police arrive and this becomes someone else's problem. Everyone in the club tonight has a motive, everyone is lying, and the dead man's briefcase is missing. Last Call plays out in compressed real-time: each turn represents roughly 2-3 minutes of the hour, creating natural urgency without a literal timer. Interrogate patrons, search the premises, mix drinks to loosen tongues. The killer is in the room with you, and they know you're looking.

### Theme 4: Green Hell (Survival Horror)

Your research expedition's helicopter went down in uncharted rainforest. The pilot is dead, the radio is smashed, and something in the jungle has been making sounds that don't match any species in your field guide. Green Hell is about resource management and escalating dread: your supplies dwindle, the jungle closes in, and the "temple" your expedition was looking for might have been looking for you. This theme leans hardest into environmental description — humidity, rot, bioluminescence, the sound of something large moving through undergrowth. Survival means navigating the forest, rationing supplies, and deciding which warnings from your increasingly unreliable guide to trust.

---

## 4. Replayability Mechanics

### Mechanic 1: Procedural Variation Seeds

**How it works:** Each adventure start generates a **variation seed** — a randomized set of parameters that the GM system prompt consumes to vary the experience. For the Sunken Archive, this might shuffle:
- Which corridor is flooded vs. accessible at start (changes exploration order)
- Which of 3 possible item sets you begin with (torch + rope, vs. lamp + map fragment, vs. knife + empty vial)
- Which NPC variant appears (helpful ghost scholar vs. territorial cave creature vs. paranoid survivor)
- Which of 2-3 ending configurations is active (the Codex location, the final obstacle type)

**Why it drives repeat play:** A player who completed the Sunken Archive with the torch+rope start and ghost scholar will discover a meaningfully different experience on replay with the knife+vial start and territorial creature. The three-act skeleton stays stable (so the GM stays coherent) but the texture — what you find, who you meet, what works — changes enough to feel fresh. The player thinks "I wonder what happens if I start with the map fragment instead."

**Implementation:** The seed is a JSON object injected into the system prompt's world-state block. Example:
```json
{
  "seed": "archive-v2b",
  "starting_items": ["oil_lamp", "torn_map_fragment"],
  "flooded_zones": ["east_wing", "deep_stacks"],
  "npc_variant": "paranoid_survivor",
  "codex_location": "hidden_vault",
  "final_obstacle": "rising_water_timer"
}
```
The GM prompt instructs the model to incorporate these parameters into its narration naturally. The player never sees the seed — they just experience a different adventure.

### Mechanic 2: Discovery Codex (Persistent Cross-Adventure Progress)

**How it works:** Every adventure contains **hidden lore fragments** — optional discoveries that aren't required to complete the adventure but reward thorough exploration. When found, these are recorded in a persistent **Discovery Codex** that persists across all adventures and themes. Examples:
- In the Sunken Archive, finding a specific inscription reveals a name that appears in Cold Signal's crew manifest
- In Last Call, discovering the dead man's notebook contains coordinates that reference Green Hell's temple
- Each theme has 5-8 discoverable fragments, with 2-3 being cross-theme connections

The Codex is displayed as a "terminal database" accessible from the main menu — entries appear as redacted text until found, creating a visible completion tracker.

**Why it drives repeat play:** The Codex creates two overlapping motivations:
1. **Completionism within a theme** — "I finished the Sunken Archive but only found 3 of 7 fragments. Let me replay to find the rest." Combined with procedural variation, this makes replays feel purposeful rather than repetitive.
2. **Cross-theme curiosity** — "The name I found in the Archive appeared in Cold Signal. Are all four themes connected?" This creates a meta-narrative that rewards playing all themes rather than replaying one favorite.

**Implementation:** Lore fragments are defined as specific quest flags in the variation seed. The GM prompt includes instructions to reveal them only when the player performs a specific action in a specific location. Found fragments are stored in local device storage (a simple key-value map) and persist across adventure restarts.

### Mechanic 3: Escalating Difficulty Tiers

**How it works:** Each adventure theme has three difficulty tiers that modify the GM's behavior:

| Tier | Name | Changes |
|------|------|---------|
| **Tier 1** | Terminal Novice | Generous suggestions, hints embedded in descriptions ("the rust around the lock looks weak"), forgiving item usage (partial solutions accepted) |
| **Tier 2** | Operator | Standard play. Suggestions are less leading, descriptions are more ambiguous, puzzles require precise item combinations |
| **Tier 3** | Root Access | Minimal suggestions (replaced with atmospheric flavor text), descriptions actively mislead ("the door looks solid" but is actually rotten), additional hazards and red herrings, time pressure increased |

Tier 2 unlocks for a theme after completing it once at Tier 1. Tier 3 unlocks after Tier 2. This is per-theme — completing the Archive at Tier 1 doesn't unlock Tier 2 on Cold Signal.

**Why it drives repeat play:** Difficulty tiers multiply effective content by 3x without requiring new narrative material. The GM system prompt handles difficulty adjustments through tone and information control rather than branching — a higher tier doesn't add new rooms, it makes existing rooms harder to read. A player who breezed through the Archive at Tier 1 discovers a genuinely different challenge at Tier 3 where the "obvious" solution was a trap all along. Combined with procedural variation seeds, each theme supports 6-9 meaningfully distinct playthroughs (3 tiers x 2-3 seed configurations).

---

## Appendix: Design Constraints from Technical Research

This game design is shaped by empirical findings from the prototype phase. Key constraints:

| Constraint | Source | Design Impact |
|-----------|--------|---------------|
| Context collapses at ~2500 prompt tokens | BL-012 | Adventures must work within 1500-token safe zone. This drives short GM responses and aggressive context windowing. |
| 3B+ model required for quality | BL-012 | 1B models can't follow structured prompts. Budget for 2GB model file. |
| 4-8 tok/s decode on floor devices | BL-014 | 80-120 token responses take 10-30s. Streaming typewriter is mandatory. |
| <=3s TTFT | BL-014 | Cold opens must feel instant. First response can be slightly longer (player expects a loading moment). |
| Structured suggestion format not followed | BL-012 | Neither tested model produced the `> 1. [action]` format. Suggestions may need post-processing extraction or few-shot examples in prompt. |
| 1500 MB iOS memory budget | BL-014 | State tracking JSON must be tiny. No heavy auxiliary data structures. |
| Mobile session = 10-15 minutes | Industry data | 15-25 turns per session. Adventures must feel complete-able in multiple short sessions. |

---

## Cross-References

- **BL-005** (Game loop implementation) — consumes this document for prompt engineering, turn structure, and suggestion mechanics
- **BL-010** (AI Game Master prompt patterns) — research that will refine the GM persona and context management described here
- **BL-018** (Genre-specific prompt templates) — implements the 4 themes defined in Section 3
- **BL-020** (Sliding-window context management) — implements the context strategy required by the pacing targets in Section 1
- **BL-021** (Game state JSON schema) — implements the structured state tracking referenced in Sections 2 and 4
- **BL-022** (Retro UI design spec) — implements the visual presentation of the turn loop described in Section 1
