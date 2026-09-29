# Design Decisions

Every major decision behind the pre-production foundation, with the reasoning.

**Two kinds of entry**
- **OD-xx: owner decisions.** Fixed by the project owner (the "Foundation
  Decisions" brief). Recorded here with the lead designer's assessment. They
  are *not* reopened without the owner asking.
- **D-xx: lead-designer decisions** made in this pass. Each can be overturned by
  the owner. Those most worth a look are listed in §3.

Format: **Decision**, **Why**, **Alternatives**, **Why not**, **Impact**.

---

## 1. Owner decisions (fixed)

### OD-01 — City: Kota Arwana
- **Decision:** a fictional Malaysian metropolis, inspired by the Klang Valley
  but recreating no real city.
- **Assessment: strong.** "Arwana" (arowana) is distinctly Malaysian, easy to
  say in English, and gives the city a river to grow around (D-23).
  - Real-city recreation was rightly ruled out. It invites "that street isn't
    there" and representation problems.
- **Impact:** every place name is invented and checked (D-28).

### OD-02 — Organisation: a Special Cases Unit in a fictional police force
- **Decision:** the SCU, inside a fictional police organisation; never the real
  Royal Malaysia Police.
- **Assessment: strong.**
  - A special unit explains why the detective gets unusual cases, why they work
    alone at night, and why they carry kit the rest of the force doesn't.
  - It keeps the fiction free of real-institution constraints.
- **Impact:** named in D-01 and D-02.

### OD-03 — CASE-001 is localised
- **Decision:** a Malaysian cast, dialogue, company, architecture, documents and
  signage, with the investigation structure preserved.
- **Assessment: correct.** v1's generic international setting was the biggest
  identity gap.
  - Localisation can preserve every ID, and even the story's key initials
    (D-05).
- **Impact:** the story bible §5.

### OD-04 — PC first
- **Decision:** keyboard and mouse is the reference; mobile second; gamepad
  later.
- **Assessment: agree, with one consequence recorded.**
  - Phase 3's R1/R4 small-screen fixes stay; mobile must not regress, but it
    doesn't set the bar.
  - Performance targets are now PC (`WORLD_SCALABILITY.md` §6), and a
    real-client PC baseline is a Phase 4 task.
- **Impact:** a cinematic 16:9 intro; tool controls designed for the mouse
  first.

### OD-05 — Audience: teens and young adults
- **Decision:** serious, intelligent, stylish; appropriate for Roblox.
- **Assessment: agree.** It licenses grief, guilt, fraud and death handled with
  restraint.
- **Content rules:** see D-43.

### OD-06 — Single-player only
- **Decision:** one player per server; no co-op in the architecture target.
- **Assessment: strong.**
  - Deduction is personal ("I have a theory"), and a partner solving it for you
    kills that.
  - It also removes shared-state problems (`WORLD_SCALABILITY.md` §2).
- **Impact:** SessionGuard stays. There are no social systems.

### OD-07 — Language: English with Malaysian code-switching
- **Decision:** English gameplay; natural Malay and Manglish in speech and the
  environment; UI in English; no bilingual toggle.
- **Assessment: strong.** It matches how urban Malaysians actually talk, reads
  for international players, and keeps localisation cost at zero.
- **Impact:** the voice guide (`NPC_WORLD_DESIGN.md` §6).

### OD-08 — Core identity
- **Decision:** a detective game set in a living Malaysian city. Not GTA, not a
  simulator, not a checklist, not a walking simulator, not roleplay.
- **Assessment:** this is the test every other decision is checked against.

### OD-09 — Long-term world: connected, dense, not large
- **Assessment: agree.** It is also the only affordable path: art throughput is
  the project's biggest risk (`WORLD_SCALABILITY.md` §8).

### OD-10 — Priority order
- **Decision:**
  1. finish CASE-001 QA;
  2. story bible;
  3. intro;
  4. narrative payoff;
  5. CASE-002 concept;
  6. a small connected proof of concept;
  7. then expand.
- **Assessment: agree.** The roadmap follows it exactly, and puts the proof of
  concept *before* the foundations work (D-44).

### OD-11 — Creative DNA
- **Decision:** Detective Conan, Magic Kaito, spy gadgets, Batman's detective
  side, for feeling only; nothing copied.
- **Assessment:** translated into concrete rules in D-30.

### OD-12 — Review gate
- **Decision:** propose major designs for review before implementation.
- **Assessment:** every roadmap phase starts with a proposal. Tonight's
  deliverables are documents only.

---

## 2. Lead-designer decisions

### World and organisation

**D-01 — The police force is "Kota Arwana Police" (*Jabatan Polis Kota Arwana*, JPKA)**
- **Why:** it reads as a Malaysian institution (*jabatan*, department) and is
  obviously fictional: a city force, while Malaysia's real police is national.
  It gives signage and documents a believable Malay form.
- **Alternatives:** an unnamed "the police"; a national-sounding force name; a
  private agency.
- **Why not:**
  - Unnamed leaves documents and signage hollow.
  - A national-sounding name drifts toward imitating the real force.
  - A private agency contradicts OD-02.
- **Impact:** the warrant card, the radio and records requests say JPKA.

**D-02 — The SCU works from Balai Lama, a 1930s police station in Kota Lama**
- **Why:**
  - It gives the hub character: ceiling fans and case boards.
  - It anchors the SCU in the old town, not a glass tower, which says "small,
    old-school, sharp".
  - It places the hub in the district the game will build second.
- **Alternatives:** a floor in a modern JPKA tower; a mobile unit; no hub.
- **Why not:**
  - A modern tower is generic.
  - A mobile unit means no place to come home to.
  - No hub leaves nowhere for the case board and Nora.
- **Impact:** Kota Lama becomes the second district (Phase 9).

**D-03 — Nora is Superintendent Noraini binti Idris, Malay, mid-fifties, voice-first**
- **Why:**
  - The owner named Nora. "Nora" is a natural short form of Noraini.
  - A senior Malay woman heading the unit is plausible and is the cast's Malay
    anchor.
  - Keeping her on the phone in CASE-001 preserves the lone-detective feeling.
- **Alternatives:** a male mentor; a mentor at every scene; a younger partner.
- **Why not:**
  - A male mentor is fine but less distinctive.
  - A mentor on scene undermines the player's ownership.
  - A partner implies co-op energy (OD-06).
- **Impact:** her dry, caring voice ("Jangan lupa makan") and her long-term
  history (D-37).

**D-04 — The protagonist: your avatar, your name on the warrant card, never gendered**
- **Why:**
  - OD-02 says you play yourself; putting the display name and avatar headshot
    on the SCU card makes it literal in the first minute.
  - NPCs address you as "Detective" or "Inspektor" because Roblox avatars
    aren't a reliable gender signal and *Tuan/Puan* would misgender someone.
- **Alternatives:** a named hero; a player-chosen gender for address forms;
  a faceless role.
- **Why not:**
  - A named hero contradicts OD-02.
  - A gender picker adds UI and branching for little gain.
  - Faceless misses the personal hook.
- **Impact:** a writing rule in `NPC_WORLD_DESIGN.md` §6; the intro's shot 9.

### CASE-001 v2

**D-05 — The localised cast: Daniel Rozario (Eurasian), Meera Rozario (Indian Malaysian), Victor Lim (Chinese Malaysian), Samir "Sam" Gurung (Nepali)**
- **Why:**
  - A believable KL-style office cast, mixed without tokenism.
  - It keeps **"R&L"** (the whiteboard, the file drawer) and **"V.L."** (the
    monitor note, "V. will fight the buy-out"), so most v1 clue text survives.
  - "Mara" is avoided because MARA is a prominent Malaysian government agency
    acronym.
  - A Nepali night guard reflects real Malaysian office security, written with
    dignity.
- **Alternatives:** all-Malay; keeping the v1 names and framing an expat firm;
  other combinations.
- **Why not:**
  - All-Malay is less representative of a CBD firm and wastes the mixed-cast
    brief.
  - Keeping v1 contradicts OD-03.
  - Other combinations lost R&L and V.L. or put Malay representation only in
    the culprit.
- **Impact:** the casting ledger (D-35). A Chinese Malaysian culprit here is
  balanced by Chinese Malaysian key allies in CASE-002 and the recurring cast.
- **Owner review (2026-09-29):** approved.

**D-06 — The firm: Rozario & Lim Design Sdn. Bhd., interior design and fit-out**
- **Why:**
  - *Sdn. Bhd.* is authentically Malaysian.
  - Fit-out work runs on subcontractors, which makes a fraud through a paper
    joinery vendor natural and easy to show on invoices.
- **Alternatives:** an unspecified business; a law firm; a tech startup.
- **Why not:**
  - Unspecified gives no motive texture.
  - A law firm pulls toward legal procedure.
  - A tech startup is generic and makes the fraud abstract.
- **Impact:** EV-002 is retitled a shareholders' buy-out. The player-facing
  "partnership" wording stays, as people say it.

**D-07 — Cause of death: a fall against the credenza during a struggle; shown only through tape, a tag and a cracked photo**
- **Why:** v1 never said how Daniel died. A struggle-and-fall is:
  - non-graphic;
  - consistent with the existing clues (turned photo, opened drawer, lift at
    11:53);
  - morally interesting: not planned, and no call for help.
- **Alternatives:** poisoning (the second cup!); a planned blunt-force murder;
  natural causes with a cover-up.
- **Why not:**
  - Poisoning makes the second cup the murder weapon and the case a chemistry
    puzzle.
  - Planned murder conflicts with Victor's panicked lies.
  - Natural causes deflates the verdict.
- **Impact:** EV-008, EV-009 and DEDUCT-005.
- **Owner review (2026-09-29):** approved.

**D-08 — Victor's motive is fraud; the death was unplanned; the cameras were bought for the theft**
- **Why:** it fixes v1's contradiction ("dark since Tuesday" implied
  premeditation), deepens the motive beyond a business breakup, and seeds the
  long-term thread naturally.
