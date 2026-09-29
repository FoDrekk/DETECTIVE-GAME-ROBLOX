# Detective Toolkit

Status: **design.** Built today: the Case File, the timeline, interrogation with
"show". Everything else is proposed. Decisions: `DESIGN_DECISIONS.md` D-29 to
D-31.

## Principles

1. **Every tool answers "what can the player discover with this?", never "what
   answer does it give?"** A tool surfaces *information*. The player still makes
   the connection in the Case File.
2. **One new tool per case, taught by the case that needs it.** Nothing arrives
   in a bundle, and no tool appears before a case uses it.
3. **Tools produce facts, not verdicts.** Their output lands in the Case File as
   evidence or statements, the same currency as everything else, so the
   existing reasoning and accusation systems keep working unchanged.
4. **Unlocked by story, never by XP.** No levels, no upgrade trees, no currency
   (D-31).
5. **Server-authoritative.** What a photo contains, what footage shows and what
   a record says are decided on the server from case data. The client displays;
   it never decides.
6. **PC-first controls, mobile-adaptable.** Mouse and keyboard are the
   reference. Every tool also works as tap-and-hold or on-screen buttons later
   (OD-04).
7. **Stylish but plausible.** The feel is spy-gadget cleverness, not
   magic: nothing an SCU detective couldn't carry in 2026.

## Progression (Season 1, provisional after CASE-002)

| Case | New tool | What the case teaches with it |
|---|---|---|
| CASE-001 *The Last Call* | **Case File**, **Timeline**, **Interrogation ("show")** (all built) | Pair facts, answer questions, order the night, confront with evidence |
| CASE-002 *Seventeen-Seven* | **Phone Camera**, **CCTV Review**, **Address Pins** | Photograph what matters, show it to anyone, scrub footage, read the city to navigate |
| CASE-003 (working) | **Records Request** | Ask the system (e-wallet, tap card, vehicle registry) the right question, for a reason |
| CASE-004 (working) | **UV Torch** | See what someone tried to clean away |
| CASE-005 (working) | **Scene Reconstruction** | Rebuild the moment and test your theory against the physical evidence |
| Season 2 | **Directional Mic** | Overhear public conversations you aren't part of |

## The tools

### Case File (built)
- **Lets the player discover:** that two facts don't fit (contradictions), and
  what a set of facts means (deductions, answered as questions).
- **Never:** pairs facts by itself or hints which pair matters.
- **Grows into:** the **case board** at the SCU hub (cases, the Dossier). With
  30 or more facts per case, the Case File needs filtering by person and place
  (`WORLD_SCALABILITY.md` §7).

### Timeline (built)
- **Lets the player discover:** the order of the night, and the gaps in it
  (CASE-001 v2: the eleven minutes where everything happens).
- **Never:** orders itself before the player does.
- **Grows into:** the input to Scene Reconstruction.

### Interrogation and "show someone something" (built for suspects; generalised in CASE-002)
- **Lets the player discover:** how a person reacts to a thing: recognition,
  a lie, a slip, a memory.
- **Never:** makes a person explain the case.
- **Grows into:** *the* world mechanic. You can show any photo or item to any
  Tier-1 or Tier-2 person (`NPC_WORLD_DESIGN.md` §3).

### Phone (the hub, story-only in CASE-001)
- **What it is:** where the other tools live. Calls and messages (Nora,
  witnesses who call back), the Camera roll, the Map with pins.
- **Lets the player discover:** very little by itself, on purpose. It's a
  container, not an oracle. There is no search engine or "find person".

### Phone Camera (CASE-002)
- **Lets the player discover:**
  - details they can carry away and compare (a sticker, a plate, a face, a
    shoe print);
  - who recognises something when they are shown it.
