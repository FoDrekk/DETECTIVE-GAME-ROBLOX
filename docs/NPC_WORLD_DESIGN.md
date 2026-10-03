# People of Kota Arwana — NPC World Design

Status: **design.** Built today: Tier 1 (the CASE-001 cast), with branching
dialogue, statements and "show". Decisions: `DESIGN_DECISIONS.md` D-32 to D-35.

## 1. Philosophy

People are the city's partial memory:
- Everyone knows *something*. Nobody knows *everything*.
- Some people lie for reasons that have nothing to do with the crime.

Our job is to make a small number of people feel real, not to simulate a
large number.

**Not a life simulator.**
- No schedules for everyone.
- No needs, no relationships between strangers, no emergent crime.

## 2. Three tiers

| | Tier 1 — Case characters | Tier 2 — Persistent locals | Tier 3 — Ambient people |
|---|---|---|---|
| **Who** | Suspects, key witnesses, victims' families | The mamak owner, the condo guard, the print-shop owner, a delivery rider, the forensic pathologist, the records clerk | Commuters, diners, riders, shoppers, pasar malam crowds |
| **How many** | 3–8 per case | 3–6 per district, recurring across cases | A handful to ~25 per area on screen (§9) |
| **Dialogue** | Fully authored branching conversations (the existing ConversationService) | A small **knowledge table** plus a few lines per case they appear in | At most one-line barks; mostly none |
| **Statements** | Yes | Yes, when they know something | Never |
| **"Show"** | Authored reactions per item | Authored reactions for what they'd plausibly recognise; a character default otherwise | No |
| **Accusable** | Only if authored as such | Never (unless promoted to Tier 1 for a case) | Never |
| **Memory** | Per case (dialogue flags, as today) | **Across cases:** they remember you, and what you did in their place | None |
| **Exists for** | The mystery | The city's memory, and continuity | Life and density |

A Tier-2 local can be **promoted** to Tier 1 for one case (the mamak owner as a
suspect) and return to Tier 2 afterwards.

## 3. "Show someone something": the central verb

Already built for suspects (`present` in ConversationService). Generalised in
CASE-002, it lets the player show **any** evidence or photo to **any** Tier-1
or Tier-2 person.

**Resolution order** (server-side, from case data):
1. **A specific authored reaction** for this person and this item, under its
   conditions. It can record a statement, claim a contradiction or unlock a
   choice (the same outcome model as `present` today).
2. **A topic reaction.** Items can carry a topic tag ("vehicle", "wedding",
   "rider jacket") and a person can have a reaction for the topic.
3. **The character's default shrug**, in their voice. Arif: "Sorry. I do the
   doors."

**Rules**
- **Showing the wrong thing is never a miss.** No lockout, no counter. It
  matches M9's rule for interrogation.
- **A reaction never exceeds the person's knowledge.** The guard can say the
  jacket was orange; he can't say whose it was.
- **Recognition is a fact, not a conclusion.** "That's her sticker" is a
  statement; "so he stole her laptop" is the player's deduction.
- **People react to *who* shows them things.** A Tier-2 local who likes you
  (you were decent last case) tells you a little more; one you treated badly
  gives you the minimum. This is one memory flag, not a reputation system.

## 4. Knowledge model (conceptual, for `WORLD_SCALABILITY.md`)

Per Tier-2 person, data only:
- **identity:** name, role, community, voice notes, home location, appearance;
- **base lines:** greeting, "who are you", a default "show" reply;
- **knowledge:** a list of `{ topic or item, requires?, line, grants? }`;
- **memory:** a few named cross-case flags (`helped_rahim_case002`).

Per case, an **overlay** adds that case's knowledge and lines to the
characters who appear in it, without editing the characters' base data.

This keeps characters reusable across cases and cases self-contained.

## 5. Witness design: partial, biased, human

Every witness is authored with three columns:

| What they saw | What they assume | What they hide, and why |
|---|---|---|
| Facts, at the resolution they would really have (time rounded, colours not faces) | Their interpretation, which can be wrong | Shame, loyalty, fear, a small crime of their own, **saving face** |

Examples:
- **Arif (CASE-001).** Saw Victor say goodnight at ten. Assumes Victor left and
  stayed gone. Hides nothing. He's the honest one.
- **Kavitha (CASE-002).** Saw Nadia arrive terrified on Sunday night. Assumes the
  danger is still out there. Hides Nadia, out of loyalty.
- **Daren (CASE-002).** Saw nothing relevant. Assumes he's a suspect. Hides his
  Sunday visit out of embarrassment, not guilt.

**Saving face** is a distinctly local lever: an uncle who won't admit he let a
stranger into the lift, a guard who logs a rider he didn't really check, a
mother who says her son was home. These lies are human, forgivable and
solvable, and they make the red herrings fair.

