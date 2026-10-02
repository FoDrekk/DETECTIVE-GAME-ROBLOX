# CASE-001 — Intro Screenplay and Storyboard

Status: **Implemented.** The original storyboard below records the approved
story decisions; the production cut is a revised 2:49 sequence in
`src/config/Case001Intro.luau`. The shot map and implementation status are
kept aligned below. The scene remains text-first; it has no recorded dialogue.

Canon for names and times: `GAME_VISION.md` and `CASE_001_V2_STORY_BIBLE.md` §3.
Decisions and rejected alternatives: `DESIGN_DECISIONS.md` D-17 to D-19.

---

## 1. What the intro has to do

| Job | How it's done |
|---|---|
| Establish Malaysia | The city in rain; LRT, mamak, rider, signage, Malay radio, "Dah sampai?" |
| Establish the detective | Your own avatar, your display name on an SCU warrant card, your reflection in the lift mirror |
| Establish the SCU | The dispatch, the warrant card, and Nora's call: who sends you and why you're alone |
| Establish the tone | Quiet, wet, late; a city that keeps going; one lit window |
| Establish the case | Who died, where, who is upstairs, and the deadline (forensics at six) |
| Create curiosity | The cold open: someone, somewhere, declines Daniel's call at 11:47 |
| Hand over control | The lift doors open onto Level 9. Sam is waiting. |

**Hard rule:** show nothing the player should discover themselves.
- No phone on the desk.
- No second cup.
- No badge log.
- No named decliner.

The v1 briefing shot shows the second cup, so this intro **replaces**
`CaseBriefingView` (see §6).

## 2. Runtime

**About 2 minutes 49 seconds** to full control (within the approved 2–4 minute
opening window).

| Beat | Target | Treatment |
|---|---:|---|
| Cold open | 0:00–0:20 | Establishing bedroom move, clock insert, phone close-up, ringed hand turns it over, cut to black. |
| Kota Arwana | 0:20–0:47.5 | Aerial push, LRT pass, mamak tableau, dispatch over the unmarked car. |
| The call | 0:47.5–1:38 | SCU warrant close-up, caller screen and detective in the car, Nora's complete briefing, road view toward the tower. |
| Arrival | 1:38–2:00 | Sedan and patrol car, rising move to the single lit ninth-floor window, detective at the entrance. |
| Lobby | 2:00–2:14 | Constable's greeting, badge reader acceptance, detective crosses the turnstile. |
| Lift | 2:14–2:49 | Doors close; floors climb; message arrives; player can look around the mirrored car; a short arrival pause, then doors open and control hands over. |

**Why this length (PC-first reference)**
- The owner asked for 2–4 minutes.
- On PC, with cinematic presentation as the reference, roughly 2:50 is long enough to
  set up Kota Arwana, the SCU, Nora and the stakes without a single line of
  exposition the room could tell instead.
- It is short enough that the first thing the player *does* happens under three
  minutes in.
- The lift segment turns the last 35 seconds into presence rather than
  waiting.

**Skip rules**
- First viewing: hold **Space** or **E** for 1 second to skip. Escape is
  Roblox-reserved.
- Every later run starts at the lift doors (shot `LIFT-OPEN`).
- Subtitles are always on for Malay lines.

## 3. Shot map

Framing remains letterboxed until the lift opens. The production cut uses 21
shots with moving wides, compressed inserts, deliberate hard cuts, restrained
focus pulls and a longer player-controlled lift passage. The count and running
times below describe the current implementation.

| # | Time | Shot | Story action / sound |
|---|---:|---|---|
| 1–5 | 0:00–0:20 | Bedroom: wide, clock, ringing phone, hand, empty hold | Rain and room tone; phone is the loudest event; the ringed hand flips it face down; cut to black. |
| 6–9 | 0:20–0:47.5 | City aerial, LRT, mamak, dispatch | Traffic motif enters; train and mamak ambience; Malay dispatch identifies Wisma Delima, level nine, and the 12:14 guard report. |
| 10 | 0:47.5–0:52.5 | Warrant insert | Player-specific SCU identity and headshot; Nora calls. |
| 11–13 | 0:52.5–1:38 | Three car framings | Caller ID and the detective's silhouette; Nora gives the complete case setup and deadline; the final move finds the tower through the windshield. Dialogue stays text-first. |
| 14–16 | 1:38–2:00 | Forecourt, ninth-floor tilt, entrance | Sedan stops; the one lit window anchors the upward move; the investigator steps into the building. |
| 17–18 | 2:00–2:14 | Constable, access reader | Sam is upstairs; the badge is accepted and logged at 12:38 AM; the investigator passes through. |
| 19–21 | 2:14–2:49 | Lift ride, arrival pause, doors | Floors climb; the mirror and ROSAK dome are discoverable by looking; Nora's message arrives; score falls away before the doors open. |

