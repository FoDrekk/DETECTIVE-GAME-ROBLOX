# Mystery Case — Game Vision

> **A detective game set in a living Malaysian city.**
> You notice things. People lie. The city remembers. You decide what happened.

This is the north star for everything after CASE-001 v1. It is short on
purpose. The detail lives in the documents indexed at the end. Where this
document and another disagree, this one wins until someone updates it.

Status: pre-production. Nothing here is implemented yet except CASE-001 v1
(see `ARCHITECTURE.md` and `ROADMAP.md`).

---

## The pitch

It is 12:40 in the morning in **Kota Arwana**. The patrol officers have taped
the floor, the ambulance has gone, and forensics can't come until six. Until
then the ninth floor of Wisma Delima belongs to you, a detective newly posted to
the **Special Cases Unit**, and to three people who have each had two hours to
decide what they're going to tell you.

The game is about the gap between what people say and what the room says.
Over time it is also about a city: its lifts and guardhouses, its mamak stalls,
its riders, its dashcams and QR receipts. Where someone was at a certain time
is a question you answer by going there and reading the place.

## Who you are

You play yourself. Your Roblox avatar is the detective, and your display name is
on the SCU warrant card in the first shot you see. You are not a chosen one, a
genius child or a vigilante. You are the new investigator on a small,
overworked unit, and your boss, **Superintendent Noraini "Nora" Idris**,
thinks you notice things other people don't. The game never tells you whether
she is right. You find out.

## Pillars

1. **Evidence over testimony.** "Believe the room." Every case is built so the
   physical world contradicts at least one confident human account.
2. **The player makes the connection.** The game records what you found and
   what people said; *you* pair them, answer the question, order the night and
   name the culprit. No clue explains itself. No marker points at the answer.
3. **Places are clues.** An address on a receipt, a trip log in a lift, a
   guardhouse visitor book: the city's own paperwork moves you through it.
4. **People are partial.** Everyone knows something, nobody knows everything,
   and some people lie for reasons that have nothing to do with the crime:
   shame, love, fear, saving face.
5. **Malaysian, not Malaysia-themed.** The setting is the texture of the
   investigation, not a skin over it. The receipts say *Teh O Ais Limau*
   because that is what someone ordered at 11:15 PM.
6. **Dense, not large.** A handful of places you can read closely beats a city
   you can only drive past.

## What the player should feel

- "I noticed something."
- "Something doesn't add up."
- "Why did they say that?"
- "Where was this person?"
- "I think these clues are connected."
- "I have a theory."
- "Let's see if I'm right."

## What this game is not

- Not a GTA clone. You can't drive and there's no combat or wanted level, and
  the map isn't something to clear.
- Not a Roblox simulator or roleplay game. It is single-player, one detective
  per server.
- Not a checklist mystery: no "collect 7/7", no glowing clues, no quest log of
  chores.
- Not a walking simulator. Every location has something to read, someone to
  question, or a decision to make.
- Not a franchise copy. The inspirations are *feelings* (see Creative DNA), and
  nothing is borrowed.

## Foundation decisions (fixed by the project owner)

These are recorded in `DESIGN_DECISIONS.md` (OD-01 to OD-12) and are not open to
reinterpretation without the owner's say-so.

| Area | Decision |
|---|---|
| City | **Kota Arwana**, a fictional Malaysian metropolis inspired by the Klang Valley, recreating no real city |
| Organisation | **Special Cases Unit (SCU)** inside a fictional Malaysian police force; the real Royal Malaysia Police is never represented |
| Protagonist | The player, as themselves; **Nora** is supervisor, mentor and dispatcher |
| CASE-001 | Localised as a Malaysian case with a mixed Malaysian cast; the investigation structure is preserved |
| Platform | **PC first** (keyboard and mouse); mobile second; gamepad later |
| Audience | Teenagers and young adults; serious but Roblox-appropriate |
| Multiplayer | **Single-player only**, one player per server |
| Language | English gameplay with natural Malay and Manglish code-switching; UI in English; environmental text naturally in Malay |
| World | Connected, **dense not large**; CASE-001 is the first location, not the game |
| Priority | Finish CASE-001 QA, then story bible, intro, narrative payoff, CASE-002 concept, connected proof of concept; only then expand |

## Canon at a glance

Canonical facts every document must agree with. Change them here first.

**The world**
- **Kota Arwana** grew up around the **Sungai Arwana**, a river named for the
  arowana that used to live in it. The old town sits on its banks; the towers
  rose behind it in thirty years.
- **Kota Arwana Police** (*Jabatan Polis Kota Arwana*, **JPKA**) is fictional.
  The SCU appears on signage as *Unit Kes Khas*. SCU works from the top floor of
  **Balai Lama**, the 1930s police station in Kota Lama (the old town).