## 6. Voice and language guide

- **Base language: English** (OD-07).
  - Code-switching is *character*: who someone is, how they feel, who they're
    talking to.
  - It is never decoration.
- **Density by character type** (a guide, not a quota):
  - Casual locals (guards, mamak staff, riders): Malay or Manglish touches in
    most exchanges.
  - Professionals under pressure: switch when rattled ("Aiya, the system's
    wrong, lah.").
  - Formal speech or grief: little or none, and the rare switch lands hard.
  - Nora: brief and warm ("Dah sampai?", "Jangan lupa makan.").
- **Meaning never depends on a Malay word the player might not know.** Either
  the context makes it obvious or the line carries a subtitle.
- **Environmental text reads as Malaysian** (Wisma Delima, ROSAK, the mamak
  sign; notices in English since 5.6). The UI stays English.
- **Address forms:**
  - NPCs call the player **"Detective"** or **"Inspector"**. Never *Tuan*,
    *Puan*, sir or ma'am, because the player's gender is never assumed (D-04).
  - NPCs among themselves use natural forms (*Meera*, *Encik*, *Abang*,
    *Kak*, *Uncle*, *Aunty*, *boss*).
- **No caricature.**
  - No phonetic accents, no broken-English jokes, no "lah" on every line.
  - Every non-native English speaker (Arif, a Bangladeshi cook, an Indonesian
    maid) speaks with dignity and clarity. They are often the most observant.

## 7. Recurring characters (Season 1)

| Character | Tier | Role | Community |
|---|---|---|---|
| **Supt. Noraini "Nora" Idris** | Story | Head of SCU; dispatcher, mentor, long-term thread | Malay |
| **Dr. Chong Mei Ling** | 2 | Forensic pathologist, Hospital Besar Arwana. Post-mortem facts, never conclusions. | Chinese Malaysian |
| **Encik Kumar Pillai** | 2 | JPKA records clerk. Processes Records Requests from CASE-003; dry, rule-bound, secretly delighted by good reasoning. | Indian Malaysian |
| **Arif Rahman** | 2 (after CASE-001) | Still at Wisma Delima. A friendly face in the CBD; knows the building guards' network. | Nepali |
| **Abang Rahim** | 2 (from CASE-002) | Restoran Seri Pagi. Knows every rider in Bukit Pelangi. | Indian Muslim |
| **Jeffery anak Ngau** | 2 (from CASE-002) | Residensi Pelangi guard. Proud of his log book. | Iban |
| **Tan Wei Jie** | 2 (from CASE-002) | A student delivery rider. The night city's eyes. | Chinese Malaysian |

## 8. Casting and representation ledger

**The rule:** no community is coded as criminal. Across a season, culprits,
victims, red herrings and helpful witnesses are spread across communities, and
no community's first appearance is only as a culprit.

| Case | Culprit | Victim | Red herring | Key helpful witness |
|---|---|---|---|---|
| 001 | Victor Lim (Chinese Malaysian) | Daniel Rozario (Eurasian) | Meera Rozario (Indian Malaysian) | Arif Rahman (Nepali) |
| 002 | Shahrul Nizam (Malay) | Nadia Kamal (Malay) | Daren Ooi (Chinese Malaysian) | Tan Wei Jie (Chinese Malaysian); Jeffery anak Ngau (Iban) |
| 003+ | *to be cast against this ledger* | | | |

**Notes**
- A Chinese Malaysian culprit in CASE-001 is followed by a Chinese Malaysian
  *key* witness in CASE-002, and the recurring pathologist is Chinese Malaysian.
- Malays appear as the SCU's head, a victim and a culprit.
- Update this table with every case. A Malaysian reader reviews it.

## 9. Ambient population

PC-first budgets, to be confirmed by profiling:
- **Density:** about 15–25 Tier-3 people visible in a busy scene (pasar malam,
  mamak), about 5–10 in a quiet one.
- **Behaviour:**
  - Idle loops and short authored walks: sitting, eating, queueing, riding past.
  - No city-wide pathfinding and no crowd AI.
- **Streaming:** ambient people exist only in the streamed area around the
  player, and are spawned by the location, not the case.
- **Barks:** optional, a few per location, in local voice. They never carry
  clues.
- **Clothing and variety:** built from the existing appearance model
  (`SuspectDefinition.appearance`), extended with weather and occasion (ponchos
  in rain, office wear in the CBD, a *baju kurung* on a Friday).

## 10. What not to build

- Schedules, needs, relationships or memory for Tier-3 people.
- A reputation or affinity *system*. Tier-2 memory is a few named flags.
- Generated or procedural dialogue. Every line with meaning is authored.
- Romance, recruitment or companions.
- Anything that lets a Tier-3 person carry a clue.
