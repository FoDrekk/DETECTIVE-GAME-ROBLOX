# CASE-001 v2: Phase 5.4 content sheet

Status: **approved and applied in Phase 5.4.**

Decisions already taken (owner, 2026-09-29), which this sheet follows:
1. One examine hands over two items: the readout shows the message with an
   "Also added: Watch Data" line under it (engine addition `grantsEvidence` on
   an evidence item).
2. The passcode question and the photo wording are as below. The question needs
   EV-001 and EV-013 together, with no other hint.
3. Route B lights up the screen of the desk phone. It does not add a second phone.
4. A player who upset Meera and never thawed her can still reach her moment,
   through a third choice on her cold line.
5. The dawn outro is camera, fades and captions only. The face-up phone is a
   caption. The dawn light tint waits for 5.5.
6. The timeline challenge order is 004, 003, 007, 005, 006, 002, 001.

Rules (story bible §14, unchanged):
- Sam switches most, Victor only when rattled, Meera least.
- Dialogue lines are at most 130 characters and choices at most 80.
- Choice ids, node ids and statement ids that already exist do not change.
- "Detective" only for the player; no new objectives; no grading changes.

## A. Evidence (data)

| ID | Name | Description | Details (Case File text) | Where |
|---|---|---|---|---|
| EV-001 (changed) | Phone | unchanged | Last call: 11:47 PM, to MEERA ♥. Rang for 31 seconds. Declined. The screen is locked beyond the call log. | Daniel's desk |
| **EV-011** | Unsent Message | A message on Daniel's phone that was never sent. | Draft to MEERA ♥, 11:48 PM: "I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home." | Daniel's Office |
| **EV-012** | Watch Data | Daniel's watch data, synced to his phone. | Heart rate recorded until 11:49 PM. Nothing after. | Daniel's Office |
| **EV-013** | Photo of Meera | A photo in Daniel's desk drawer, one he never put on the desk. | Meera in a songket, holding flowers. She's laughing at whoever held the camera. On the back, in Daniel's hand: "For M. — 07.12.09." | Daniel's Office |

- The EV-001 change also fixes a v1 leftover: its details still say "to MARA"
  (the old name). The 5.2 localisation test was case-sensitive and missed it,
  so it becomes case-insensitive.
- **EV-013** is the desk drawer that already sits in the office. Its flavour
  text ("Pens. A phone charger. A photo of Meera...") is replaced by the
  evidence above, the same way 5.3 did for the shelves and file cabinet. The
  prompt label stays.
- **EV-011** is examined on the phone's lit screen (see below), and is also
  handed over by Meera's line (Route A). It carries `grantsEvidence = { "EV-012" }`,
  so examining it also adds EV-012.
- **EV-012** has no prop of its own. It arrives with EV-011 by either route.
- Importance: EV-011 High, EV-012 Medium, EV-013 Medium. All three are optional
  (no objective needs them).
- The Case File shows "x / 13" once they exist.

**The lit screen (Route B).** A thin, pale screen lying on the desk phone, with
the prompt "Read Unlocked Phone". It is held out of the world from the start
and appears the moment DEDUCT-007 is answered correctly (`revealWhen` on the
deduction). If the player already got EV-011 through Meera, the screen still
appears and reads the same again.

## B. Statement

| ID | Who | Label | Text (Case File) |
|---|---|---|---|
| **STMT-SUS-001-HOME** | Meera | Coming Home | "He was coming home." Meera has read Daniel's last message. |

Neutral on purpose: the same text is right whether she opened the phone or was
shown the message.

## C. Dialogue

### Meera, Route A: "Would you open his phone for me?"

New hub question, before "Can you look at something for me?". It is shown once
she has admitted the call (STMT-SUS-001-ADMISSION is known) and until she has
been through it (no EV-011 yet, no HOME yet). It can only be reached when she
isn't upset, because an upset Meera goes to her cold line instead.

| Node | Speaker | Line |
|---|---|---|
| choice | you | Would you open his phone for me? |
| MARA-OPENPHONE-1 | Meera | ...Give it here. He used the same code for everything. |
| MARA-OPENPHONE-2 | Meera | Zero-seven, one-two, zero-nine. Our wedding. |
| MARA-OPENPHONE-3 | Meera | There's a message. He never sent it. |
| MARA-OPENPHONE-4 | Meera | "I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home." |
| MARA-OPENPHONE-5 | Meera | He was coming home. *(grants EV-011 and EV-012; unlocks HOME; back to her hub)* |

