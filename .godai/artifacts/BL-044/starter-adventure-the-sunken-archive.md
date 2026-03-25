# The Sunken Archive — Starter Adventure Scenario

> **BL-044** | Created: 2026-03-25 | Audience: Game Master prompt engineering (BL-005, BL-043), game loop implementation, content iteration
>
> Purpose: Provide the Game Master with a rich, pre-authored world context for DANTE TERMINAL's first playable adventure. Small models (1-3B params) improvise poorly (BL-036: 58-77% instruction compliance, near-zero structured output without grammar enforcement). Pre-authored locations, items, NPCs, and puzzle logic give the AI concrete material to narrate around rather than generating from scratch. This document is consumed as keyword-triggered lore entries (per BL-010 Section 2) and puzzle-state flags (per BL-013's quest flag system).

---

## 1. Setting and Premise

### Theme

**The Sunken Archive** — Classic dungeon crawl. An ancient underground library, partially flooded, where knowledge itself has become dangerous. Aesthetic: Zork's puzzle logic meets Lovecraftian knowledge-horror. The horror is intellectual, not violent — what you read changes you, and the Archive remembers everyone who enters.

### Era and Tone

Era is deliberately ambiguous — the Archive predates any civilization the player would recognize. Technology is pre-electric: oil lamps, brass mechanisms, hand-scribed texts. The tone is **atmospheric dread with dry wit**. The GM persona (sardonic, atmospheric, fair — per BL-013) manifests as a narrator who finds the player's predicament mildly amusing but not unsympathetic. Think: a librarian who has seen too many patrons wander into the wrong section.

### Premise

The player awakens on a cold stone floor at the bottom of a collapsed stairway. They don't remember descending. Above them, rubble seals the only exit they can see. Ahead, a vaulted corridor stretches into darkness. Their oil lamp — the only item in their possession — sputters but holds. Somewhere in the depths of this drowned library lies the **Codex Umbra**, the book that caused the Archive's collapse. Bringing it to the surface is the only way out: the Archive was designed so that only the Codex can unseal the main door from inside. The water is rising. Slowly, but rising.

### Opening Narrative (Cold Open — First Thing the Player Reads)

> You wake on stone. Cold, damp, and wrong — the kind of cold that means you're underground and have been for a while. Behind you, the stairway is a wall of rubble. Your oil lamp sits beside you, flame low but stubborn. Ahead, a vaulted corridor exhales stale air that tastes of copper and old paper. Water pools in the cracks between flagstones, and somewhere ahead, something drips with metronomic patience. You don't remember coming down here. The Archive remembers you.
>
> > 1. Pick up the lamp and head into the corridor
> > 2. Search the rubble for anything useful
> > 3. Call out into the darkness

**Design notes:**
- Establishes location (underground), tension (trapped), item (oil lamp), and mystery (no memory) in 90 words
- The "Archive remembers you" line seeds the sentient-library theme without exposition
- All 3 suggestions advance the story — none are dead ends
- Player is acting within 10 seconds of starting (BL-013 cold open requirement)

---

## 2. Location Map

### Overview

The Sunken Archive contains **9 interconnected locations** (numbered 0-8) arranged in a roughly north-south grid. The player starts at the southernmost point (Antechamber) and must reach the northernmost (Vault of the Codex) through exploration and puzzle-solving. Water level rises gradually — by Act III, the two lowest-elevation locations (Flooded Passage, East Wing) become hazardous, creating urgency.

### Graph Structure

```
                    [8. Vault of the Codex]
                            |
                    [7. Restricted Section]
                            |
    [6. Reading Room] -- [5. Circulation Desk] -- [4. Flooded Passage]
          |                   |                          |
    [3. West Wing]  -- [2. Main Hall]        --  [1. East Wing]
                            |
                    [0. Antechamber] (START)
```

### Location Details

---

#### 0. The Antechamber (START)

**Keyword triggers:** `antechamber`, `start`, `entrance`, `stairway`, `rubble`

**Description:** A low-ceilinged chamber at the base of a collapsed stairway. Rubble blocks the way up — stones too heavy to move by hand. Water seeps through the debris, pooling in depressions on the floor. A faded mosaic on the floor shows an open book surrounded by chains. The air is still. One corridor leads north.

**Atmosphere:** Claustrophobic. The silence is the loudest thing here. The mosaic is the first hint that the Archive was deliberately sealed.

**Exits:**
- **NORTH** → Main Hall
- **UP** → Collapsed stairway (blocked; becomes the win-condition exit in Act III when player uses the Codex)