- **Alternatives:** a premeditated murder with the cameras as prep; the motive
  stays "just the dissolution".
- **Why not:**
  - Premeditation clashes with his improvised lies.
  - The dissolution alone is thin and leaves the dark cameras unexplained.
- **Impact:** EV-010, DEDUCT-006, the reveal text, the PANTAU receipt.
- **Owner review (2026-09-29):** approved.

**D-09 — Meera gets a surface motive (Clause 14, the estate) and Victor points at her**
- **Why:** v1's misdirection was one declined call. A money motive plus a
  suspect steering you makes her a fair, mid-case red herring without making
  her guilty.
- **Alternatives:** a third suspect; an affair subplot; no change.
- **Why not:**
  - A third suspect bloats the tutorial case.
  - An affair is a cliché and cheapens her grief.
  - No change keeps the three-minute solve.
- **Impact:** the escalation beats (story bible §12).

**D-10 — The title's payoff: Meera unlocks the phone (the unsent message and the watch data), gated by treating her gently**
- **Why:**
  - It answers "what was the last call for?" through the person who didn't
    pick up.
  - It rewards decency with the emotional truth *and* the strongest proof
    (CONTRA-006).
  - It uses the existing gentle/harsh branch, so there's agency without a
    cutscene.
- **Alternatives:** a voicemail; a cutscene flashback; forensics unlock the
  phone in the epilogue.
