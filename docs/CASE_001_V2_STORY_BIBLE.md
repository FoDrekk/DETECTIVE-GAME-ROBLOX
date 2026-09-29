# CASE-001 v2 — THE LAST CALL — Story Bible

Status: **design for review.** Nothing here is implemented. CASE-001 v1 (the
current `src/config/Case001.luau`) is untouched.

What this document is for:
- the single source of truth for the v2 story;
- a map of exactly what changes from v1, so implementation can be reviewed
  line by line.

Canon summary lives in `GAME_VISION.md`. Decisions and rejected alternatives
are in `DESIGN_DECISIONS.md` (D-05 to D-16).

---

## 1. What v2 must preserve

- **Every system:**
  - evidence, statements, claimed contradictions, answered deductions;
  - interrogation with `present`;
  - the timeline puzzle;
  - early accusation needing a motive and a proof;
  - Solved, Unproven and Wrong grades;
  - P7 epilogue variants and R7 timeline credit.
- **Every existing ID.** EV-001–007, STMT-*, CONTRA-001–004, DEDUCT-001–004,
  OBJ-000–006, ACC-001/002 keep their IDs. Characters are renamed; the IDs
  stay. The two new contradictions are labelled so they sort after the
  originals.
- **The grading rule.** Solved still means the right suspect, a motive in that
  accusation's `motives` and a proof in its `proofs`. v2 *adds* valid motives
  and proofs; thresholds are unchanged.
- **Agency.**
  - Every new clue is optional.
  - No new objectives.
  - The minimum Solved path stays about as short as v1's (badge log, then
    Victor's lie).
  - Accusing early stays possible.
- **Mara's gentle/harsh branch** (now Meera's). v2 builds its payoff on that
  branch.

## 2. Audit of v1

### What works
- The clues are specific and restrained: two espressos, a man who drinks tea at
  night, a declined call that wasn't missed, a pen across a blank signature
  line.
- A red herring that is both true and innocent (the declined call).
- Victor's three-stage collapse: alibi, revised story, "I'd like a lawyer now".
- The timeline puzzle, which is a real decision.

### What is thin

| Beat | v1 state | v2 fix |
|---|---|---|
| Protagonist | Unnamed "investigator", no context | The intro: SCU, Nora, the warrant card (see screenplay) |
| Why these people are here at 12:40 | Never explained | Canon: patrol phoned next of kin; Sam phoned the company's emergency contact |
| Cause of death | **Never stated** | A fall against the credenza during a struggle; ambulance tag; tape marks |
| Time of death | Implied only | Daniel's watch data: heart rate ends at 11:49 PM |
| Victor's motive | "The dissolution", while the reveal implies premeditation via cameras dark since Tuesday. Contradictory. | Fraud through a paper vendor; the cameras were bought dark to empty a drawer, not to kill. The death was not planned. |
| Misdirection | The badge log sits on the counter, so Victor is exposed in about 3 minutes. Nothing but the call points at Mara. | The badge log is printed on request; Meera gets a surface motive (the estate clause); Victor pushes suspicion onto her |
| Escalation | Victor breaking is the only turn | Four beats: the lie, Meera looks guilty, Meera's truth, the slip |
| Reveal | A paragraph | A rewritten paragraph plus an optional 20-second dawn outro |
| **Payoff of the title** | **Missing.** Why did Daniel call? | The unsent message: "I'm finishing it with V. Then I'm coming home." |
| Identity | Generic international names and office | A Malaysian firm, a Malaysian cast, Malaysian paper and signage |

### Continuity holes found in v1 (must fix)
1. **Victor never badges out at ten.**
   - Sam hears "Night, Sam. I'm off" around half ten.
   - The log's only entries are 11:04 IN and 11:52 OUT, with "no other badge
     used after 9 PM".
   - He cannot badge *in* at 11:04 without having left. The log needs a
     **10:28 PM OUT** line.