- **Nora**: Superintendent Noraini binti Idris, head of the SCU. Dry, patient
  and hard to impress. She is usually on the phone rather than at the scene.

**CASE-001 — THE LAST CALL** (full detail in `CASE_001_V2_STORY_BIBLE.md`)
- Wisma Delima, Level 9, Jalan Merbau, Dataran Arwana (the CBD).
- Rozario & Lim Design Sdn. Bhd., an interior design and fit-out firm founded
  fifteen years ago. On paper it is still "R&L".
- The people:
  - **Daniel Rozario**, 41, the victim: design partner, Eurasian.
  - **Meera Rozario**, 38, his wife: hospital pharmacist, Indian Malaysian.
  - **Victor Lim**, 44, the managing partner, who runs the contracts and money:
    Chinese Malaysian.
  - **Arif Rahman**, 31, the night security guard: from Nepal, six years
    in Kota Arwana.
- The night, fixed times:
  - 11:04 PM Victor badges back in.
  - 11:47 PM the last call, declined.
  - 11:49 PM Daniel's heart-rate data ends.
  - 11:52 PM Victor badges out.
  - 12:10 AM Arif finds him.
  - 12:40 AM you arrive.
  - About 6:00 AM forensics are due and the case closes at dawn.

**CASE-002 — SEVENTEEN-SEVEN** (concept only; `CASE_002_CONCEPT.md`)
- Residensi Pelangi and Pelangi Square, Bukit Pelangi. It is a Wednesday
  evening, pasar malam night.

## Creative DNA

The inspirations are Detective Conan, Magic Kaito, spy gadgets and Batman's
detective side. From them we take four feelings:

- **Fair-play deduction.** Every answer can be reached from things the player
  has seen, and the moment it clicks feels earned.
- **The slip.** A suspect says something they could only know if they were
  there. (CASE-001 v2's *Nobody Told Him*.)
- **Stylish, plausible tools.** Kit that feels clever without being magic: a
  phone camera, CCTV scrubbing, a UV torch, later a directional mic.
- **Reconstruction.** You rebuild what happened from pieces and test your
  version against the world (the timeline now, scene reconstruction later).
- **A rival in the shadows** (long term only). **Kunang**, an original thief
  with their own reasons. Working concept, `LONG_TERM_MYSTERY.md`.

We never borrow characters, costumes, catchphrases, gadgets or plots:

- no shrunken genius and no voice-changer;
- no white-suited magician thief;
- no borrowed catchphrase.

See `DESIGN_DECISIONS.md` D-30.

## Tone and look

- **Tone.** Quiet, observant, melancholic, with a sharp edge. It is a city that
  keeps going while one room has stopped. Grief and guilt are taken seriously,
  and so is humour, in small human doses. It is never gory, never campy and
  never cynical about ordinary people.
- **Look (PC reference).** The city is wet at night:
  - sodium-orange streetlights against white LED shopfronts;
  - rain on glass and neon on puddles;
  - interiors lit warm, and lit sparingly.
- **Frames.** Cinematic 16:9, letterboxed in cutscenes and conversations. The UI
  is minimal and typographic, like a case file rather than a game HUD.
- **Sound.** Mostly diegetic: rain, the LRT, air-conditioning hum, a mamak TV,
  motorbikes, the lift's ding. Music is sparse, one motif per case, and it
  stops when you are working.

## Document index

| Document | What it holds |
|---|---|
| `GAME_VISION.md` | This page: the north star, pillars and canon at a glance |
| `DESIGN_DECISIONS.md` | Every major decision with why, alternatives and impact |
| `CASE_001_V2_STORY_BIBLE.md` | CASE-001 v2: the audit, the true story, the cast, clues, the fixes |
| `CASE_001_INTRO_SCREENPLAY.md` | The opening, shot by shot |
| `CASE_002_CONCEPT.md` | The first connected, multi-location case (concept) |
| `KOTA_ARWANA_WORLD_FOUNDATION.md` | The city: districts, density, traversal, Malaysian identity |
| `DETECTIVE_TOOLKIT.md` | Which tools, when, and what each lets the player discover |
| `NPC_WORLD_DESIGN.md` | The three NPC tiers, "show someone something", voice and casting |
| `LONG_TERM_MYSTERY.md` | *Titik Buta*, the working concept for the connecting thread |
| `WORLD_SCALABILITY.md` | How the current code grows; what to change later and why |
| `ROADMAP.md` | Milestone history plus the pre-production roadmap |
| `ARCHITECTURE.md` | How the current game is built |