- **How it works:**
  - Aim and take (PC: right-mouse to raise, left-click to shoot).
  - The server decides whether the frame contains an *authored subject* (a
    tagged detail within the frame and range).
  - If it does, the photo becomes an evidence item ("Photo: motorbike plate,
    back lane").
  - If not, it's just a photo in the roll, with no penalty and no hint.
- **Never:** identifies anyone, matches faces or reads text for you.
  Comparison is done by the player, by showing photos to people or setting
  two photos side by side.

### CCTV Review (CASE-002)
- **Lets the player discover:** a moment on a recording:
  - a rider with **no delivery bag**;
  - a door opening at a time someone said they were elsewhere;
  - a camera that shows *nothing* when it should.
- **How it works:**
  - A scrub bar with speed controls. The player marks moments.
  - A marked authored moment becomes evidence ("Back-lane camera, 6:55 PM").
  - Unauthored moments just show the city.
- **Never:** flags the important frame, auto-tracks anyone or enhances an image
  into an answer.
- **Why it's Malaysian:** cameras are everywhere, owned by everyone (mamak back
  doors, guardhouses, lifts, dashcams), and half of them are broken or
  pointed at the wrong thing.

### Address Pins (CASE-002)
- **Lets the player discover:** *where to go next* by reading: a receipt, a
  signboard, a tenancy agreement, a parcel label.
- **How it works:**
  - Any readable address in examined evidence can be **pinned**.
  - Pins appear on the phone Map and are the only e-hailing destinations.
  - Nothing is pinned for you.
- **Never:** reveals a location the player hasn't read. There is no "go to
  next objective" marker, ever.
- **The small Malaysian puzzle:** shoplot numbering (*No.12* downstairs, *12-1*
  upstairs), numbered *Jalan* sections, block and unit numbers
  (*Blok B, 17-07*).

### Records Request (CASE-003, working)
- **Lets the player discover:** what the city's systems recorded:
  - e-wallet merchant transactions (who paid where, when);
  - tap-card journeys;
  - vehicle registration by plate;
  - a tenancy record.
- **How it works:**
  - From the phone, the player files a request **citing a fact already in the
    Case File** as justification ("plate photographed in the back lane").
  - A request without a relevant fact is refused ("On what grounds?").
  - The result arrives as evidence.
- **Why the justification:** it stops "request everything" brute force by
  making the player reason *before* asking. The cost is thinking, not a
  currency.
- **Never:** answers a question the player didn't ask, or returns more than was
  asked.

### UV Torch (CASE-004, working)
- **Lets the player discover:** what was cleaned or hidden: a wiped desk edge,
  a scrubbed doorframe, a note in invisible ink, a shoe track on a mopped
  floor.
- **Never:** labels what it reveals. A glowing wiped area is a fact ("someone
  cleaned this"); *why* is the player's deduction. It is non-graphic: no bodily
  fluids.

### Scene Reconstruction (CASE-005, working)
- **What it is:** the Batman-detective feeling, earned.
- **Lets the player discover:** whether their theory fits the physical scene.
- **How it works:**
  - After ordering a timeline, the player places people and objects (ghost
    figures) into a scene at key moments.
  - The reconstruction plays back.
  - Where it collides with a physical fact (a door that was locked, a sightline
    that was blocked, a dry patch under a car), the collision is shown *as a
    fact* the player must explain.
- **Never:** says "correct". It only shows where the world disagrees with you.

### Directional Mic (Season 2)
- **Lets the player discover:** things people say in public when they think
  nobody's listening (a mamak table, a bus stop, a car park).
- **Never:** gives you a full confession. It gives fragments, and the player
  decides what they mean.

## Rejected tools

| Tool | Why not |
|---|---|
| **Fingerprint kit** | In practice a database-match tool, which invites "scan and read the name" solving. If prints ever return, only as "matches a print *you* lifted earlier", and not before Season 2. |
| **Audio recorder** | Statements are already recorded in the Case File word for word. It adds nothing. |
| **Evidence scanner / "detective vision" highlight** | An answer machine. It kills "I noticed something". |
| **Phone location tracking** | Solves "where was this person?" in one button, the question the city exists to make you answer. |
| **Lie detector / stress analysis** | Tells the player who is lying. The Case File exists so they work it out. |
| **Hacking minigames** | A different game. Reading a laptop is examining evidence, not a puzzle about hacking. |
| **Drone** | Pulls the camera and scale up and away from the human, walking pace of investigation. |
| **Disguise / voice changer** | Too close to the inspirations' signature gadgets, and not detective work. |

## Mobile adaptation notes (for later, not a constraint now)

- Camera: an on-screen shutter; hold to raise.
- CCTV Review: a larger scrub handle.
- Pins: long-press to pin.
- Records Request: pick the fact from a list.
- None of the tools needs precision aiming beyond what PC testing sets as the
  bar.