- **Why not:**
  - A declined call leaves no voicemail.
  - A flashback tells instead of letting the player find it.
  - Forensics removes the player's hand.
- **Impact:** EV-011 and EV-012, TIMELINE 11:48 and 11:49, a
  `grantsEvidence` capability.
- **Owner revision (2026-09-29): not approved as written.** Keep the emotional
  payoff and the Meera interaction, but preserve detective agency:
  - the evidence stays obtainable through investigation;
  - the player's approach changes *how* it is obtained (the route, the
    dialogue, the difficulty);
  - never a simple "be kind, get the evidence; be harsh, lose it for good".
- **Approved implementation (owner, 2026-09-29): "two ways into the phone"**
  (built in step 5.4; see `CASE_001_V2_CONTENT_SHEET_5_4.md`):
  - **Route A, trust** (the gentle path, or thawed by apologising). As written
    in story bible §11:
    - Meera types the date and reads the message aloud.
    - The line grants EV-011 and EV-012 (`grantsEvidence`) and records
      STMT-SUS-001-HOME.
    - Quicker, and the emotional scene is hers.
  - **Route B, investigation** (any approach, including harsh and never
    thawed). The passcode can be worked out from the room:
    - The photo of Meera in Daniel's desk drawer (today flavour text) carries
      the date on its back ("07.12.09").
    - A Case File question asks what Daniel would use to lock his phone.
    - Answering it reveals an "unlocked phone" at the desk
      (`propPlacement.revealWhen` on that deduction). Examining it discovers
      EV-011 and EV-012, and the investigator reads the message alone.
    - Slower, and it asks for a deduction.
    - Meera's moment can still come later, differently: showing her the
      message (an ordinary `present` outcome) gets her "He was coming home."
  - **Both routes** reach CONTRA-006, the 11:48 and 11:49 timeline events, and
    the phone-face-up ending (key that ending on STMT-SUS-001-HOME, not on who
    unlocked the phone).
  - **Engine note.** One examine discovers one evidence item. So Route B needs
    either a second revealed prop for the watch data, or a small addition in
    5.4: evidence that hands over further evidence when discovered, reusing
    `EvidenceService.grant`. Recommended: the addition (one object, one
    action).
  - **Decisions taken by the owner (2026-09-29):**
    - **The clue:** the back of the drawer photo carries "07.12.09". It
      becomes a new optional evidence item.
    - **The Case File question:** "Daniel's phone is locked. What would he
      choose as the code?" Options: their wedding date (correct); Meera's
      birthday; the day the firm opened; the day Daniel was born.
    - **Meera's line when shown the message (Route B):** she reads it twice,
      then says "...He was coming home."
    - **Engine:** a small addition in 5.4, so discovering one item also hands
      over another (one examine gives the message and the watch data), reusing
      `EvidenceService.grant`.
  - **Not yet decided:** the passcode question's difficulty tuning, and the
    exact text on the back of the photo. Both are for step 5.4's review.