### Meera, Route B: shown the message

New outcomes on her "Can you look at something for me?" list, for EV-011.

| Case | Node | Speaker | Line |
|---|---|---|---|
| HOME not known | MARA-MSG-0 | you | He wrote this to you at 11:48. He never sent it. |
| | MARA-MSG-1 | Meera | ... |
| | MARA-MSG-2 | Meera | Let me read it again. |
| | MARA-MSG-3 | Meera | ...He was coming home. *(unlocks HOME; clears her upset flag; back to her hub)* |
| HOME already known | MARA-MSG-KNOWN | Meera | I know what it says. Keep it safe for me. |

She reads it twice (the two beats), then speaks.

### Meera, harsh and never thawed

Her cold line (MARA-COLD) gains a third choice, shown once EV-011 is known and
HOME isn't.

| Node | Speaker | Line |
|---|---|---|
| choice | you | He left a message for you. I found it. |
| MARA-MSG-COLD-1 | Meera | ...What message? |
| MARA-MSG-COLD-2 | you | It's on his phone. He wrote it at 11:48. |
| MARA-MSG-COLD-3 | Meera | ...Show me. *(continues into MARA-MSG-1)* |

From there it is the same three beats as above, and MARA-MSG-3 clears her upset
flag, so she is no longer cold afterwards.

### Victor: the watch data

New outcome on "Take a look at this", for EV-012, available once he has told his
revised story (STMT-SUS-002-REVISED) and before his break. It claims CONTRA-006.
It ends in the existing break lines (VIC-CONF-3 onwards), so it is a second way
to STMT-SUS-002-BREAK. Shown earlier, EV-012 gets his usual "And? Am I supposed
to be impressed?"

| Node | Speaker | Line |
|---|---|---|
| VIC-WATCH-0 | you | Daniel's watch stopped recording at 11:49. Your badge left at 11:52. |
| VIC-WATCH-1 | Victor | Aiya, those things lose signal all the time. It means nothing. |
| VIC-WATCH-2 | you | It means he was alive at 11:48 and gone by 11:49. You were still in the building. |
| *(continues)* | Victor | ... *(VIC-CONF-3, then the existing lines to "I'd like a lawyer now.")* |

Victor slips into Manglish here ("Aiya") because he is rattled, as in his badge
scene.

## D. Contradiction

| ID | Label | Left | Right | Reason | Claimed in |
|---|---|---|---|---|---|
| **CONTRA-006** | Still in the Building | STMT-SUS-002-REVISED | EV-012 Watch Data | Victor says Daniel was alive when he left. Daniel's watch records his last heartbeat at 11:49. Victor's badge didn't leave until 11:52. | Case File pairing, or by showing Victor |

