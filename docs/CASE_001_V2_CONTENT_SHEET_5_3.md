# CASE-001 v2: Phase 5.3 content sheet

Status: **proposal, awaiting owner approval.** Nothing here is applied.

This sheet assumes the recommended options in the 5.3 proposal (decisions
1 to 5). Where an option would change a line, that is noted.

Rules (story bible §14, unchanged):
- Sam switches most, Victor only when rattled, Meera least.
- Dialogue lines are at most 130 characters and choices at most 80.
- Choice ids, node ids and statement ids that already exist do not change.
- "Detective" only for the player; no new objectives; no grading changes.

## A. Evidence (data)

| ID | Name | Description | Details (Case File text) | Where |
|---|---|---|---|---|
| EV-002 (changed) | Laptop | unchanged | A draft: "Rozario & Lim: Termination of Shareholders' Agreement & Buy-Out", last saved 11:42 PM. A note in the margin: "V. will fight the buy-out. Don't back down." Clause 14: if a shareholder dies before completion, his shares pass to his estate. | Daniel's desk |
| EV-003 (changed) | Agenda | unchanged | 12:00 AM, with V. Lim: "Sign it. No more delays." | Daniel's desk |
| EV-004 (gated) | Badge Log | unchanged | unchanged (10:28 OUT, 11:04 IN, 11:52 OUT). **The printout stays on the reception counter but is only in the world after Sam prints it** (`revealWhen`: his BADGE statement). | Reception |
| EV-007 (seed) | Camera Monitor | unchanged | 'All four feeds: NO SIGNAL. A note on the bezel: "Don't call the contractor out. Next week. — V.L." A sticker beside it: "PANTAU Sekuriti · Servis 24 Jam · Tiket #4471".' | Reception |
| **EV-008** | Marked Floor | Tape marks and a numbered marker on the floor beside the credenza. | Patrol tape where he lay. Ambulance tag: "Pronounced 12:26 AM. Head injury. Fall against furniture." The credenza corner is chipped. | Daniel's Office |
| **EV-009** | Face-Down Photo | A framed photo on the shelf, turned face down. | Daniel and Victor at a ribbon-cutting, fifteen years younger. The glass is cracked and the photo has been turned face down. | Daniel's Office |
| **EV-010** | Partnership Drawer | The file cabinet drawer labelled R&L — PARTNERSHIP. | Opened tonight; the folders are out of order. The divider "VENDOR INVOICES — KEMAS" has nothing behind it. | Daniel's Office |

EV-008 to EV-010 are optional (not needed for any objective). EV-009 and
EV-010 become evidence on the shelf frame and file cabinet that are already
in the office (their flavour text is replaced by the evidence text above).
EV-008 is a small ambulance-tag prop by the floor marker, with a credenza
built beside the tape outline.

## B. Statements

| ID | Who | Label | Text (Case File) |
|---|---|---|---|
| STMT-SUS-003-BADGE (changed) | Sam | The Badge Log | Every door locks at nine. Sam printed tonight's badge log for you at reception. |
| **STMT-SUS-003-TAPE** | Sam | The Tape | Nobody past the tape since the ambulance crew. Mr. Lim asked to go in; Sam said no. Sam told him only that Daniel had passed. |
| **STMT-SUS-002-MEERA** | Victor | On Meera | "Ask her why she didn't pick up when he rang. That's your mystery, Detective." |
| **STMT-SUS-001-SILENT** | Meera | Not a Word | "I haven't said a word to Victor tonight. I won't." |

## C. Dialogue

**Sam: the badge log, printed on request.** Replaces the three lines after
"How does anyone get in after hours?" (its choice text, ids and the
"lacks BADGE" rule stay).

| Node | Now | Proposed |
|---|---|---|
| SAM-BADGE-1 | Badge. Every door locks at nine. | unchanged |
| SAM-BADGE-2 | The system keeps a log. I printed tonight's for you. It's on the reception counter. | You nak tengok the log? I can print it now. |
| SAM-BADGE-3 (new) | | Okay, it's printing. ...There. On the reception counter. *(unlocks the BADGE statement; the printout appears)* |
| SAM-BADGE-4 (was -3) | Haven't read it. Figured that's your job. | unchanged |