2. **The lift "remembers one last trip tonight: down, 11:53 PM".** The
   ambulance crew, the patrol, Victor, Meera and the detective all came up after
   midnight. The panel becomes a trip log (§8).
3. **The v1 briefing shot shows the second cup** on the visitor's side of the
   desk before the player has found it. That breaks "don't show what the player
   should discover". The v2 intro replaces the briefing (screenplay §6).
4. **Chalk outline.** Real crime scenes use tape markers, not chalk. v2 uses
   tape plus a numbered evidence marker.

## 3. The true story

This is the version the player can reconstruct, and the reveal tells.

**Before the night**
- Rozario & Lim Design Sdn. Bhd. is fifteen years old. Daniel draws; Victor
  sells, contracts and pays.
- For two years Victor has billed the firm's projects through a joinery
  subcontractor that exists only on paper, **Kemas Joinery Enterprise**, and
  kept the difference. He owes money to people who don't send reminders.
- Three weeks ago Daniel found the invoices. He didn't go to the police. He
  wanted out, cleanly: a buy-out of his shares, signed at midnight on Friday,
  with the invoices in the office file drawer as leverage.
- On Tuesday Victor paid a technician from the building's camera contractor,
  **PANTAU Sekuriti**, for four nights of "scheduled maintenance". The
  ninth-floor cameras went dark. He used the nights to take invoices out of the
  drawer a few at a time. He never got the last folder.

**The night (canonical times)**

| Time | Event | How the player can know |
|---|---|---|
| 7:00 PM | Daniel calls Meera: he'll miss dinner, again. They argue. He tells her Victor is "coming back tonight to talk me out of it". | Meera (statements) |
| 9:00 PM | Doors lock; after hours is badge only | Sam |
| 10:28 PM | Victor says "Night, Sam. I'm off" and **badges out**. The lift goes down at 10:29. | Sam, badge log, lift log |
| 11:03 / 11:04 PM | Lift up; **Victor badges back in** | Lift log, badge log |
| 11:31 PM | Two espressos from the pantry machine. Daniel is trying to keep it civil. | Coffee machine, second cup, Sam |
| 11:42 PM | Daniel saves the buy-out draft | Laptop |
| 11:47 PM | Daniel steps to the window and calls Meera. It rings 31 seconds and is **declined**. | Phone; the cold open |
| 11:48 PM | Daniel types a message to Meera and never sends it | **New:** unsent message (phone, unlocked) |
| ~11:48–11:49 PM | Victor goes for the partnership drawer; Daniel stops him; they struggle. Victor shoves him and Daniel falls against the corner of the credenza. | Tape marks, cracked photo, drawer |
| 11:49 PM | Daniel's watch records its last heart rate | **New:** watch data (phone, unlocked) |
| 11:49–11:52 PM | Victor doesn't call anyone. He turns their photo face down, takes the last invoice folder and leaves. | Face-down photo, missing folder |
| 11:52 PM | **Victor badges out** | Badge log |
| 11:53 PM | Lift down | Lift log |
| 12:10 AM | Sam finds Daniel on his rounds. The light is on; it's always on. | Sam |
| 12:14 AM | Sam calls 999 from the reception phone on Level 9 | Sam ("I called it in from reception"; v1 said "the lobby"); the intro radio |
| 12:16 AM | Sam prints the badge log for the police | **New:** a print time on the log |
| 12:18 AM | Sam phones the company's emergency contact: Victor | **New:** Sam |
| 12:22 AM | Ambulance crew and a patrol car arrive; lift up | Lift log |
| 12:26 AM | Death pronounced at the scene: head injury | **New:** ambulance tag |
| 12:28 AM | Patrol officers phone next of kin: Meera | Sam ("your lot called her") |
| 12:31 AM | Victor arrives with a patrol officer. He uses no badge. He asks to go into the office; Sam refuses. | **New:** Sam |
| 12:34 AM | The patrol tapes the floor. The ambulance takes Daniel to the mortuary at Hospital Besar Arwana, and the patrol officers go down with it to hold the lobby for the SCU. | Nora (intro), tape marks, lift log, the constable in the lobby (intro) |
| 12:35 AM | Meera arrives. She goes to the far window and speaks to no one. | Sam |
| 12:38 AM | The detective badges in at the lobby | The intro |
| 12:40 AM | The detective reaches Level 9 | The intro title card |
| ~6:00 AM | Forensics due. At dawn the case closes. | Nora; the outro |