**Discoverable details:**
- The mosaic inscription reads: *"What is shelved is preserved. What is read is released."* (Foreshadows the Codex's danger)
- A leather strap half-buried in rubble — remnant of a previous explorer's pack (flavor, not item)
- Water on the floor is faintly warm (hint that the Archive has its own heat source below)

**Lore entry (~60 tokens):**
```
[LOCATION: Antechamber] Collapsed stairway, rubble blocks exit upward. Floor mosaic: open book in chains. Inscription: "What is shelved is preserved. What is read is released." Water seeps through debris. One corridor leads north to Main Hall. The Codex Umbra can unseal the stairway exit.
```

---

#### 1. The East Wing

**Keyword triggers:** `east wing`, `waterlogged`, `stacks`, `shelves`, `desk`

**Description:** The Archive's east wing is ankle-deep in dark water. Bookshelves lean at drunken angles, their contents bloated and unreadable. A collapsed reading desk sits in the center — something metallic glints beneath it. The air tastes of copper and decaying paper. A faint current suggests the water flows from somewhere to the north.

**Atmosphere:** Ruined and melancholy. This was once a place of quiet study. The water makes every step loud.

**Exits:**
- **WEST** → Main Hall
- **NORTH** → Flooded Passage

**Discoverable details:**
- The metallic glint under the desk is the **Brass Key** (Item #2)
- One shelf still holds a readable book: a catalog of Archive procedures mentioning "the Cipher for Restricted texts" (hints at Cipher Wheel)
- The water is slightly acidic — prolonged wading ruins paper items (creates urgency for Act III escape)
- Scratches on the desk leg — tally marks. Someone was counting days.

**Lore entry (~55 tokens):**
```
[LOCATION: East Wing] Ankle-deep dark water. Leaning bookshelves, waterlogged books. Collapsed reading desk with metallic glint underneath (brass key). Water flows north toward Flooded Passage. One readable shelf mentions "the Cipher for Restricted texts." Exits: west to Main Hall, north to Flooded Passage.
```

---

#### 2. The Main Hall

**Keyword triggers:** `main hall`, `corridor`, `mosaic`, `fungus`, `hub`

**Description:** The Archive's central corridor stretches north and south beneath a vaulted ceiling. Bioluminescent fungus clings to the upper walls, casting a faint blue-green glow that makes the oil lamp feel redundant — but isn't. The floor is an elaborate mosaic depicting the Archive's construction: robed figures carrying books into a descending spiral. Water runs in a thin stream down the center, flowing south.

**Atmosphere:** Grand decay. The fungus glow gives everything an underwater feeling. The hall was designed to inspire awe; it still does, but the awe has curdled.

**Exits:**
- **SOUTH** → Antechamber
- **EAST** → East Wing
- **WEST** → West Wing
- **NORTH** → Circulation Desk

**Discoverable details:**
- The mosaic shows the Archive has **multiple levels** — the player is on the uppermost
- The bioluminescent fungus reacts to loud sounds (flickers, dims) — useful info for the Warden encounter
- A stone bench along the west wall has a name carved: "MAREN — 7th descent" (foreshadows the NPC)
- The stream flows south, implying a water source deeper in the Archive

**Lore entry (~55 tokens):**
```
[LOCATION: Main Hall] Central vaulted corridor. Bioluminescent fungus on ceiling casts blue-green glow, reacts to loud sounds. Floor mosaic shows robed figures carrying books into a spiral. Water stream flows south. Name "MAREN" carved on bench. Exits: south to Antechamber, east to East Wing, west to West Wing, north to Circulation Desk.
```

---

#### 3. The West Wing

**Keyword triggers:** `west wing`, `display case`, `manuscripts`, `dry`, `rare`

**Description:** Unlike its flooded counterpart, the West Wing is bone-dry. The air is warm and still — almost preserved. Glass display cases line the walls, most cracked or shattered. One case remains intact, holding three illuminated manuscripts with gilt edges that catch lamplight. A wooden cabinet in the corner has a drawer slightly ajar. The ceiling timbers creak overhead, warning of structural instability.

**Atmosphere:** Hushed, museum-like. The warmth feels deliberate, as if the Archive is protecting what's here. The creaking ceiling is a constant low-grade threat.

**Exits:**
- **EAST** → Main Hall

**Discoverable details:**
- The intact display case is sealed with a **wax stamp** matching the Archive's seal — breaking it triggers a faint vibration through the floor (the Archive notices)
- Inside the case: the **Archivist's Journal** (Item #3) — partially readable, contains clues about the Codex
- The ajar drawer contains a **Glass Vial of Solvent** (Item #4) — labeled in faded script
- Manuscripts in the broken cases are beautiful but fragile — touching them causes them to crumble
- A temperature difference: the wall behind the cabinet is noticeably warmer (hints at deeper levels)

**Lore entry (~55 tokens):**
```
[LOCATION: West Wing] Bone-dry, warm air. Glass display cases, most shattered. One intact case with wax seal holds the Archivist's Journal. Wooden cabinet with ajar drawer contains glass vial of solvent. Ceiling timbers creak — structurally unstable. Illuminated manuscripts crumble when touched. Exits: east to Main Hall.
```

---

#### 4. The Flooded Passage

**Keyword triggers:** `flooded passage`, `waist-deep`, `water`, `dark water`, `passage`

**Description:** The passage is waist-deep in black water. The walls narrow to barely shoulder-width, and the ceiling drops low enough that the lamp must be held at an angle. Sound distorts here — your own breathing comes back at you from unexpected directions. The water is cold and opaque. Something brushes your leg that might be a submerged shelf or might not be.

**Atmosphere:** Primal fear. The passage forces vulnerability — you can't move fast, can't see what's below, can't easily turn back. Every sound is suspect.

**Exits:**
- **SOUTH** → East Wing
- **WEST** → Circulation Desk

**Discoverable details:**
- A **Waterproof Satchel** (Item #5) hangs from a peg just above water level — easy to miss if the player isn't looking carefully
- Submerged beneath the water: the top of a stone shelf holding a sealed jar of **lamp oil** (extends oil lamp life — flavor/optional resource)
- Scratches on the walls at water level — someone passed through here recently (Maren's path)
- The water level has a visible high-water mark about a foot above current level (foreshadows rising)

**Lore entry (~55 tokens):**
```
[LOCATION: Flooded Passage] Waist-deep black water, narrow walls, low ceiling. Sound distorts. Waterproof satchel hangs on peg above water level. Submerged shelf holds sealed lamp oil. Scratch marks on walls. Visible high-water mark above current level. Exits: south to East Wing, west to Circulation Desk.
```

---

#### 5. The Circulation Desk

**Keyword triggers:** `circulation desk`, `desk`, `ledger`, `bell`, `catalog`

**Description:** A massive stone desk dominates this hexagonal chamber — the Archive's administrative heart. A leather-bound ledger is chained to the desk, open to a page filled with coded entries. A brass bell sits on the counter, incongruously polished. Behind the desk, floor-to-ceiling catalog drawers line the wall — hundreds of tiny brass-handled compartments. To the north, an iron gate blocks further progress.

**Atmosphere:** Bureaucratic order amid chaos. The desk is the one thing in the Archive that looks maintained. The bell is suspiciously clean.

**Exits:**
- **SOUTH** → Main Hall
- **EAST** → Flooded Passage
- **WEST** → Reading Room
- **NORTH** → Restricted Section (blocked by locked iron gate — requires **Brass Key**)

**Discoverable details:**
- Ringing the **brass bell** summons the Cataloger (NPC #2) — a spectral presence that manifests as a voice and a chill
- The ledger records every book ever checked out. The last entry reads: *"Codex Umbra — recalled to Vault. Seal renewed. Warden assigned. —A."*
- The catalog drawers are organized by a coded system. One drawer is labeled with a symbol matching the Cipher Wheel — pulling it reveals a note: *"The Warden responds to silence, not force."*
- Behind the desk, a small door (locked, no key exists — red herring) leads to a broom closet

**Lore entry (~65 tokens):**
```
[LOCATION: Circulation Desk] Hexagonal chamber with massive stone desk. Chained leather ledger with coded entries. Polished brass bell summons the Cataloger when rung. Catalog drawers line the wall. Iron gate north to Restricted Section (needs brass key). Ledger last entry: "Codex Umbra — recalled to Vault. Seal renewed. Warden assigned." Exits: south to Main Hall, east to Flooded Passage, west to Reading Room, north to Restricted Section.
```

---

#### 6. The Reading Room

**Keyword triggers:** `reading room`, `mural`, `dome`, `constellations`, `firepit`

**Description:** A domed chamber, the largest space in the Archive. Collapsed reading tables and overturned chairs litter the floor. The dome above is painted with a star map — constellations you almost recognize but that are subtly wrong, as if charting a different sky. A stone fire pit sits in the center, long cold, ringed with scorch marks that extend further than any normal fire should reach. A figure sits against the far wall, watching you.

**Atmosphere:** Vast, echoing, exposed. After the tight corridors, the openness feels vulnerable. The wrong constellations are deeply unsettling. The figure (Maren) adds human tension to the environmental dread.

**Exits:**
- **EAST** → Circulation Desk
- **SOUTH** → West Wing (via connecting passage along south wall)

**Discoverable details:**
- **Maren** (NPC #1) is here, sitting against the wall. She's been in the Archive for what she thinks is three weeks.
- The **Cipher Wheel** (Item #6) is hidden inside a hollowed-out book on the floor near the fire pit — Maren knows this but won't say directly
- The star map on the dome, when studied with the lamp held overhead, reveals a sequence of symbols — the same symbols that appear on the Codex's pedestal lock
- The scorch marks from the fire pit form a pattern — the Archive's seal, burned into the floor. Someone tried to destroy something here and failed.
- A reading table leg, when examined, has "TURN BACK" scratched into the wood in small letters

**Lore entry (~60 tokens):**
```
[LOCATION: Reading Room] Large domed chamber. Star map mural on dome — constellations that are subtly wrong. Collapsed tables and chairs. Cold stone fire pit with oversized scorch marks forming the Archive's seal. Cipher Wheel hidden in hollowed book near fire pit. Maren sits against the far wall. Exits: east to Circulation Desk, south to West Wing.
```

---

#### 7. The Restricted Section

**Keyword triggers:** `restricted section`, `chained books`, `chains`, `iron gate`, `warden`

**Description:** Beyond the iron gate, the architecture changes. The walls are rougher, older — carved from bedrock rather than built from stone blocks. Books are chained to their shelves here, spines facing inward so titles can't be read without pulling them out. The air is thick and warm, and the lamplight seems to lose reach, as if the darkness here is denser than elsewhere. A low hum vibrates through the floor.

**Atmosphere:** Oppressive, sacred, dangerous. This is where the Archive keeps what shouldn't be read. The chains on the books are not to prevent theft — they're to prevent escape. The hum suggests something alive or active below.

**Exits:**
- **SOUTH** → Circulation Desk (back through the iron gate)
- **DOWN** → Vault of the Codex (via a spiral staircase at the section's far end — accessible only after solving Puzzle 3: The Warden's Question)

**Discoverable details:**
- The chained books whisper when approached — fragments of their contents, bleeding through the covers. Not dangerous, but deeply unsettling.
- One book's chain is broken. The shelf where it sat is scorched. (This was the Codex Umbra's original shelf — it was moved to the Vault after it "woke up")
- The **Warden** (NPC #3) manifests here as a voice from the darkness when the player approaches the spiral staircase
- Wall inscriptions in coded text — decipherable with the Cipher Wheel. They read: *"The Codex opens for the one who carries its seal and speaks no claim of ownership."*
- The hum grows louder toward the staircase

**Lore entry (~60 tokens):**
```
[LOCATION: Restricted Section] Carved from bedrock. Books chained to shelves, spines inward. Air thick and warm. Darkness is unnaturally dense. Low hum from below. One shelf scorched — Codex Umbra's original location. The Warden manifests as a voice near the spiral staircase. Coded wall inscriptions. Exits: south to Circulation Desk, down to Vault (after Warden encounter).
```

---

#### 8. The Vault of the Codex

**Keyword triggers:** `vault`, `codex`, `pedestal`, `seal`, `final`

**Description:** A perfectly circular chamber at the bottom of the spiral staircase. The walls are polished obsidian — so smooth they reflect the lamplight like dark mirrors. In the center, a stone pedestal holds a book bound in black leather that seems to absorb light: the **Codex Umbra**. The pedestal's base is ringed with a combination lock — five rotating stone discs, each carved with the same symbols from the dome's star map. The hum is loudest here, resonating in your sternum. The book is waiting.

**Atmosphere:** Finality. Everything in the Archive has led here. The circular room feels like the inside of an eye. The Codex doesn't look dangerous — it looks patient. The reflections in the obsidian walls show you from angles that don't quite match your position.

**Exits:**
- **UP** → Restricted Section (via spiral staircase)

**Discoverable details:**
- The combination lock requires a 5-symbol sequence (solved with Cipher Wheel + star map clues)
- The Codex, once freed from the pedestal, is warm to the touch and heavier than it looks
- Taking the Codex triggers the Archive's final response: a deep rumble, and water begins entering the Vault from cracks in the obsidian walls — the timer starts for Act III escape
- The obsidian walls, when examined closely, contain text visible only from certain angles — the Archive's original charter, explaining it was built to contain dangerous knowledge, not preserve it
- The pedestal, once emptied, reveals an engraving: the same seal from the Antechamber mosaic — confirmation that the Codex is the key to the exit

**Lore entry (~60 tokens):**
```
[LOCATION: Vault of the Codex] Circular obsidian chamber. Stone pedestal with Codex Umbra — black leather book that absorbs light. Combination lock: five rotating stone discs with star-map symbols. Taking the Codex triggers water flooding. Obsidian walls show the Archive's charter. Pedestal engraving matches Antechamber seal. Exit: up to Restricted Section.
```

---

## 3. Items and NPCs

### Items

---

#### Item #1: Oil Lamp

**Keyword triggers:** `lamp`, `oil lamp`, `light`

**Found:** Player starts with it (mentioned in cold open).

**Pickup behavior:** Already in inventory. Cannot be dropped (it's the player's lifeline).

**Use behaviors:**
- **Passive:** Illuminates the current location. Descriptions reference lamplight. Without it, certain details are invisible.
- **Use on manuscripts (West Wing):** Holding the lamp close to the intact display case reveals hidden text on the Archivist's Journal — UV-reactive ink that glows under direct lamplight. This is how the player discovers the Codex's location hint.
- **Use on star map (Reading Room):** Holding the lamp overhead while studying the dome mural makes the symbol sequence visible — the star map symbols glow faintly when directly lit.
- **Resource note:** The lamp's oil is finite. Refueled by the sealed lamp oil found in Flooded Passage. If the player doesn't refuel, the lamp dims in Act III, making the escape harder (reduced descriptions, can't see hazards as clearly). Not a hard failure — just increased difficulty.

**Lore entry (~40 tokens):**
```
[ITEM: Oil Lamp] Player's starting item. Illuminates locations. Reveals hidden text when held close to manuscripts or star map. Finite oil — refuelable from Flooded Passage jar. Dims in Act III if not refueled.
```

---

#### Item #2: Brass Key

**Keyword triggers:** `brass key`, `key`, `metallic glint`

**Found:** East Wing — beneath the collapsed reading desk (the metallic glint).

**Pickup behavior:** Player reaches under the desk and retrieves a heavy brass key, corroded green but solid. The Archive's seal is cast into the bow. A tag attached to it reads *"Restricted — Return to Desk."*

**Use behaviors:**
- **Use on iron gate (Circulation Desk → Restricted Section):** Unlocks the gate with a groan of old metal. The gate swings inward. The key breaks off in the lock — no going back to lock it again. *(One-use item, consumed on use.)*
- **Use on anything else:** "The key doesn't fit" or "This isn't a lock" — straightforward rejection.
- **Show to Cataloger:** The Cataloger recognizes the key and provides additional context: *"Restricted access was revoked after the Codex incident. That key should have been destroyed."* (Flavor + lore)

**Lore entry (~35 tokens):**
```
[ITEM: Brass Key] Found under collapsed desk in East Wing. Opens iron gate to Restricted Section. Single use — breaks in lock after opening. Tagged "Restricted — Return to Desk." Archive seal on bow.
```

---

#### Item #3: Archivist's Journal

**Keyword triggers:** `journal`, `archivist`, `display case`

**Found:** West Wing — inside the intact display case. Player must break the wax seal to open the case (triggers a floor vibration — the Archive notices).

**Pickup behavior:** A leather-bound journal, dry and well-preserved. The handwriting is cramped and urgent. Most pages are in a coded language, but several passages are in plain text — the Archivist was losing the ability to encode as they wrote faster.

**Use behaviors:**
- **Read (anywhere):** Reveals key narrative information in stages:
  - *First read:* A passage about the Codex: *"It doesn't contain knowledge. It contains an appetite. We built the Vault to feed it safely — symbols from the old sky, the combination that calms it. Without the sequence, it wakes hungry."*
  - *Second read (after finding Cipher Wheel):* Using the Cipher Wheel on the coded pages reveals the 5-symbol pedestal combination, confirming what the star map shows. This is the redundant solution path — players who miss the star map can still solve the pedestal.
- **Show to Maren:** Maren recognizes the journal and reveals she's been looking for it. Unlocks her full dialogue tree (she'll tell the player directly about the Cipher Wheel's location and the Warden's weakness).
- **Show to Cataloger:** The Cataloger catalogs it instinctively: *"Archivist's Journal, personal. Classification: restricted. Overdue."* (Humor + flavor)

**Lore entry (~50 tokens):**
```
[ITEM: Archivist's Journal] Found in West Wing display case (must break wax seal). Contains coded and plain-text entries about the Codex Umbra. Plain text: "It contains an appetite." Coded pages reveal pedestal combination when decoded with Cipher Wheel. Maren recognizes it.
```

---

#### Item #4: Glass Vial of Solvent

**Keyword triggers:** `vial`, `solvent`, `glass vial`, `drawer`

**Found:** West Wing — in the slightly ajar cabinet drawer.

**Pickup behavior:** A small glass vial, half-full of amber liquid. The label is faded but legible: *"Archival Solvent — dissolves binding adhesive. Handle with care."*

**Use behaviors:**
- **Use on chained books (Restricted Section):** Dissolves the chain adhesive on one book, freeing it. The freed book contains a map of the Vault chamber showing the pedestal mechanism in detail — confirming it's a 5-disc combination lock. *(Optional — provides visual confirmation of the puzzle mechanic.)*
- **Use on wax seal (West Wing display case):** Dissolves the seal cleanly, allowing the case to open without triggering the floor vibration. The Archive doesn't notice. *(Alternative to breaking the seal — rewards exploration and lateral thinking per BL-013's design philosophy.)*
- **Use on anything else:** "The solvent has no effect on this" — limited utility, clear boundaries.

**Lore entry (~35 tokens):**
```
[ITEM: Glass Vial of Solvent] Found in West Wing cabinet drawer. Dissolves adhesives. Can silently open display case wax seal (avoids alerting Archive). Can free one chained book in Restricted Section. Half-full, limited uses.
```

---

#### Item #5: Waterproof Satchel

**Keyword triggers:** `satchel`, `waterproof`, `bag`, `peg`

**Found:** Flooded Passage — hanging from a peg just above the water level. Easy to miss if player rushes through.

**Pickup behavior:** A waxed leather satchel, designed to keep contents dry. The strap is frayed but functional. Inside: nothing but a faint smell of old paper. Someone used this to carry documents through the flooded areas.

**Use behaviors:**
- **Use to carry Codex Umbra (Act III escape):** The Codex must survive the return trip through rising water. Without the satchel, the Codex's pages dissolve in the acidic water of the East Wing during the escape, resulting in a **Pyrrhic** ending (you escaped, but the Codex is ruined). With the satchel, the Codex survives intact — **Triumph** ending possible.
- **Use to carry Archivist's Journal through water:** Protects the journal from water damage in the Flooded Passage. Without the satchel, the journal becomes unreadable after wading. *(Optional quality-of-life use.)*
- **Passive:** Once picked up, all paper items in inventory are protected from water. The game state flag `has_satchel` determines whether paper items survive water areas.

**Lore entry (~35 tokens):**
```
[ITEM: Waterproof Satchel] Found on peg in Flooded Passage (easily missed). Waxed leather, keeps contents dry. Critical for Act III: protects Codex Umbra from acidic water during escape. Without it, Codex dissolves — Pyrrhic ending only.
```

---

#### Item #6: Cipher Wheel

**Keyword triggers:** `cipher wheel`, `cipher`, `wheel`, `decoder`

**Found:** Reading Room — hidden inside a hollowed-out book near the fire pit. Maren knows its location but won't reveal it directly unless the player shows her the Archivist's Journal.

**Pickup behavior:** A brass disc with two concentric rings of symbols — an outer ring (the Archive's coding alphabet) and an inner ring (common letters). Rotating the inner ring aligns symbols to letters. It's warm to the touch.

**Use behaviors:**
- **Use on wall inscriptions (Restricted Section):** Decodes the inscriptions to read: *"The Codex opens for the one who carries its seal and speaks no claim of ownership."* — This is the clue for the Warden's question (Puzzle 3).
- **Use on Archivist's Journal (coded pages):** Decodes the journal's coded entries, revealing the 5-symbol pedestal combination. This is the redundant path for Puzzle 4 (alternative to the star map).
- **Use on ledger (Circulation Desk):** Decodes ledger entries, revealing a log of everyone who ever accessed the Codex. The last name: *"Maren. 7th descent. Access denied."* — reveals Maren has been here before and was turned away.
- **Use on catalog drawers (Circulation Desk):** Decodes the coded drawer labels, allowing the player to find specific information about the Archive's history (flavor/lore).

**Lore entry (~45 tokens):**
```
[ITEM: Cipher Wheel] Brass decoder disc, found in hollowed book in Reading Room. Decodes Archive script. Use on: Restricted Section inscriptions (reveals Warden clue), Archivist's Journal coded pages (reveals pedestal combination), Circulation Desk ledger (reveals Maren's history).
```

---

### NPCs

---

#### NPC #1: Maren

**Keyword triggers:** `maren`, `woman`, `survivor`, `figure`

**Location:** Reading Room (sitting against the far wall when the player first enters).

**Personality:** Paranoid, sharp, exhausted. Maren has been trapped in the Archive for what she estimates is three weeks (it's been longer — time moves differently down here). She was part of a scholarly expedition that went wrong. Her colleagues are gone — she won't say how. She speaks in clipped, guarded sentences and doesn't trust the player immediately. She's not hostile, but she's been alone long enough that human company feels more threatening than the dark. Underneath the paranoia is a genuine intellect and a dry humor that surfaces when she lets her guard down.

**Dialogue hooks:**
- **First meeting:** *"Don't. Come. Closer."* (Pause.) *"...Fine. You don't look like one of them. You look lost, which is marginally better."*
- **On the Archive:** *"It's not a library. Libraries let you leave. This is a stomach."*
- **On the Codex:** *"Everyone comes here for the Codex. Everyone. That should tell you something about the Codex."*
- **On the Cipher Wheel (if asked directly):** *"I know where it is. I also know what happens when you use it. You want both pieces of information, you bring me something worth trading."*
- **After receiving Archivist's Journal:** *"Archivist. That sanctimonious— yes, this is useful. The cipher tool is in a book that isn't a book, near the fire that wasn't a fire. The Reading Room. You're welcome."*
- **On the Warden:** *"Don't try to fight it. Don't try to trick it. It's been here longer than the books. It asks a question. Get it wrong, you don't die — you just wish you did for about an hour."*

**Interaction behavior:**
- Won't share critical information without receiving the Archivist's Journal first (trade mechanic — BL-013's "combine items, information, or NPC relationships" requirement)
- If player is aggressive or threatening: retreats deeper into the room and stops talking
- If player is patient and conversational: gradually reveals more background about the Archive and its dangers
- If player asks about her failed expedition: deflects twice, then admits on third ask that the Codex "showed them things" and they tried to destroy it (explaining the scorch marks in the Reading Room)

**Quest flags:**
- `maren_met` — Triggered on first encounter
- `maren_trusts` — Triggered when player gives her the Archivist's Journal
- `maren_cipher_hint` — Triggered when `maren_trusts` is set; she reveals the Cipher Wheel's location
- `maren_warden_hint` — Triggered when `maren_trusts` is set; she reveals the Warden's weakness

**Lore entry (~60 tokens):**
```
[NPC: Maren] Paranoid scholar survivor, trapped ~3 weeks. In Reading Room. Clipped speech, dry humor under guard. Won't share info freely — trade Archivist's Journal for her trust. Knows Cipher Wheel location and Warden weakness. Previous expedition tried to destroy Codex (failed — caused scorch marks). Dialogue: guarded, then gradually revealing.
```

---

#### NPC #2: The Cataloger

**Keyword triggers:** `cataloger`, `spectral`, `bell`, `ghost`, `voice`

**Location:** Circulation Desk — manifests when the player rings the brass bell.

**Personality:** Prim, meticulous, utterly detached from the passage of time. The Cataloger is the remnant of a former Archive librarian — not a ghost exactly, but an echo preserved by the Archive's strange properties. It speaks as if conducting a reference interview: precise, formal, mildly impatient. It cares about one thing: proper cataloging. It does not care about the player's survival, the rising water, or the Codex's danger. It cares about whether books are shelved correctly and checked out through proper channels.

**Dialogue hooks:**
- **Summoned (first bell ring):** *"Reference desk. State your inquiry."* (A beat of silence.) *"...You rang. That implies a question. I have a finite attention span. Posthumously finite, which is worse."*
- **On the Restricted Section:** *"Access requires a Restricted key and a valid scholarly purpose. Death does not constitute a valid scholarly purpose, despite what the last three visitors argued."*
- **On the Codex Umbra:** *"Classification: Unclassifiable. Status: Recalled to Vault. Checked out: never. Checked in: always. It doesn't leave. It's returned."*
- **On the key:** *"That key was reported destroyed in the Incident. Interesting. Bureaucratic records are, apparently, unreliable even in death."*
- **If player asks for help escaping:** *"The Circulation Desk handles checkouts, returns, and reference inquiries. Escape routes are not within our catalog. Try the Antechamber."*

**Interaction behavior:**
- Only appears when the bell is rung; fades after ~3 exchanges per summoning (can be summoned multiple times)
- Answers questions about the Archive's layout, history, and contents — but only in formal reference-interview style
- Will not provide direct puzzle solutions, but its cataloging knowledge contains useful clues ("The Cipher Wheel is classified under 'Decryption Tools, Restricted Use'")
- Reacts with distress if player mentions damaging books — the only thing that breaks its composure
- Can be asked to "check out" the Codex, which triggers an amusing bureaucratic refusal loop

**Quest flags:**
- `cataloger_summoned` — Triggered when player rings bell
- `cataloger_key_comment` — Triggered when player shows Brass Key to Cataloger (provides lore)
- `cataloger_codex_info` — Triggered when player asks about the Codex (provides classification details)

**Lore entry (~55 tokens):**
```
[NPC: The Cataloger] Spectral echo of former librarian, summoned by ringing brass bell at Circulation Desk. Prim, meticulous, detached. Answers reference inquiries about Archive layout and contents in formal style. Fades after ~3 exchanges per summon. Won't give direct solutions but cataloging knowledge contains useful clues. Only breaks composure about book damage.
```

---

#### NPC #3: The Warden

**Keyword triggers:** `warden`, `darkness`, `voice`, `staircase`, `guardian`

**Location:** Restricted Section — manifests as a disembodied voice when the player approaches the spiral staircase leading down to the Vault.

**Personality:** Ancient, measured, neither hostile nor helpful. The Warden is the Archive's final security measure — not a person or ghost, but a construct of the Archive itself. It speaks in a low, resonant voice that seems to come from the walls, floor, and ceiling simultaneously. Its purpose is singular: ensure that anyone who reaches the Codex understands the responsibility. It does not prevent access — it *tests understanding*. The Warden has waited centuries and has no urgency. It will ask its question once. The player's response determines what happens next.

**Dialogue hooks:**
- **Manifesting:** *"You carry the key's memory. The gate's rust is still on your fingers."* (Pause.) *"Why are you here?"*
- **If player says "to take the Codex":** *"Everyone takes. No one carries. The Codex was written to be read and reading it has a cost. I will ask once: who owns what you are about to hold?"*
- **If player claims ownership:** The hum intensifies painfully. Player is pushed back to the Restricted Section entrance. Must re-approach. *"Ownership is the wrong word. Try again."* (Not a failure — a redirect. Per BL-013, no hard fail states.)
- **If player says "no one" / "it owns itself" / disclaims ownership:** *"Acceptable. The stair is open. What the Codex shows you is your burden, not your prize."* The spiral staircase becomes accessible.
- **If player remains silent:** (After a long pause) *"Silence is not an answer. But it is not a claim, either."* The staircase opens. (Silence = correct, per the Restricted Section inscription: *"speaks no claim of ownership."*)

**Interaction behavior:**
- Cannot be attacked, bribed, or circumvented — it IS the Restricted Section
- Responds to exactly one approach from the player per visit; if the player fails, they must leave the Restricted Section and return to try again
- The "correct" answer is informed by the decoded wall inscription (*"speaks no claim of ownership"*) and Maren's hint (*"don't try to trick it"*)
- Players who haven't decoded the inscription or talked to Maren can still solve it through roleplay intuition — the question is thematically consistent with the Archive's ethos
- Getting the answer wrong costs time (1-2 turns to leave and re-approach) but never blocks progress permanently

**Quest flags:**
- `warden_encountered` — Triggered when player approaches the staircase
- `warden_passed` — Triggered when player gives an acceptable answer (staircase opens)
- `warden_failed_once` — Triggered on wrong answer (tracks for difficulty tier adjustments)

**Lore entry (~55 tokens):**
```
[NPC: The Warden] Disembodied voice in Restricted Section, manifests near spiral staircase. Archive security construct, not a person. Tests understanding: asks who owns what the player seeks. Correct response: disclaim ownership or remain silent. Wrong answer pushes player back (no permanent block). Clued by decoded wall inscription and Maren's advice.
```

---

## 4. Puzzle Chain

The four puzzles form a sequential chain that moves the player through all three acts. Each puzzle gates progress to the next area or objective. Multiple solution paths exist for every puzzle (per BL-013's "wide paths, narrow gates" philosophy), ensuring the player never hits an absolute dead end.

### Estimated Turn Budget

| Puzzle | Act | Turns | Cumulative |
|--------|-----|-------|------------|
| 1. The Locked Gate | I | 3-6 | 3-6 |
| 2. The Cipher Discovery | I-II | 4-7 | 7-13 |
| 3. The Warden's Question | II | 2-4 | 9-17 |
| 4. The Codex and the Flood | II-III | 5-8 | 14-25 |
| **Total** | | **14-25** | **14-25** |

This fits within BL-013's 15-25 turn target range, with variance depending on exploration thoroughness.

---

### Puzzle 1: The Locked Gate

**Act:** I (Orientation), turns ~3-6

**Problem:** The iron gate at the Circulation Desk blocks access to the Restricted Section and everything beyond. The player needs to open it.

**Primary solution — The Brass Key (2-3 turns):**
1. Player explores East Wing and notices the metallic glint under the collapsed desk
2. Player investigates the glint → picks up the Brass Key
3. Player returns to Circulation Desk and uses key on iron gate → gate opens, key breaks in lock

**Alternative solution — The Cataloger's Bypass (3-4 turns):**
1. Player rings the brass bell at the Circulation Desk, summoning the Cataloger
2. Player asks the Cataloger about accessing the Restricted Section
3. Cataloger says access requires "a valid Restricted key or an emergency scholarly override, which requires the Archivist's authorization"
4. If player has the Archivist's Journal and shows it: the Cataloger accepts it as Archivist authorization and opens the gate itself (the lock clicks open without a key)

**Failure mode:** Player wanders without finding the key or the bypass. Suggestions gently steer toward the East Wing ("The eastern corridor looks like it hasn't been fully explored") or the bell ("The brass bell on the desk catches your eye — it's oddly clean"). After ~8 turns without progress, the GM includes more direct hints.

**Revelation trigger (Act I → Act II gate):** Opening the gate is the Act I revelation moment. Stepping through reveals the Restricted Section's fundamentally different architecture — older, carved from bedrock. The player realizes the Archive is much older and stranger than a library. The chained books, the whispering, the warmth — this isn't storage, it's containment. The stakes reframe: this isn't about finding a book, it's about surviving one.

**Quest flags:**
- `brass_key_found` — Player picked up the key
- `gate_opened` — Gate is open (by any method)
- `act_two_entered` — Player has stepped into the Restricted Section

---

### Puzzle 2: The Cipher Discovery

**Act:** I-II (spans the act transition), turns ~4-7

**Problem:** The Codex Umbra is locked in a pedestal with a 5-symbol combination lock. The player needs to find both the decoding tool (Cipher Wheel) and the combination (star map symbols or journal codes) to open it.

**Primary path — Maren's Trade (4-5 turns):**
1. Player encounters Maren in the Reading Room (automatic on entry)
2. Maren is guarded and won't share information freely
3. Player finds the Archivist's Journal in the West Wing (1-2 turns of exploration)
4. Player returns to Maren and shows/gives her the journal → Maren trusts the player
5. Maren reveals: "The cipher tool is in a book that isn't a book, near the fire that wasn't a fire" → player searches near the fire pit → finds the Cipher Wheel in a hollowed-out book

**Secondary path — Independent Discovery (5-7 turns):**
1. Player explores the Reading Room thoroughly without Maren's help
2. Player examines the fire pit area → notices hollowed books on the ground → finds Cipher Wheel
3. Player uses Cipher Wheel on the Archivist's Journal coded pages → reveals pedestal combination
4. (This path requires finding the journal in the West Wing independently)

**Tertiary path — Star Map (3-4 turns):**
1. Player examines the star map dome in the Reading Room
2. Player holds lamp overhead → symbols glow, revealing the 5-symbol sequence
3. Player memorizes or notes the sequence → uses it directly on the pedestal (Cipher Wheel not needed for this path, but still useful for other decoding)

**Completion:** Player has the means to open the Codex's pedestal — either the decoded combination (from journal + cipher) or the observed sequence (from star map + lamp). Having both provides confirmation and confidence.

**Quest flags:**
- `maren_trusts` — Maren has been given the journal
- `cipher_wheel_found` — Player has the Cipher Wheel
- `combination_known` — Player has learned the 5-symbol sequence (by any method)
- `star_map_read` — Player discovered the sequence via the dome mural

---

### Puzzle 3: The Warden's Question

**Act:** II (Escalation), turns ~2-4

**Problem:** The spiral staircase down to the Vault is guarded by the Warden. The player must pass its test to proceed.

**Setup (1 turn):**
Player approaches the spiral staircase in the Restricted Section. The Warden manifests as a voice. It asks: *"Who owns what you are about to hold?"*

**Informed solution — Pre-clued answer (1 turn):**
If the player decoded the wall inscription (*"speaks no claim of ownership"*) or received Maren's hint (*"don't try to trick it"*), they know the answer: **disclaim ownership**. Responses like "No one owns it," "It belongs to itself," "I don't claim it," or "I'm a borrower, not an owner" all pass.

**Intuitive solution — Silence (1 turn):**
If the player remains silent (types nothing or "stay quiet" or "say nothing"), the Warden also accepts this. The inscription says *"speaks no claim"* — silence speaks no claim. This rewards players who are cautious or who paid attention to the Archive's general theme of knowledge-as-danger.

**Wrong answer — Claiming ownership (2-3 extra turns):**
If the player says "It's mine," "I'm taking it," or similar claims of ownership, the Warden pushes them back to the Restricted Section entrance. The player can re-approach and try again. Each failure costs 1 turn. The Warden hints more explicitly each time:
- First failure: *"Ownership is the wrong word. Try again."*
- Second failure: *"The books here are chained. The Codex is sealed. Even the Archive does not own what it holds. It only contains."*
- Third failure: Auto-pass with narrated insight — *"You stand in silence, and the silence is enough."* (Prevents permanent blocking per BL-013's no-hard-fail-states rule.)

**Midpoint reversal (BL-013 Act II requirement):**
Passing the Warden is the midpoint reversal. The Warden's question forces the player to reconsider their goal: they came to "take" the Codex, but the Archive's entire philosophy rejects ownership of dangerous knowledge. This reframes the final act — the player isn't a thief or a hero, they're a **carrier**. The Codex needs to leave, but it must be carried, not claimed.

**Quest flags:**
- `warden_encountered` — Warden has spoken
- `warden_passed` — Player passed the test
- `warden_failed_once` / `warden_failed_twice` — Tracks failures for adaptive hinting

---

### Puzzle 4: The Codex and the Flood

**Act:** II-III (Escalation → Resolution), turns ~5-8

**Problem:** The player must unlock the Codex's pedestal, take the Codex, and escape the now-flooding Archive back to the Antechamber where the Codex unseals the collapsed stairway exit.

**Phase A: Opening the Pedestal (1-2 turns)**
Player enters the Vault and approaches the pedestal. The 5-disc combination lock requires the symbol sequence learned in Puzzle 2. Player inputs the combination → the pedestal mechanism clicks, stone discs align, and the Codex is released.

If the player doesn't know the combination: the Cipher Wheel can be used directly on the pedestal symbols to trial-and-error the solution (takes 2 turns instead of 1). The star map symbols are also faintly visible on the Vault's obsidian walls if examined by lamplight (redundant clue).

**Phase B: The Trigger (1 turn)**
Taking the Codex triggers the Archive's containment failure. A deep rumble. Cracks appear in the obsidian walls. Water begins entering the Vault. The hum stops — replaced by silence that's worse. The player must escape upward.

The GM narrates urgency without a literal timer: *"The water is ankle-deep by the time you reach the staircase. It wasn't there ten seconds ago."*

**Phase C: The Escape (3-5 turns)**
The player must navigate back from the Vault to the Antechamber:
- **Vault → Restricted Section** (1 turn): Water follows up the staircase. Books fall from shelves.
- **Restricted Section → Circulation Desk** (1 turn): The iron gate is jammed open (key broke in it earlier). Water pours through.
- **Circulation Desk → Main Hall** (1 turn): The bioluminescent fungus is flickering wildly. Water is shin-deep.
- **Main Hall → Antechamber** (1 turn): The collapsed stairway. Player holds the Codex up to the sealed door. The seal from the mosaic glows. The rubble shifts. Light from above.

**Critical item check — Waterproof Satchel:**
- **With satchel:** The Codex survives the water. Player emerges with the Codex intact. **Triumph** or **Survival** ending depending on other choices.
- **Without satchel:** The Codex's pages begin dissolving in the acidic water (established in East Wing description). By the time the player reaches the Antechamber, the Codex is damaged. It still opens the door (the seal responds to the binding, not the contents), but the knowledge inside is lost. **Pyrrhic** ending.

**Win condition:** The player reaches the Antechamber with the Codex and uses it to unseal the exit. The stairway clears. Light floods in. The Archive seals behind them.

**Ending variations:**

| Ending | Requirements | Narrative |
|--------|-------------|-----------|
| **Triumph** | Codex + Satchel + Maren trusted | Player emerges with intact Codex. Maren follows them out (she was waiting at the Reading Room exit). The Archive seals permanently. The star map fades from the dome. Maren takes the journal; you keep the Codex. What you do with it is another story. |
| **Survival** | Codex + Satchel, Maren NOT trusted | Player emerges with intact Codex, alone. The Archive seals. You have the book. You don't have answers. The Codex is warm in your hands. You try not to think about what the Archivist wrote: *"It contains an appetite."* |
| **Pyrrhic** | Codex WITHOUT Satchel | Player emerges, but the Codex is a waterlogged ruin. The door opened, but the knowledge is gone — dissolved in the Archive's last act of containment. You're free. The book is dead. Maren, if trusted, says only: *"The Archive won."* |
| **Time-out** | Turn 30+ without reaching Antechamber | The water rises above your head. You find an air pocket in the Main Hall. The Codex floats beside you, pages fanning open. In the lamplight — your last lamplight — you read the first line. And now you understand why they built the Archive. *"What is shelved is preserved. What is read is released."* Fade to black. Adventure marked incomplete. |

**Quest flags:**
- `codex_taken` — Player took the Codex from pedestal
- `flood_triggered` — Water is rising (Act III begins)
- `has_satchel` — Player has the Waterproof Satchel
- `codex_intact` — Codex survived the water (has_satchel = true)
- `escaped` — Player reached the Antechamber with Codex
- `ending_triumph` / `ending_survival` / `ending_pyrrhic` / `ending_timeout` — Final outcome

---

## Appendix A: Quest Flags Summary

The complete set of quest flags for game state tracking (per BL-021 JSON schema, BL-010 per-turn state serialization):

```json
{
  "act": 1,
  "turn": 1,
  "location": "antechamber",
  "inventory": ["oil_lamp"],
  "flags": {
    "brass_key_found": false,
    "gate_opened": false,
    "act_two_entered": false,
    "journal_found": false,
    "solvent_found": false,
    "satchel_found": false,
    "cipher_wheel_found": false,
    "combination_known": false,
    "star_map_read": false,
    "maren_met": false,
    "maren_trusts": false,
    "maren_cipher_hint": false,
    "maren_warden_hint": false,
    "cataloger_summoned": false,
    "cataloger_key_comment": false,
    "cataloger_codex_info": false,
    "warden_encountered": false,
    "warden_passed": false,
    "warden_failed_once": false,
    "warden_failed_twice": false,
    "codex_taken": false,
    "flood_triggered": false,
    "has_satchel": false,
    "codex_intact": false,
    "escaped": false,
    "ending": null
  }
}
```

**Token cost estimate:** ~120-150 tokens for the full state object. Within BL-010's recommended 100-150 token budget for world state injection.

---

## Appendix B: Lore Entry Token Budget

All keyword-triggered lore entries are designed to fit within BL-010's recommended per-entry budget (50-100 tokens minor, 100-150 tokens major). At any given turn, typically 1-2 location entries + 0-1 NPC entries + 0-1 item entries are active = ~100-250 tokens of lore injected.

| Entry Type | Count | Avg Tokens | Max Active at Once |
|-----------|-------|------------|-------------------|
| Location | 9 | ~58 | 1 (current location) |
| Item | 6 | ~38 | 2 (items being used/discussed) |
| NPC | 3 | ~57 | 1 (NPC in current location) |
| **Total active** | | | **~95-155 tokens** |

This fits comfortably within the 1,500-token context safe zone (BL-012) alongside system prompt (~150 tokens), example (~120 tokens), state JSON (~130 tokens), story summary (~150 tokens), recent history (~500 tokens), and author's note (~30 tokens) = ~1,080-1,235 total.

---

## Appendix C: Variation Seed Compatibility

This adventure is designed to support BL-013's procedural variation seed system. The following elements can be varied per seed without changing the puzzle chain structure:

| Element | Variations | Effect |
|---------|-----------|--------|
| Starting items | Oil lamp only / Oil lamp + torn note / Oil lamp + empty vial | Changes early exploration incentives |
| Flooded zones | East Wing + Flooded Passage / West Wing + Flooded Passage / Main Hall shallow flooding | Changes which areas feel dangerous |
| Maren's disposition | Paranoid (default) / Helpful but confused / Absent (journal has all her clues instead) | Changes NPC interaction difficulty |
| Cipher Wheel location | Reading Room (default) / West Wing cabinet / Flooded Passage submerged | Changes exploration path |
| Warden's question | Ownership (default) / Purpose ("Why should the Codex leave?") / Sacrifice ("What will you give?") | Changes thematic emphasis |
| Ending modifier | Standard / Maren is the Archivist / The Codex speaks during escape | Changes narrative twist |

Each seed selects one option per element, generating 2-3 meaningfully distinct playthroughs before exhausting combinations — matching BL-013's target of 6-9 playthroughs when combined with the 3 difficulty tiers.

---

## Cross-References

- **BL-005** (Game loop implementation) — consumes location graph, quest flags, and lore entries for prompt assembly
- **BL-010** (AI GM prompt patterns) — this document implements the keyword-triggered lore and per-turn state serialization patterns
- **BL-013** (Game design one-pager) — this adventure instantiates the Sunken Archive theme, three-act structure, and pacing targets
- **BL-018** (Genre-specific prompt templates) — this document provides the concrete content that the Sunken Archive template wraps
- **BL-021** (Game state JSON schema) — quest flags in Appendix A define the schema for this adventure
- **BL-036** (Small model prompting) — lore entry token budgets designed around small model context constraints
- **BL-043** (Game Master prompt) — the opening narrative and lore entries are formatted for direct injection into the production prompt