**D-11 — *Nobody Told Him*: Victor's own misdirection becomes his slip**
- **Why:**
  - The purest "why did they say that?" moment: early, the line reads as a push
    toward Meera; later, as proof he was in the room.
  - It is Conan-style fair play with no gadget.
  - It needs no new capability, since Statement × Statement pairing already
    works.
- **Alternatives:** Victor knows about the unsigned papers; he knows the time
  of death.
- **Why not:**
  - Papers are guessable from the agenda.
  - Time of death is too forensic for a first case.
- **Impact:** STMT-SUS-002-MEERA, STMT-SUS-003-TAPE, CONTRA-005.

**D-12 — The badge log is printed on request, not lying on the counter**
- **Why:** v1 could be solved in about three minutes by walking past the
  counter. Gating on *asking Sam how access works* rewards curiosity and slows
  the solve without a marker.
- **Alternatives:** leave it; hide it in a drawer; require an objective.
- **Why not:**
  - Leaving it keeps the three-minute solve.
  - A drawer is arbitrary.
  - An objective violates "don't make every clue mandatory".
- **Impact:** a `revealWhen` capability; Sam's line "You nak tengok the badge
  log?".

**D-13 — Fix v1's continuity holes**
- **The holes:**
  - Victor's missing badge-out (10:28 PM; owner's timing decision, 2026-09-29,
    so it agrees with his "half ten");
  - the lift's "last trip 11:53", despite five later arrivals;
  - chalk instead of tape;
  - the briefing showing the second cup.
- **Why:** a fair-play mystery must survive a careful player. These are exactly
  the holes careful players find.
- **Alternatives:** leave them as "game logic".
- **Why not:** they undermine the one thing the game is about.
- **Impact:** the story bible §2 and §6; the screenplay §6.