**After (off-screen, only in the Solved epilogues):** the last invoice folder is
in the boot of Victor's car. Between the invoices is a PANTAU receipt for four
nights of maintenance. That receipt is the first thread of the long-term
mystery (`LONG_TERM_MYSTERY.md`). It is not resolved here and is never required.

### Why Victor lied the way he did
- He came back to stop Daniel and to get the folder.
- He did not plan to kill him. The cameras were dark for the theft.
- His lies protect the fraud first and the death second. That is why he is so
  quick to point at Meera, and why he slips.

### Why Meera lied
- She declined the call out of anger and has been sick with it since 12:28.
- "I never heard it" is the lie a guilty conscience tells, not a guilty person.

## 4. The cast

No criminality is tied to any community. Victor's crime comes from debt and
panic, not from who he is. The casting ledger across cases is in
`NPC_WORLD_DESIGN.md` §8.

### Daniel Rozario, 41 — the victim (not on screen)
- **Background.** Eurasian (Kristang family from Melaka), Catholic. Moved to
  Kota Arwana for architecture school and stayed.
- **Character.** A designer who keeps the lights on late and drinks chamomile
  after six. He makes coffee for whoever he's keeping late ("a bribe", per Sam).
  Stubborn, generous, bad at letting go.
- **In the room.**
  - His mug, on the desk.
  - A photo of Meera in the drawer, never put on the desk.
  - The fountain pen, uncapped over a blank signature line.
- **What he wanted that night:** out, cleanly, and to go home.

### Meera Rozario, 38 — his wife (SUS-001, accusable, innocent)
- **Background.** Indian Malaysian, a hospital pharmacist. They live in Bukit
  Pelangi, ten minutes away.
- **Voice.** Precise and controlled, with grief held tight. She code-switches
  rarely, and when she does it's with Daniel's words, not hers.
- **What she hides.** She was awake. She saw his name at 11:47 and turned the
  phone face down.
- **Why she looks guilty.**
  - "I never heard his call".
  - A clause on Daniel's laptop means his shares pass to his estate, her.
  - Victor tells you to ask her why she didn't pick up.
- **What she knows.**
  - The 7 PM argument.
  - "Victor's coming back tonight to talk me out of it".
  - Daniel's phone passcode.
- **Arc.**
  - Guarded, then defensive.
  - Pushed hard, she shuts down (the harsh path).
  - Treated gently, she admits it, and then opens his phone for you. That is
    the title's payoff.

### Victor Lim, 44 — managing partner (SUS-002, the culprit)
- **Background.** Chinese Malaysian: *Lim Wei Keat*, Victor since school.
  Charming in meetings, curt with staff. He is in debt and has been for years.
- **Voice.** Polished, impatient, in control until he isn't. Business English.
  Manglish only when rattled ("Aiya, the system's wrong, lah.").
- **What he hides.**
  - The fraud.
  - That he came back.
  - That he was in the room when Daniel fell.
  - The folder.
- **His lies, in order.**
  1. "Half ten. Whatever happened, it happened after I'd gone."
  2. "Fine, I came back. Ten minutes. He was alive, on the phone, laughing."
  3. **The slip:** "Ask her why she didn't pick up when he rang." Nobody told him
     about the call.
  4. Broken: "I'd like a lawyer now."
- **Why he isn't a cartoon.** He didn't plan it. He didn't call for help, and
  that is the thing he'll never say out loud.

### Samir "Sam" Gurung, 31 — night security (SUS-003, witness, never accusable)
- **Background.** From Pokhara, Nepal; six years in Kota Arwana; night shifts at
  Wisma Delima for three. His Malay is better than most of the tenants'. He
  brings his own flask of strong tea because he doesn't trust the office
  machine.