*nak tengok* = want to see (the next words make it plain).

**Sam: the tape.** New question at Sam's hub: "Has anyone been in his office since?" (shown until the TAPE statement is known).

| Node | Line |
|---|---|
| SAM-TAPE-1 | Nobody, since the ambulance crew. |
| SAM-TAPE-2 | Mr. Lim came up with the police at half twelve. Wanted to go in the office. |
| SAM-TAPE-3 | I said sorry boss, police tape. He wasn't happy. |
| SAM-TAPE-4 | I told him Mr. Rozario passed. That's all I know, what else I'm going to tell him? *(unlocks TAPE)* |

**Victor: on Meera.** New question at Victor's hub: "Have you spoken to Meera tonight?" (shown until the MEERA statement is known; available from his first conversation).

| Node | Line |
|---|---|
| VIC-MEERA-1 | Speak to her? She won't look at me. |
| VIC-MEERA-2 | Ask her why she didn't pick up when he rang. That's your mystery, Detective. *(unlocks MEERA)* |

Victor stays in clean English here: he is not rattled yet.

**Meera: not a word.** Her "Tell me about Victor" answer gains one closing line.
Today that question is `once` and hidden after the laptop is found; because it
now unlocks a statement, it follows the file's own rule for such questions
(shown until the statement is known, never `once`).

| Node | Line |
|---|---|
| MARA-VICTOR-3 | They built it together. Lately it felt like Daniel was the only one still building. *(unchanged; now continues)* |
| MARA-VICTOR-4 (new) | I haven't said a word to Victor tonight. I won't. *(unlocks SILENT)* |

**Objective hint (needs your OK).** OBJ-003 ("Half Past Ten") gains a nudge,
because the objective chain still needs the badge log and the log is now
behind a question: description "...If anything in this building says
otherwise, show it to him, or set the two side by side in your case file. The
night guard knows how people get in and out." (Strike this and the chain has
no pointer to Sam's access question; a stuck player can still find it by
asking Sam everything.)

## D. Contradiction

| ID | Label | Left | Right | Reason | Claimed in |
|---|---|---|---|---|---|
| **CONTRA-005** | Nobody Told Him | STMT-SUS-002-MEERA | STMT-SUS-003-TAPE | Victor knows Daniel's call went unanswered. The phone has been behind the tape since before he arrived, and all he was told was that Daniel had passed. He knew because he was in the room. | Case File pairing |

It is claimed by pairing the two statements (already supported by the engine).

## E. Deductions (open questions)

| ID | Label | Facts | Prompt | Options (right answer first here only) |
|---|---|---|---|---|
| **DEDUCT-005** | By the Credenza | EV-008 + EV-009 | Tape by the credenza, a head injury, a cracked photo turned face down. What happened here? | **He fell during a struggle, and someone turned the photo over afterwards.** / He collapsed alone at his desk. / He was hit with the frame. / He slipped reaching for a file. |
| **DEDUCT-006** | Why It Couldn't Wait | EV-010 + EV-002 | A buy-out that Victor would 'fight', and a folder of vendor invoices gone from tonight's drawer. Why midnight? | **Daniel had found something in those invoices, and it was his leverage.** / Daniel wanted to leave before year-end tax. / Meera wanted the money. / The client deadline moved. |

In the game the options are presented in the file's own fixed order, as v1.

## F. Accusation (grading thresholds unchanged)

- ACC-001 motives: DEDUCT-002, DEDUCT-001, **DEDUCT-006**.
- ACC-001 proofs: CONTRA-001, CONTRA-002, **CONTRA-005**.
- `supportedBy` is left as it is, so nothing about how the verdict is graded moves.
- ACC-002 (Meera) is unchanged.

## G. Deferred to 5.4 (with the phone, per the approved two-route design)

EV-011 and EV-012, the 11:48 and 11:49 timeline events, CONTRA-006 and
Victor's watch-data confrontation, STMT-SUS-001-HOME, the drawer-photo date
clue and the passcode question, the reveal and epilogue text, and the dawn
outro. The timeline stays at its five events in 5.3.