The ROSAK tape remains unexplained and has no interaction prompt. The access
caption is not evidence. No case facts are granted or marked discovered during
the scene. The player receives control at the same lift-door handoff on first
play and replay.

### The approved storyboard

The storyboard the owner approved, kept as the reference for story content.
Its shot numbers (1–17) are the ones §7 cites. The production cut above
re-times and splits these beats into 21 shots, and nothing here was dropped
from the story: the tablets and the face-down phone (`sets/Bedroom.luau`), the
access caption and Nora's message (`Case001Intro.luau`) and the ROSAK dome
(the real lift car, `OfficeShell.luau`) are all built.

#### Scene 1 — "11:47" (cold open), 0:00–0:22

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 1 | 0:00–0:06 | Black, then a slow fade to a dark bedroom, locked-off wide | Rain streaks a window; the city glows orange through it. A bedside clock: **11:47**. | Rain on glass; air-conditioning hum | — |
| 2 | 0:06–0:14 | Close-up, top-down on the bedside table | A phone buzzes face up: **Daniel ♥**. Beside it, a strip of migraine tablets, **none pressed out**. | Vibration on wood, loud in the quiet | — |
| 3 | 0:14–0:20 | Insert, same angle | A hand with a thin gold wedding band comes in, hovers, and **turns the phone face down**. The buzzing stops. | Buzz, then stop. Rain. | — |
| 4 | 0:20–0:22 | Hold on the face-down phone | Nothing moves | Rain | Cut to black |

We never see a face, a room detail that names her, or a lanyard.
- The unopened tablets are there for the rare player who remembers them when
  Meera says "I took something. I was out by ten."
- It's never pointed at and never needed.

#### Scene 2 — Kota Arwana, 0:22–0:50

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 5 | 0:22–0:30 | Aerial wide, slow push over the city at night in rain | The towers of Dataran Arwana; the dark curve of the Sungai Arwana; the old town's low roofs lit orange | Rain; distant traffic. The **motif** enters: low keys and a single plucked-string line. | — |
| 6 | 0:30–0:36 | Low wide, under an LRT viaduct | A two-car LRT crosses overhead; the rails' light washes the wet road | The train's rising whine and rattle | — |
| 7 | 0:36–0:42 | Street level, across the road | A 24-hour mamak, full at half twelve. Football on a wall TV, a teh tarik pulled high. A delivery rider in a rain poncho waits by his bike. A sign on the lamppost: *DILARANG MELETAK KENDERAAN*. | Mamak chatter, a TV cheer, rain on awnings | — |
| 8 | 0:42–0:50 | Tracking alongside an unmarked sedan at a red light | Wipers. The police radio crackles. | **Radio, in Malay:** "Kawalan kepada semua unit. Kes mati mengejut, Wisma Delima, Jalan Merbau, tingkat sembilan. Dilaporkan pengawal keselamatan, dua belas empat belas pagi." | Subtitle: *"Control to all units. Sudden death, Wisma Delima, Jalan Merbau, ninth floor. Reported by the security guard at 12:14 AM."* |

#### Scene 3 — The call, 0:50–1:40

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 9 | 0:50–0:56 | Insert: the passenger seat | A lanyard and warrant card: **JABATAN POLIS KOTA ARWANA · UNIT KES KHAS / SPECIAL CASES UNIT**, the player's avatar headshot, **INSPEKTOR [DisplayName]** | The phone starts ringing | — |
| 10 | 0:56–1:30 | Medium, the driver's side through a rain-streaked window, the face lit by the dashboard phone | The detective answers on speaker. The light turns green. | Nora's call (script §4); the motif low underneath | Caller ID: **SUPT. NORA — SCU**. Dialogue in the conversation style. |
| 11 | 1:30–1:40 | Over-the-shoulder through the windscreen | Between towers, **Wisma Delima**: mostly dark, and **one lit window on the ninth floor** | The motif lifts slightly; wipers | — |