**D-14 — Promote the best flavour to optional evidence (the face-down photo, the partnership drawer); add the marked floor**
- **Why:** v1's strongest story beats were unclaimable flavour text.
- **Alternatives:** keep them as flavour.
- **Why not:** they're the "how" and "why" the case was missing.
- **Impact:** EV-008 to EV-010 (optional).

**D-15 — Epilogue variants in priority order, plus a 20-second dawn outro**
- **Why:** P7's mechanism already exists. The phone-face-up ending closes the
  loop with the cold open.
- **Alternatives:** a single epilogue; a long outro.
- **Why not:**
  - A single epilogue wastes the unlock.
  - A long outro drags after the verdict.
- **Impact:** four Solved variants; the sequencer reused.

**D-16 — Kept out of v2: a third suspect, new objectives, grading changes**
- **Why:** preserve the tutorial case's tightness and the owner's rules (no
  meters, no forced clues).
- **Impact:** v2 adds only optional facts and valid motives and proofs.

### The intro

**D-17 — The cold open is the other end of the last call**
- **Why:**
  - It creates the case's question before the case exists.
  - It foreshadows the declined call and the face-down photo without revealing
    who.
  - It hides a fair clue for attentive players (the unopened tablets).
- **Alternatives:** open on the city; open on the body; open in the SCU
  office.
- **Why not:**
  - The city first is scenic but has no hook.
  - The body is graphic and gives away the scene.
  - The SCU office is exposition first.
- **Impact:** screenplay Scene 1; the outro's rhyme.

**D-18 — About 2:40 to control, with mouse-look in the lift; skippable; replays start at the doors**
- **Why:**
  - Within the owner's 2–4 minute range.
  - PC-first means cinematic time is affordable.
  - The lift turns the last half-minute into presence.
- **Alternatives:** 60–90 seconds passive (the earlier proposal); 4 minutes.
- **Why not:**
  - 60–90 seconds was a mobile-first argument, overturned by OD-04.
  - 4 minutes has scenes that would only be exposition.
- **Impact:** screenplay §2.

**D-19 — The intro replaces the v1 briefing for CASE-001**
- **Why:** the briefing shows the second cup, and the intro does its job
  better.
- **Alternatives:** keep both.
- **Why not:** redundant and spoiling.
- **Impact:** the `CaseBriefingView` code is kept for future static briefings.

### CASE-002

**D-20 — The premise: a missing photographer, a flat searched but not robbed, a fake delivery rider**
- **Why:**
  - It proves the connected loop.
  - It asks a different question ("where is she?").
  - Its deception is rooted in everyday Malaysian life (riders pass
    guardhouses).
  - The stakes are real but non-lethal.
- **Alternatives:** a second murder; a hit-and-run; a heist.
- **Why not:**
  - A second murder repeats Case 1.
  - A hit-and-run needs roads and vehicles early.
  - A heist wants Kunang, who is saved for CASE-003.
- **Impact:** `CASE_002_CONCEPT.md`.

**D-21 — The proof-of-concept location: Pelangi Square, one condo, one shoplot row, a back lane, a night-market car park**
- **Why:** the smallest set of places that still makes the player *travel* and
  *return*, all walkable in under a minute.
- **Alternatives:** span two districts; a single building.
- **Why not:**
  - Two districts needs transit before the loop is proven.
  - A single building doesn't prove the world.
- **Impact:** Phase 6 and Phase 8.

**D-22 — CASE-002 has no long-term-thread content**
- **Why:** it proves early that not every case is a conspiracy.
- **Impact:** the thread cadence (D-38).

### The city

**D-23 — Kota Arwana is "a city that grew too fast around an old river"**
- **Why:** it gives the city a history, a geography (old town on the river,
  towers behind, condos on the hills) and a theme: a city that writes
  everything down and still loses people.
- **Alternatives:** a coastal port city; a new planned city.
- **Why not:**
  - A port city pulls away from the Klang Valley inspiration.
  - A planned city loses the old town.
