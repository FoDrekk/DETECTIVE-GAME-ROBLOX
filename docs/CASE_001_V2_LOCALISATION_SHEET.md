# CASE-001 v2: Phase 5.2 localisation sheet

Status: **awaiting owner approval.** Nothing in this sheet is applied yet.

Owner decisions so far (2026-09-29):
- **D1A:** update the baked place with a targeted patch, not a full re-bake.
- **D2A:** dialogue changes are approved from this sheet before they are applied.
- **D3A:** adjust skin tones only.
- **D4B:** leave the briefing shot until 5.5.

Rules used (`CASE_001_V2_STORY_BIBLE.md` §5 and §14):
- Sam switches most, Victor only when rattled, Meera least (Daniel's words).
- Any Malay word whose meaning matters has an obvious meaning from context.
- The player is only ever "Detective". Dialogue lines stay at 130 characters or
  fewer and choices at 80 or fewer.
- Choice ids, node ids and statement ids do not change.

## A. Code-switching touches (8 lines)

| Node | Now | Proposed |
|---|---|---|
| SAM-OPEN-2 | Sorry. I've been stood here half an hour. Didn't know if I was allowed to sit down. | Sorry ah. I've been standing here half an hour. Didn't know if I'm allowed to sit down. |
| SAM-AGAIN | Still here. Not going anywhere, apparently. | Still here lah. Not going anywhere, apparently. |
| SAM-FOUND-2 | His light was on. It's always on. I knocked, 'cause you knock, right? | His light was on. It's always on. I knocked, 'cause you knock, kan? |
| SAM-COFFEE-1 | From that machine? No chance. I bring a flask. That thing hates me. | From that machine? No chance lah. I bring a flask. That thing hates me. |
| SAM-MARA-2 | She's by the window at the end of the corridor. Hasn't moved. Hasn't said a word to me. | Puan Meera's by the window at the end of the corridor. Hasn't moved. Hasn't said a word to me. Kesian. |
| SAM-BYE | Sure. I'll be... here. Obviously. | Okay, okay. I'll be... here. Obviously. |
| VIC-BADGE-1 (Victor, rattled) | Then the system's wrong. | Aiya. Then the system's wrong, lah. |
| MARA-LAST-1 (Meera, Daniel's words) | He rang at seven to say he'd miss dinner. Again. | He rang at seven. "Sayang, sorry, I'll miss dinner." Again. |

Meaning from context: *kan* = right?; *kesian* = poor thing (Sam, about a
grieving woman standing alone); *sayang* = darling (Daniel's word, with the
English beside it).

Deliberately not touched:
- Lines whose meaning would depend on the Malay ("Contractor's expensive").
- Victor's other lines (polished until he cracks).
- Lines tied to 5.3 mechanics: Sam printing the log, the tape line,
  "ask her why she didn't pick up".

## B. Renames and the story-bible map (mechanical)

Applied across all player-facing case text (about 20 lines beyond section A):
- **Names:** Daniel Reyes → Daniel Rozario, Mara Reyes → Meera Rozario,
  Victor Lane → Victor Lim, Sam Okafor → Samir "Sam" Gurung.
- **Sam's usage:** "Mr. Lane" → "Mr. Lim"; "Mr. Reyes" → "Mr. Rozario".
- **The detective's usage:** "Mrs. Reyes" → "Puan Meera" (two lines).
- **Sam's timings and places:**
  - "twenty past twelve" → "half twelve";
  - "from the lobby" → "from reception".
- **Camera wording:** "lobby cameras/footage" → "reception cameras/footage"
  (v2 has a ground-floor lobby in the intro, so "lobby" would be ambiguous).
- **Place line:** "Reyes & Lane · Ninth floor" → "Rozario & Lim · Tingkat 9".
- **Deduction option:** "Signing the end of Reyes & Lane." → "Signing the end of
  Rozario & Lim."
- **Contradiction label:** "Mara's Missed Call" → "Meera's Missed Call".
- **Accusation labels and wrong epilogue:** renamed only.
- **Reveal and solved epilogues:** renamed only. The story text stays as it
  is until 5.3 and 5.4 rewrite it.

## C. Continuity texts

- **Lift panel** (observation): "The lift is parked on this floor. Its display
  keeps tonight's trips: 10:03 PM down · 11:03 PM up · 11:53 PM down · 12:22 AM
  up · 12:31 AM up · 12:34 AM down · 12:35 AM up · 12:38 AM up."
  - Words, not arrows: I haven't verified the arrow glyphs render in the game font.
  - Times depend on decision 5 below.
- **EV-004 details:** "10:02 PM LIM, V. OUT. 11:04 PM LIM, V. IN. 11:52 PM
  LIM, V. OUT. No other badge used after 9 PM except security."
  - Times depend on decision 5 below.
- **Printout on the counter:** the same lines in its 24-hour format, headed
  "AFTER-HOURS ACCESS · TINGKAT 9", with the security line "S. GURUNG".
- **Signage** (targeted patch of the baked props):
  - **Relabelled:** the door nameplate, the reception fascia, the logo wall
    ("ROZARIO & LIM" over "DESIGN SDN. BHD. · EST. 2010"), the monitor lock
    caption, and the anniversary poster.
  - **Exit signs:** "EXIT" → "KELUAR".
  - **Pantry note:** "LABEL YOUR MILK" → "Label susu anda. TQ."
  - **New small signs:** "DILARANG MEROKOK", "Sila imbas kad", "BUKU PELAWAT"
    and a Surau door sign. No gameplay attaches to any of them.
- **Tape:** the chalk outline is replaced by a flat tape outline plus a
  numbered marker at the same spot.

## D. Skin tones (skin only; hair, clothes and accessories unchanged)

| Character | Now (RGB) | Proposed (RGB) | Reason |
|---|---|---|---|
| Meera | 234, 198, 170 | 150, 102, 72 | Indian Malaysian: warm medium-deep brown |
| Sam | 116, 78, 56 | 176, 130, 96 | Nepali: warm tan-brown (the old tone was written for Okafor) |
| Victor | 198, 152, 122 | unchanged | Chinese Malaysian: already a mid tone |

I'll check the result in a Studio screenshot after patching the baked NPCs,
and adjust if it doesn't read well in the office lighting.

## E. Open story question: 10:02 against "half ten"

The bible puts Victor's badge-out at **10:02 PM**, but his first lie is "Half
ten. Give or take." A careful player will see a 28-minute gap between what he
said and what the log shows. That is not a contradiction the case intends, and
CONTRA-001 is titled "Half Past Ten".

- **A:** keep it as written in the bible (10:02, "half ten, give or take").
  Nothing changes.
- **B:** change Victor's claim to "around ten" and rename "Half Past Ten"
  (the CONTRA-001 label, the OBJ-003 title, one DEDUCT-004 option and its
  dialogue).
- **C (recommended):** move the badge-out to **10:28 PM** and the lift down to
  10:29. Sam then hears "Night, Sam. I'm off" at about half ten.
  - "Half Past Ten" stays everywhere.
  - Sam's "about ten" line and his statement become "about half ten".
  - The bible's timeline gets the two new times.