#### Scene 4 — Wisma Delima, 1:40–2:05

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 12 | 1:40–1:48 | Wide, the tower forecourt | The sedan stops beside a patrol car, lights off. The detective (the player's avatar) steps out into the rain. | Car door; rain gets louder | — |
| 13 | 1:48–1:56 | Tilt up the tower face | The ninth-floor window is still lit | Rain; the motif at its peak, then easing | — |
| 14 | 1:56–2:05 | Lobby, medium | Marble, a closed coffee kiosk, an empty guard desk (Sam is upstairs). A patrol constable by the door straightens and nods the detective through ("Tingkat sembilan, Inspektor."). The detective taps the warrant card on a turnstile reader. | *Beep* | Reader screen: **SILA IMBAS KAD** changes to **DITERIMA · 00:38**. A small caption: *Access logged 12:38 AM.* Subtitle: *"Ninth floor, Inspector."* |

Shot 14 quietly teaches that the building remembers every badge. It pays off
when Sam prints the log. It does not mention Victor.

#### Scene 5 — The lift, 2:05–2:40 (mouse-look, no movement)

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 15 | 2:05–2:30 | First-person-ish, inside the lift car, player controls the look | The floor display climbs G → 9. A mirrored back wall shows the player's avatar. A lift certificate in a frame. In the ceiling corner, a small CCTV dome with **ROSAK** tape across it. | Lift hum; the motif fades to nothing | Floor numbers. At about 2:15 the phone buzzes: a message from **Nora**: *"Jangan lupa makan."* ("Don't forget to eat.") |
| 16 | 2:30–2:36 | Hold | The display reads **9** | *Ding* | — |

The ROSAK tape is the first thread of *Titik Buta* (`LONG_TERM_MYSTERY.md`).
- It has no prompt and no explanation.
- Most players won't see it; the ones who do will remember it when the office
  cameras are dark too.

#### Scene 6 — Level 9, 2:36–2:40, then control

| # | Time | Shot | Action | Sound | On screen |
|---|---|---|---|---|---|
| 17 | 2:36–2:40 | The player's own camera, as the doors slide open | Level 9 reception in after-hours light. **Sam** steps forward from beside the counter. | Doors; air-conditioning; the records-room tube flickering. **Silence where the music was.** | Title card over the opening doors: **CASE 001 — THE LAST CALL** · *Rozario & Lim · Tingkat 9 · 12:40 AM*. It fades as Sam speaks. |
| — | 2:40 | **Control.** The letterbox retracts. | Sam: "Detective? Hey. Over here." (v1's first line, unchanged) | — | The first interaction prompt |

## 4. Dialogue (Scene 3)

Speaker names appear as in conversations. The detective's lines are short and
neutral. The player is never gendered.

> **NORA:** *Dah sampai?* (There yet?)
> **YOU:** Five minutes.
> **NORA:** Daniel Rozario. Forty-one. Half of Rozario and Lim, the design firm on nine.
> **NORA:** The guard found him just after twelve. The ambulance took him to Hospital Besar. Patrol taped the floor. Forensics can't get there till six.
> **YOU:** So until six—
> **NORA:** Until six, it's yours.
> **NORA:** His wife is up there. So is his partner. Nobody's gone home.
> **NORA:** They've had two hours to decide what happened. You haven't had any. Good.
> **NORA:** Listen to all of them. Believe the room.
> **YOU:** And you?
> **NORA:** I'll be asleep. Call me when you know.

Line by line, what each one is doing:
- **"Dah sampai?"** Malaysia in two words; Nora's economy.
- **"Half of Rozario and Lim"** plants the partnership without explaining it.
- **"Forensics can't get there till six"** justifies a lone detective and sets
  a deadline that pays off at dawn. It also explains the tape marks with no
  body.
- **"Wife… partner… nobody's gone home"** tells the player who is on the floor
  without saying why.
- **"Believe the room"** is the game's thesis, said once, in character. It is
  never repeated as a tooltip.
- **"Jangan lupa makan"** (the message in the lift) is Nora's care, in the most
  Malaysian way she knows.

**Voice.** The intro is written text-first, with subtitles. VO is optional
later. If it is recorded, Nora's actor should be a Malaysian Malay woman in her
fifties, and the dispatcher's Malay must be natural radio Malay, not a
translation.

## 5. Sound and music

**Diegetic first.** Rain, the LRT, the mamak TV, the radio, the phone, the
wipers, the turnstile beep, the lift hum and ding, air-conditioning, the
flickering tube.

**One motif for the case.**
- Instruments: low piano or keys, with a single plucked-string line.
- Where it plays: Scenes 2–4 only. Silence in the cold open.
- How it ends: it fades in the lift and is gone when the doors open.
- It returns once, in the Solved dawn outro.

**Mix.** The phone buzz in the cold open is the loudest thing in the first
twenty seconds. It should feel intrusive.

**Don't:** use stock "Asian" instrument clichés to signal Malaysia. The city,
the radio, the language and the food do that.

## 6. How it fits the current game

- **Title screen** (`TitleScreenView`): stays as the menu. First play goes
  Play, then the intro, then control. Replays go Play, then Shot 17.
- **Briefing** (`CaseBriefingView`): **retired for CASE-001.** It shows the
  second cup, and the intro now does its job. Keep the code for future cases
  that want a static briefing.
- **Spawn:** the player spawns *in the lift car* at Level 9. The existing office
  has a lift at reception (`ElevatorPanel`); a lift-car interior is built behind
  its doors.
- **Case state:** nothing is discovered during the intro. The access-log
  caption in Shot 14 is not evidence.

## 7. Withheld and foreshadowed

| Withheld | Revealed by |
|---|---|
| Who declined the call | Meera's admission (CONTRA-003); the cold-open hand and ring rhyme with her |
| That the call was *declined*, not missed | The phone (EV-001) |
| Victor came back | The badge log (EV-004), printed only when you ask |
| How Daniel died | The marked floor, the photo, the watch data |
| Why the cameras are dark | The monitor note and, in the epilogue, the PANTAU receipt |
| What Daniel wanted to say | The unsent message (EV-011), if Meera opens the phone |

| Foreshadowed | Where |
|---|---|
| The face-down photo | The face-down phone (Shot 3) |
| Meera's lie about sleeping | The unopened tablets (Shot 2) |
| Badge readers log everything | The turnstile beep and caption (Shot 14) |
| Dark cameras | ROSAK on the lift dome (Shot 15) |
| Dawn as the deadline | "Forensics can't get there till six" |

## 8. Production notes (the original proposal; now built)

**New sets**
- A small condo bedroom (Bukit Pelangi).
- A street strip with the LRT viaduct, the mamak and the rider.
- A car interior.
- The Wisma Delima forecourt and lobby.
- A lift car.
- These can be dressed sets, not explorable spaces. Only the lift needs player
  presence.

**Reuse**
- The skyline (`CitySkyline`).
- DialogueView's letterbox and subtitle styling.
- `CameraController` scripted shots.

**New system**
- A small cinematic sequencer: shots as data (camera path, duration, subtitle
  lines, sound cues), skippable and replay-aware.
- It should also serve the dawn outro and future case intros.

**Avatar use**
- The warrant card headshot via the player's avatar thumbnail.
- The lift mirror showing the real avatar.
- The display name on the card.

Built in Phase 5.5 as `CutsceneService` (server-timed shots, replay from
`LIFT-OPEN`), `CutsceneView` (letterbox, captions, hold-to-skip),
`CutsceneSets` with one module per dressed set in `src/client/sets`, and
`CutsceneLighting` presets in `Config.Cutscene.Lighting`. See
`ARCHITECTURE.md`, "The case intro and scene presentation (Phase 5.5)".

## 9. Prototype specification: an animatic before any sets

To test pacing cheaply, build a **throwaway animatic place** (not the game
place) before committing to sets:
- block-out boxes for the bedroom, street, car and lobby;
- the existing office and skyline for the tower shots;
- the shot list above as timed camera cuts;
- the subtitles and a temp soundtrack.

Watch it three times and cut anything that drags. Only then build sets.

## 10. Production pass notes (full audit, 2026-10-02)

Story, dialogue, timing and shot count are unchanged: 21 shots, 169 seconds,
replay from `LIFT-OPEN`. What changed is how the shots read on screen.

- **City aerial.** The camera sits lower and closer, with a narrower lens
  (FOV 48), so the towers fill the frame instead of a far, fogged grid. The
  city set keeps its geometry within ~500 studs of the camera, where Roblox
  still draws small parts, and the haze was thinned so the lit windows
  survive.
- **Street (LRT and mamak).** Rebuilt as a place: a guideway on piers that
  the train crosses, two-storey shophouses with a few rooms lit upstairs,
  sodium lamps on both kerbs, a lit mamak interior behind the glass,
  stools at the tables. The unmarked car drives in along the kerb as one
  model, headlamps lit, and pulls up (only its body used to move, leaving
  the roof, wheels and lamps behind). The mamak shot frames the teh tarik
  and the rider at a tighter lens.
- **Car.** Nora's first framing is tighter on the phone. The windscreen shot
  looks up at Wisma Delima, with lamp posts and rain along the road.
- **Forecourt and lobby.** The sedan drives in and the investigator steps out
  of the driver's door; the tower carries its name; the lobby has a ceiling
  and downlights. The investigator's double is placed by its feet, so it
  stands on the floor in every set whatever the avatar's proportions (it was
  placed by its root before), walks to the reader and through the gate.
- **Lift.** Its own lighting preset (`Lift`): a dim, cool, closed car
  instead of the lobby's look, with a softer ceiling panel.
- **Sound.** The phone's buzz stops when the hand turns it over, and the
  motif is listed on every shot it plays through, so it carries unbroken
  from the city to the lift (a test pins this).
- **Known gap.** The constable is a simple block figure, not a rigged
  character (`ROADMAP.md`, 5.6). The horizon glow behind the city, which did
  not render at its distance, was fixed in the playthrough pass.