- **Voice.** Casual, dry, a little shaken, and genuinely helpful. He mixes
  English and Malay naturally ("Detective, you nak tengok the badge log?").
- **Role.** He knows the building, not the case. He is the most honest person on
  the floor, and the game treats him that way.
- **Care rules.**
  - No broken-English caricature.
  - No suspicion ever framed around his being a migrant worker.
  - He is competent at his job, and people underestimate him (Victor does).

### Superintendent Noraini "Nora" Idris — head of SCU (voice only in CASE-001)
- Malay; mid-fifties; twenty-eight years on the force.
- Dry, economical, kind in ways she'd deny.
- She calls rather than visits. She sent you, the new one, to this scene on
  purpose. She'll say why in a later case.

### Off-screen
- The ambulance crew (their tag).
- The patrol officers (they taped the floor and phoned Meera).
- The dispatcher (the intro radio).
- A PANTAU technician (a name on a sticker).

## 5. Localisation map, v1 to v2

| v1 | v2 | Notes |
|---|---|---|
| Daniel Reyes | **Daniel Rozario** | "R&L" preserved |
| Mara Reyes | **Meera Rozario** | "MARA" is a well-known Malaysian government agency acronym, so it's avoided |
| Victor Lane | **Victor Lim** | Initials **V.L.** preserved, so the monitor note and "V. will fight the buy-out" survive |
| Sam Okafor | **Samir "Sam" Gurung** | "Sam" preserved |
| Reyes & Lane | **Rozario & Lim Design Sdn. Bhd.** | "R&L" on the whiteboard and file drawer preserved |
| Reyes & Lane · Ninth floor | **Rozario & Lim · Tingkat 9**, Wisma Delima | Title card: *Rozario & Lim · Tingkat 9 · 12:40 AM* |
| "Mrs. Reyes" | "Puan Meera" | Sam's usage; Victor says "Meera" |
| Sam: "Came in about twenty past twelve" | "Came in about half twelve" | Matches the v2 timeline (Meera arrives 12:35) |
| Sam: "I called it in from the lobby" | "I called it in from reception" | Matches the lift trip log (Sam isn't in it) |
| "your officers" / "your lot" | unchanged in spirit | Patrol officers of the Kota Arwana Police |
| "LANE, V." (log) | "LIM, V." | Plus the 10:28 PM OUT line |
| Pantry note "LABEL YOUR MILK" | "Label susu anda. TQ." | Office humour; TQ is Malaysian shorthand for thank you |
| (none) | Stairwell "KELUAR", "DILARANG MEROKOK"; reader "Sila imbas kad"; "BUKU PELAWAT"; a small **Surau** door sign | Environment only; no gameplay on religious spaces |

**Rule.** Players address you only as "Detective" or "Inspektor". The detective
is never gendered, so there is no *Tuan* or *Puan* for the player.

## 6. Evidence (v2)

Legend:
- **R**: needed for the objective chain (as in v1).
- **O**: optional.
- **G**: gated behind a conversation.

| ID | Name | Where | What it tells the player | What it doesn't tell | v2 change |
|---|---|---|---|---|---|
| EV-001 | Phone | Daniel's desk | Last call 11:47 PM to MEERA ♥, rang 31s, **declined**. The screen is locked beyond the call log. | Why he called; who declined | Contact reads "MEERA ♥"; "locked" line added |
| EV-002 | Laptop | Desk | Draft *Termination of Shareholders' Agreement & Buy-Out*, saved 11:42 PM. Margin: "V. will fight the buy-out. Don't back down." **Clause 14:** on a shareholder's death before completion, the shares pass to the estate. | That Victor was there | Retitled; Clause 14 added (misdirection toward Meera) |
| EV-003 | Agenda | Desk | 12:00 AM with V. Lim: "Sign it. No more delays." | — | Name only |
| EV-004 | Badge Log | **Reception printer (G: appears after Sam prints it)** | 10:28 PM LIM V. OUT · 11:04 PM LIM V. IN · 11:52 PM LIM V. OUT · "Printed 12:16 AM" | That he was in Daniel's office | 10:02 OUT line (continuity fix); print time; **gated** |
| EV-005 | Coffee Machine | Pantry | LAST BREW 11:31 PM · 2 × ESPRESSO | Who drank it | — |
| EV-006 | Second Cup | Visitor's side of the desk | Half-finished espresso; Daniel's mug holds tea | Whose it was | — |
| EV-007 | Camera Monitor | Reception | All four feeds NO SIGNAL. Note: "Don't call the contractor out. Next week. — V.L." Sticker: **PANTAU Sekuriti · Servis 24 Jam · Tiket #4471** | Why they're dark | Sticker added (long-term seed, never required) |
| **EV-008** | **Marked Floor** | Beside the credenza | Patrol tape where he lay; ambulance tag: "Pronounced 12:26 AM. Head injury. Fall against furniture." The credenza corner is chipped. | Whether he fell or was pushed | **New, O** |
| **EV-009** | **Face-Down Photo** | Shelf | Daniel and Victor at a ribbon-cutting, fifteen years younger. The glass is cracked and the photo turned face down. | Who turned it | **New, O** (promoted from flavour) |
| **EV-010** | **Partnership Drawer** | File cabinet | "R&L — PARTNERSHIP", opened tonight; folders out of order; the divider "VENDOR INVOICES — KEMAS" with nothing behind it | What was in it | **New, O** (promoted from flavour) |
| **EV-011** | **Unsent Message** | Phone (G: Meera unlocks it) | 11:48 PM, draft to Meera: "I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home." | Exactly what happened next | **New, O+G** |
| **EV-012** | **Watch Data** | Phone (G: same unlock) | Daniel's watch, synced: heart rate recorded until 11:49 PM, nothing after | Who was with him | **New, O+G** |

Flavour observations that stay flavour (updated for v2):
- **Pen:** uncapped across a blank signature line.
- **Whiteboard:** "R&L" struck through to "R".
- **Desk drawer:** the photo of Meera.
- **Daniel's mug:** chamomile.
- **Guard's flask**, **meeting-room water**.
- **Lift panel:** now a trip log. "10:29 PM ↓ · 11:03 PM ↑ · 11:53 PM ↓ ·
  12:22 AM ↑ · 12:31 AM ↑ · 12:34 AM ↓ · 12:35 AM ↑ · 12:38 AM ↑".
  - The 11:53 is the one that matters.
  - The rest explain everyone else: the ambulance and patrol, Victor, the
    ambulance leaving, Meera, you.
  - Sam uses the stairs on his rounds, which is why he isn't in the log.
- **Reception visitor book:** the last entry is a courier at 6:12 PM.

## 7. Statements (v2 additions)

Existing statements stay, with names localised. New ones:

| ID | Who | Label | Text (Case File) | How it's unlocked |
|---|---|---|---|---|
| STMT-SUS-003-BADGE (changed) | Sam | The Badge Log | "Every door locks at nine. Sam printed tonight's log for you at reception." | Ask Sam "How does anyone get in after hours?" He prints it and the printer runs. |
| **STMT-SUS-003-TAPE** | Sam | The Tape | "Nobody past the tape since the ambulance crew. Mr. Lim asked to go in; Sam said no. Sam told him only that Daniel had passed." | New question: "Has anyone been in his office since?" |
| **STMT-SUS-002-MEERA** | Victor | On Meera | "Ask her why she didn't pick up when he rang. That's your mystery, Detective." | New question: "Have you spoken to Meera tonight?" |
| **STMT-SUS-001-SILENT** | Meera | Not a Word | "I haven't said a word to Victor tonight. I won't." | Part of her "Tell me about Victor" answer |
| **STMT-SUS-001-HOME** | Meera | Coming Home | "He was coming home." She opened his phone for you. | Unlock scene (§11) |

## 8. Contradictions (v2)

| ID | Label | Left | Right | Reason text | Proof for ACC-001? |
|---|---|---|---|---|---|
| CONTRA-001 | Half Past Ten | Victor's alibi | EV-004 Badge Log | "He left at 10:28, came back at 11:04 and left again at 11:52, five minutes after Daniel's last call." | Yes (v1) |
| CONTRA-002 | A Call That Never Connected | Victor's revised story | EV-001 Phone | unchanged | Yes (v1) |
| CONTRA-003 | Meera's Missed Call | Meera's alibi | EV-001 Phone | unchanged (the innocent contradiction) | No |
| CONTRA-004 | The Footage | Victor: "pull the footage" | EV-007 Monitor | unchanged | No (shows planning to be unseen, not presence) |
| **CONTRA-005** | **Nobody Told Him** | STMT-SUS-002-MEERA | STMT-SUS-003-TAPE | "Victor knows Daniel's call went unanswered. The phone has been behind the tape since before he arrived, and all he was told was that Daniel had passed. He knew because he was in the room." | **Yes (new)** |
| **CONTRA-006** | **Still in the Building** | Victor's revised story | EV-012 Watch Data | "Daniel's heart stopped at 11:49. Victor's badge didn't leave until 11:52. He wasn't laughing on the phone when Victor left." | **Yes (new)** |

Both new contradictions can be **claimed in the Case File**. CONTRA-006 can also
be **presented**: show Victor the watch data, which is an alternative route to
his break. v1's phone route stays.

**Design note on CONTRA-005.** Victor's line is available from his first
conversation. A player hearing it early reads it as misdirection toward Meera,
which is exactly what Victor intends. Only after learning that nobody told
him does it flip into the slip. It is the case's "why did they say that?"
moment.

## 9. Deductions (v2)

Existing deductions DEDUCT-001 to 004 stay, with names localised in the
options. New ones:

| ID | Label | Facts | Question | Options | Answer |
|---|---|---|---|---|---|
| **DEDUCT-005** | **By the Credenza** | EV-008 Marked Floor + EV-009 Face-Down Photo | "Tape by the credenza, a head injury, a cracked photo turned face down. What happened here?" | He collapsed alone at his desk / **He fell during a struggle, and someone turned the photo over afterwards** / He was hit with the frame / He slipped reaching for a file | struggle |
| **DEDUCT-006** | **Why It Couldn't Wait** | EV-010 Partnership Drawer + EV-002 Laptop | "A buy-out that Victor would 'fight', and a folder of vendor invoices gone from tonight's drawer. Why midnight?" | Daniel wanted to leave before year-end tax / **Daniel had found something in those invoices, and it was his leverage** / Meera wanted the money / The client deadline moved | leverage |

- **Motives for ACC-001 (v2):** DEDUCT-002, DEDUCT-001, **DEDUCT-006**.
- **Proofs for ACC-001 (v2):** CONTRA-001, CONTRA-002, **CONTRA-005**,
  **CONTRA-006**.

ACC-002 (Meera) is unchanged: supported only by CONTRA-003, and wrong.

## 10. Timeline (v2)

Seven events once everything is found:

| Time | Event | Source |
|---|---|---|
| 11:31 PM | Two espressos | EV-005 |
| 11:42 PM | The draft is saved | EV-002 |
| 11:47 PM | The last call | EV-001 |
| 11:48 PM | **A message never sent** | EV-011 (new) |
| 11:49 PM | **The last heartbeat his watch recorded** | EV-012 (new) |
| 11:52 PM | A badge leaves | EV-004 |
| 12:00 AM | The midnight meeting | EV-003 |

- `timelineChallengeOrder` must stay non-chronological at every index; the
  registry test enforces this.
- Proposed order: 11:52, 12:00, 11:48, 11:31, 11:49, 11:47, 11:42.
- The timeline shows 11:48 and 11:49 only to players who opened the phone. They
  make ordering easier and more meaningful: the night visibly *stops* between
  the call and the badge.

## 11. The payoff: the phone unlock scene

This is the heart of v2.

> **Owner revision (2026-09-29).** The harsh-path outcome below ("that player
> misses the payoff") is superseded. The phone's evidence must stay reachable
> by investigation whatever the approach, and the approach changes only how
> it's reached. The two-route design ("two ways into the phone") is approved
> in `DESIGN_DECISIONS.md` D-10. This section will be
> rewritten to match in step 5.4. The trust route below stands as Route A.

- **When it's available:** after Meera's admission
  (STMT-SUS-001-ADMISSION), and only while she isn't upset (the gentle path, or
  thawed by apologising).
- **The choice:** "Would you open his phone for me?"

> **MEERA:** ...Zero-seven, one-two, zero-nine. Our wedding.
> *(She types it and doesn't hand it back straight away.)*
> **MEERA:** There's a message. He never sent it.
> **MEERA:** *(reading)* "I'm sorry about tonight. I'm finishing it with V. He's taking it badly. Then I'm coming home."
> **MEERA:** He was coming home.

- **What it grants:** EV-011 and EV-012 are discovered, and
  STMT-SUS-001-HOME is recorded.
- **On the harsh path, if never thawed:**
  - she won't unlock it ("Get your forensics people to do it.");
  - the case is still fully solvable through CONTRA-001, 002 and 005;
  - that player misses the payoff and the 11:48 and 11:49 events.
- **Why this works.**
  - The title's question is answered: he called to say he was coming home.
  - The answer comes from the person who didn't pick up.
  - The player unlocks it by being decent to her.
  - It is emotion delivered through agency, not a cutscene.

## 12. Structure and pacing

- **Target:** 15–20 minutes for a thorough first play. The minimum Solved path
  (badge log, Victor's lie, accuse) is about 8–10 minutes, as in v1 plus the
  printer step.
- Three movements, all order-free:
  1. **The floor (0–6 min).**
     - Sam; the office read (phone, laptop, agenda, both cups).
     - First statements.
     - The player learns what the room is.
  2. **The lie (6–12 min).**
     - The badge log arrives only when you ask Sam about access.
     - Victor revises.
     - Meanwhile Meera starts to look bad: the declined call, Clause 14, and
       Victor's "ask her why she didn't pick up".
     - **This is the mid-case turn:** a thoughtful player may suspect her.
  3. **The truth (12–20 min).**
     - Meera's admission and the phone.
     - The watch data, the tape, the slip.
     - Victor breaks.
     - The player picks the motive and proof they trust and accuses.

**Escalation beats**
1. Victor's alibi fails.
2. Meera looks guilty.
3. Meera's truth reverses it.
4. Victor's own words corner him.

No beat is forced. A player can accuse after beat 1.

## 13. Reveal and endings

**Reveal (Solved, Unproven and Wrong)**
> Victor Lim had been paying himself through a joinery firm that existed only on paper. Daniel found the invoices and wanted out, tonight, with the folder in his drawer as leverage. Victor came back at 11:04 to talk him out of it. Daniel made two coffees. At 11:47 he called Meera; she let it ring. A minute later they were fighting over the drawer, and Daniel fell against the credenza. Victor didn't call anyone. He turned their photo face down, took the folder, and his badge left at 11:52. The cameras had been dark since Tuesday. Victor had paid for that, for the nights he spent emptying that drawer.

**Solved epilogue variants** (the first match wins; P7 mechanism, order matters)
1. **Unsent message and Victor broken:**
   > Victor Lim is charged before sunrise. What he said in that meeting room goes into the file word for word. The folder is in the boot of his car. Meera takes Daniel's phone home, and on the train she turns it face up.
2. **Unsent message:**
   > Victor Lim is charged before sunrise. The folder is in the boot of his car. Meera takes Daniel's phone home, and on the train she turns it face up.
3. **Victor broken:** the existing P7 "word for word" text, localised, plus "The
   folder is in the boot of his car."
4. **Base:**
   > Victor Lim is charged before sunrise. The folder is in the boot of his car. The papers are still on Daniel's desk, unsigned.

**Unproven:**
> Victor Lim walks out at three in the morning with his lawyer. You know what happened in that office. You couldn't make it hold.

**Wrong (accuse Meera):**
> Meera Rozario is charged at four in the morning. She doesn't say a word in the car. Three weeks later the case against her comes apart, and by then Victor Lim is running Rozario & Lim on his own.

**Optional dawn outro (Solved only, about 20 seconds, skippable)**
- Shots:
  - first light over Kota Arwana;
  - the forensics van pulling into the forecourt;
  - Meera at the corridor window with the phone.
- If the phone was unlocked, it is **face up**. That is the visual rhyme with
  the cold open.
- A distant Subuh (dawn prayer) call is an option for the soundscape. It needs
  a cultural review before it's used (DESIGN_DECISIONS D-27).

**The Case Closed screen:** the R6 and R7 stats as built.

## 14. Dialogue guidance and samples

- **Code-switching is character, not decoration.**
  - Sam switches most.
  - Victor switches only when rattled.
  - Meera switches least.
  - Nora switches for warmth and brevity.
- **Target density:** one Malay or Manglish touch every few lines for Sam; at
  most one per scene for Meera.
- **Subtitles:** any Malay line whose meaning matters also carries an English
  subtitle or an obvious context meaning.

Samples (new or localised lines):
> **SAM:** Detective? Hey. Over here. *(unchanged)*
> **SAM:** Badge. Every door locks at nine. You nak tengok the log? I can print it now. *(prints)* Haven't read it. That's your job, right?
> **SAM:** Mr. Lim came up with the police at half twelve. Wanted to go in the office. I said sorry boss, police tape. He wasn't happy.
> **SAM:** I told him Mr. Rozario passed. That's all I know, what else I'm going to tell him?
> **VICTOR:** Speak to her? She won't look at me. Ask her why she didn't pick up when he rang. That's your mystery, Detective.
> **VICTOR:** *(the badge log)* Aiya. Then the system's wrong, lah. ...Fine. I came back.
> **MEERA:** I haven't said a word to Victor tonight. I won't.

## 15. Kept out, on purpose

- No third suspect. This is the tutorial case; Case 2 brings more.
- No body on screen, no weapon and no gore.
- No PANTAU investigation in this case. It is one sticker and one receipt.
- No new objectives. OBJ texts are localised only.
- No change to grading thresholds, no case-strength meter, no XP.

## 16. Implementation notes (for review before any work)

These capabilities don't exist yet and would be needed. They are listed so the
implementation proposal can be reviewed on its own:

1. **Evidence gated by a statement.** EV-004's printout appears only after
   STMT-SUS-003-BADGE. Option A: a `revealWhen` condition on
   `propPlacement`. Option B: the dialogue node grants the evidence.
   **Recommendation: A**, because the player still walks to the printer and
   examines it, which keeps the examine loop.
2. **Evidence granted by dialogue.** EV-011 and EV-012 are discovered in the
   unlock scene, via a `grantsEvidence` field on a dialogue node that goes
   through EvidenceService (server-authoritative, idempotent).
3. **Present-claims for a new contradiction:** CONTRA-006 through the existing
   `present` / `claims`. No new capability.
4. **Case-File-only contradiction between two statements:** CONTRA-005.
   Already supported, verified in the code:
   - `ReasoningService.claimContradiction` matches `FactReference`s by kind and
     ID in either order;
   - `CaseFileView` lets the player select any two facts, whatever their kind.
   No new capability.
5. **Cinematic intro and outro.** A sequencer; see the screenplay §8.

Tests to extend:
- Case001_Test for the new IDs;
- CaseRegistry for the challenge order and fact references;
- the headless playthrough for the gentle-unlock route and the harsh route,
  both solvable.