(The reason text is the bible's, reworded so it says what Victor claimed.)

## E. Deduction (the passcode)

| ID | Label | Facts | Prompt | Options |
|---|---|---|---|---|
| **DEDUCT-007** | Daniel's Code | EV-001 + EV-013 | Daniel's phone is locked. What would he choose as the code? | Meera's birthday. / **Their wedding date.** / The day the firm opened. / The day Daniel was born. |

- The right answer sits second (the file's own order, as DEDUCT-005 and 006).
- A correct answer lights the phone's screen (Route B).
- A wrong answer says only that it doesn't hold, and counts, like every other question.
- The difficulty rests on the photo: the wedding outfit on the front and the
  date on the back. No other clue points at it.
- It is not a motive or a proof for the accusation.

## F. Timeline (seven events once everything is found)

| ID | Time | Title | Description | Source |
|---|---|---|---|---|
| **TIMELINE-006** | 11:48 PM | A message never sent | Daniel starts a message to Meera. He never sends it. | EV-011 |
| **TIMELINE-007** | 11:49 PM | The last heartbeat | Daniel's watch records its last heart rate. Nothing after. | EV-012 |

Canonical order, top to bottom: 11:31, 11:42, 11:47, **11:48**, **11:49**,
11:52, 12:00. Challenge order: TIMELINE-004, 003, 007, 005, 006, 002, 001
(different from the canonical position at every index, which the registry
test requires).

## G. Accusation (grading thresholds unchanged)

- ACC-001 proofs: CONTRA-001, CONTRA-002, CONTRA-005, **CONTRA-006**.
- ACC-001 motives, `supportedBy` and ACC-002 do not change.
- The case stays solvable without the phone: CONTRA-001, 002 and 005 are
  enough, as in 5.3.

## H. Reveal and endings

**Reveal** (shown at every verdict):
> Victor Lim had been paying himself through a joinery firm that existed only on paper. Daniel found the invoices and wanted out, tonight, with the folder in his drawer as leverage. Victor came back at 11:04 to talk him out of it. Daniel made two coffees. At 11:47 he called Meera; she let it ring. A minute later they were fighting over the drawer, and Daniel fell against the credenza. Victor didn't call anyone. He turned their photo face down, took the folder, and his badge left at 11:52. The cameras had been dark since Tuesday. Victor had paid for that, for the nights he spent emptying that drawer.

**Solved epilogue.** The first match wins, in this order.

| # | Needs | Epilogue |
|---|---|---|
| 1 | STMT-SUS-001-HOME and STMT-SUS-002-BREAK | Victor Lim is charged before sunrise. What he said in that meeting room goes into the file word for word. The folder is in the boot of his car. Meera takes Daniel's phone home, and on the train she turns it face up. |
| 2 | STMT-SUS-001-HOME | Victor Lim is charged before sunrise. The folder is in the boot of his car. Meera takes Daniel's phone home, and on the train she turns it face up. |
| 3 | STMT-SUS-002-BREAK | Victor Lim is charged before sunrise. What he said in that meeting room goes into the file word for word, and his lawyer can't take it back. The folder is in the boot of his car. The papers are still on Daniel's desk, unsigned. |
| base | | Victor Lim is charged before sunrise. The folder is in the boot of his car. The papers are still on Daniel's desk, unsigned. |

The phone ending keys on HOME, not on who unlocked the phone, as decided.

**Unproven** and **Wrong (accuse Meera)**: unchanged.
> Unproven: Victor Lim walks out at three in the morning with his lawyer. You know what happened in that office. You couldn't make it hold.

## I. The dawn outro (Solved only, skippable, about 18 seconds)

Two scenes, which differ by one caption. The server picks the second when HOME
is known. It plays after a Solved verdict is accepted and before the Case
Closed card, and either ending of it (finished or skipped) opens the card.

| Shot | Length | Camera (chosen against the built office) | Caption |
|---|---|---|---|
| 1 | 6 s, fade in | A slow push across Daniel's desk and the taped floor | First light over Kota Arwana. |
| 2 | 7 s | The corridor window, Meera's back to us | *(with HOME)* She turns it face up. *(without)* She stays at the window. |
| 3 | 5 s, fade out | A held wide of the corridor window | none |

- Captions are narration (no speaker), timed inside their shot.
- No sound cue is added. A Subuh call stays out until the cultural review (D-27).
- The dawn light tint is left for 5.5, along with the intro sets. Until then
  the office is lit as it is.

## J. What changes in the world

- **DeskDrawer:** evidence EV-013 replaces its flavour text.
- **A lit-screen prop** on the desk phone, held until DEDUCT-007 is answered.
- Both are patched into the baked place, and BuilderVersion goes to 5.
- No other set work.

## K. Tests

- New `CaseContent54_Test`: the new evidence, statement, lines and endings word
  for word; both routes; the harsh route through the cold line; CONTRA-006 by
  pairing and by showing Victor; DEDUCT-007 needing EV-001 and EV-013 and
  lighting the screen; the timeline order and the epilogue priority.
- The 5.3 test "the phone's evidence and its consequences are not in yet"
  flips to check that they are in.
- Counts move: 13 evidence, 6 contradictions, 7 deductions, 7 timeline events.
- Engine tests for `grantsEvidence` on evidence (idempotent, unknown ids and
  cycles rejected).
- The headless playthrough plays Route A (gentle), Route B (harsh, never
  thawed, passcode, screen, message shown to Meera) and the case solved
  without the phone.

## L. Kept out, on purpose

- No PANTAU thread, and no showing Victor the message.
- No new objectives, no grading changes, no scoring.
- No intro or set art (5.5).