- **Impact:** the district layout and tone.

**D-24 — No driving. Walk, take the LRT between districts, e-hail to pinned addresses.**
- **Why:**
  - Driving is expensive, pulls toward GTA, and adds nothing to deduction.
  - The LRT and e-hailing are authentically Malaysian and diegetic.
  - Pins reward reading.
- **Alternatives:** driving; fast-travel menus.
- **Why not:**
  - Driving is the scope and identity risk above.
  - A menu is non-diegetic and doesn't reward reading addresses.
- **Impact:** no vehicle systems in any phase plan.

**D-25 — Build two places first: Level 9 and Pelangi Square. Seven more districts exist on paper only.**
- **Why:** OD-09 and art throughput.
- **Impact:** the roadmap Phases 6–9.

**D-26 — Case time, not world time**
- **Why:** mysteries depend on authored times ("11:47"). A running clock breaks
  them and costs simulation.
- **Alternatives:** a day/night cycle.
- **Why not:** it fights the clues and adds systems for no deduction value.
- **Impact:** each case sets time and weather.

**D-27 — Religion is setting, never a device; the Subuh call at dawn is optional and reviewed**
- **Why:**
  - Surau, temples, churches and prayer times are part of real Malaysian life.
    Leaving them out is inauthentic; exploiting them is disrespectful.
  - The dawn azan would be beautiful in the CASE-001 outro, but only after a
    cultural review.
- **Impact:** the guardrails (`KOTA_ARWANA_WORLD_FOUNDATION.md` §8).
- **Owner review (2026-09-29):** approved.

**D-28 — All brands and apps fictional; every name checked before shipping**
- **Why:** it avoids real-business and real-agency representation and legal
  risk.
- **Impact:** working names (*SenPay*, *Sembang*, *Bungkus*, *Naik*, *PANTAU*,
  *Wisma Delima*) are checked in Phase 5 and later.

### Tools

**D-29 — The toolkit: Camera, CCTV Review, Address Pins, Records Request, UV Torch, Scene Reconstruction, Directional Mic**
- **Rejected:** fingerprint kit, audio recorder, evidence scanner, location
  tracking, lie detector, hacking, drone, disguise.
- **Why:** each chosen tool surfaces information the player must interpret. Each
  rejected one either gives answers, duplicates the Case File, or copies the
  inspirations.
- **Impact:** `DETECTIVE_TOOLKIT.md`.

**D-30 — Creative DNA: take the feelings, never the signatures**
- **What we take:**
  - fair-play deduction;
  - the slip of the tongue;
  - stylish-plausible tools;
  - reconstruction;
  - a principled thief in the shadows.
- **What we never take:**
  - a shrunken genius;
  - voice-changers or bow ties;
  - a white-suited magician thief;
  - announced heists with riddles;
  - catchphrases;
  - vigilante costumes.
- **Why:** the owner's rule, and a stronger identity.
- **Impact:** Kunang's rules (D-37); tool selection (D-29).

**D-31 — No XP, no levels, no currencies: tools arrive one per case, through the story**
- **Why:** the owner's rules, and progression by understanding instead of
  grinding.
- **Impact:** tool unlocks are world-state flags set at case close.

### People

**D-32 — Three NPC tiers: case characters, persistent locals, ambient people**
- **Why:** it puts authored depth where the mystery needs it and cheap life
  everywhere else.
- **Alternatives:** everyone talkable; a simulated population.
- **Why not:**
  - Everyone talkable is unwritable.
  - A simulation is expensive, and emergent noise pollutes fair-play clues.
- **Impact:** `NPC_WORLD_DESIGN.md`.

**D-33 — "Show someone something" is the central world verb**
- **Why:** it already exists and works. It turns every photo and item into a
  question you can ask anyone, and it scales by data.
- **Impact:** the resolution order (specific, then topic, then default).

**D-34 — The code-switching voice guide**
- **Rules:** density by character type; meaning never hidden in an untranslated
  word; no caricature.
- **Why:** OD-07 done well.
- **Impact:** every dialogue review.

**D-35 — A casting and representation ledger, updated per case**
- **Why:** "no community associated with criminality" is a property of a
  *season*, not a single case. A ledger makes it checkable.
- **Impact:** a table in `NPC_WORLD_DESIGN.md` §8; a Malaysian reader review.

### The long-term mystery

**D-36 — The thread is *Titik Buta*, blind spots for sale** (working concept)
- **Why:** it grows from CASE-001's own logic, is specific to a camera-saturated
  Malaysian city, and keeps cases self-contained.
- **Alternatives:** a serial killer; police corruption; a secret society; a
  tech corporation; no thread.
- **Why not:** see `LONG_TERM_MYSTERY.md`, "Rejected alternatives".
- **Impact:** only the CASE-001 seeds are canon.

**D-37 — Kunang, an original thief named for the firefly** (working)
- **Why:** the Magic Kaito *appeal* (a principled rival in the dark) with an
  original Malaysian identity and grounded rules.
- **Impact:** a first appearance in CASE-003, if approved.

**D-38 — Thread cadence: at most every other case; the Dossier is optional**
- **Why:** individual cases stay satisfying, and a player who ignores the thread
  loses nothing but an ending variant.
- **Impact:** the seed map.

### Technical

**D-39 — No rewrite; staged abstractions A1–A9, each at its trigger phase**
- **Why:** the core is right. What's missing are world-level concepts.
- **Impact:** `WORLD_SCALABILITY.md`.

**D-40 — Locations own anchors; cases reference anchors, not coordinates. Characters live in a registry with per-case overlays.**
- **Why:** v1 welds content to absolute office coordinates. A world needs
  places and people that outlive a case.
- **Impact:** A3 and A5.

**D-41 — Persistence at checkpoints only, with versioning; streaming from Phase 6**
- **Why:** it minimises save bugs and matches case-shaped sessions.
- **Impact:** A2 and §5.

### Tone and process

**D-42 — Tone and look: quiet, observant, melancholic with a sharp edge; a wet-night palette; typographic, case-file UI**
- **Why:** it matches the existing CASE-001 craft and the audience (OD-05), and
  gives the game a look that isn't "Roblox default".
- **Impact:** `GAME_VISION.md`, "Tone and look".

**D-43 — Content rules for the audience**
- **The rules:**
  - Death is implied, never shown.
  - No gore.
  - No depicted drinking or drug use.
  - Loan sharks and scams are discussed, not shown violently.
  - The experience's content maturity questionnaire is answered honestly at
    publish (expected: Mild).
- **Why:** OD-05 and Roblox's platform rules.
- **Impact:** every case review.

**D-44 — Proof of concept before foundations in the roadmap**
- **Why:** OD-10 orders the proof of concept before expansion. Testing whether
  the connected loop is *fun* before investing in persistence and hubs is also
  cheaper if the answer is "not yet".
- **Alternatives:** foundations first.
- **Why not:** it risks building infrastructure for a loop that hasn't been
  proven.
- **Impact:** `ROADMAP.md` Phases 6 and 7.

---

## 3. Decisions that most need the owner's eye

Owner review of 2026-09-29: items 1, 2 and 6 approved; item 3 revised and
then approved as the two-route design (see D-10); items 4 and 5 not yet
reviewed (they don't block CASE-001 v2).

1. **The cast's communities and names** (D-05). Especially the Chinese Malaysian
   culprit in the first case, and the Nepali guard. Both are written with care
   and balanced by the ledger, but they're sensitive choices. *Approved.*
2. **Victor's fraud and the unplanned death** (D-07, D-08). This changes v1's
   implied premeditation. *Approved.*
3. **The phone-unlock payoff gated by kindness** (D-10). Players who push Meera
   hard miss the title's answer. That's intended, but it is a design stance.
   *Revised by the owner: see D-10.*
4. **No driving, ever (for now)** (D-24).
5. ***Titik Buta* and Kunang** (D-36, D-37), as working concepts only.
6. **The Subuh call in the outro** (D-27). It needs a cultural review.
   *Approved.*
