# Kota Arwana — World Foundation

Status: **pre-production foundation.** Nothing here is built except the CASE-001
floor. Decisions: `DESIGN_DECISIONS.md` OD-01, OD-09, D-23 to D-28.

> **Kota Arwana: a city that grew too fast around an old river.**

Kota Arwana is fictional. It is inspired by the texture of Malaysian cities (the
Klang Valley above all), but it recreates no real city, road or building.
Everything is named from scratch and checked before it ships (§9).

---

## 1. Identity

The Sungai Arwana bends through the valley, and the **old town** sits on its
banks:
- pre-war shophouses, a wet market, a 1930s police station;
- a temple and a surau on the same street;
- kopitiam that open at six.

In the last thirty years the **towers** went up behind it, the **LRT** was
threaded over the roads, and condos climbed the hills where the rubber estates
used to be. The city is prosperous, humid, crowded and always slightly
unfinished: a new mall beside a mamak that has been there since 1987, a CCTV
camera beside a hand-painted *NO PARKING* sign.

For a detective that texture is the point. **Kota Arwana is a city that writes
everything down and still loses track of people:**
- badge readers, visitor logs, dashcams;
- QR receipts, delivery apps, group chats;
- and cameras that don't work.

## 2. Geography (sketch)

```
            BUKIT PELANGI (condos, hillside)          TAMAN SERI CEMPAKA
                  │  Laluan Bukit (LRT)                 (terrace suburb)
                  │                                            │
  SIMPANG KENARI ─┼──── ARWANA SENTRAL (interchange) ──────────┘
  (mamak / night)  │            │
                  │     DATARAN ARWANA (CBD towers, Wisma Delima)
                  │            │
   ~~~~~~~ SUNGAI ARWANA ~~~~~~~~~~~ Laluan Sungai (LRT) ~~~~~~~~~
                  │
            KOTA LAMA (old town; Balai Lama: the SCU; Kompleks Awam)
                  │
     KAWASAN PERINDUSTRIAN BATU HAMPAR (industrial, downriver)
```

- **Two LRT lines** cross at Arwana Sentral: *Laluan Sungai* (the river line,
  old town to CBD) and *Laluan Bukit* (the hill line, CBD to the condos and the
  suburb).
- A highway (never driveable) rings the city and is seen from windows.

## 3. Districts

"Built" means playable in the current game.

| District | Character | Investigation value | Planned use | Status |
|---|---|---|---|---|
| **Dataran Arwana** (CBD) | Glass towers, lobby turnstiles, covered walkways, food courts in basements | Badge logs, lifts, guards, building CCTV, office politics | CASE-001 (Wisma Delima, Level 9) | **Level 9 built** |
| **Kota Lama** (old town) | Pre-war shophouses, five-foot ways, back lanes, wet market, kopitiam, temple, surau, Balai Lama | Families who've been there forty years, back-lane escapes, upstairs rentals, people who notice strangers | **SCU hub** (Balai Lama); future cases | Concept |
| **Bukit Pelangi** (high-rise residential) | Condos and serviced residences with guardhouses; a commercial shoplot row below; a car park that becomes a pasar malam on Wednesdays | Visitor logs, lift CCTV, delivery riders, neighbours, residents' group chat | **CASE-002** (Residensi Pelangi, Pelangi Square) | Concept, **first slice to build** |
| **Simpang Kenari** (mamak and night strip) | A 24-hour mamak row, KTV lounges (exteriors only), a 24-hour convenience store, a car wash, money changers | Late-night witnesses, QR timestamps, riders, dashcams | Side mysteries; later cases | Concept |
| **Taman Seri Cempaka** (suburb) | Double-storey terraces, auto-gates, grilles, a playground, a surau, the neighbourhood watch post | Dashcams, doorbell cameras, the aunty network, the rukun tetangga (residents' association) group | A daytime case | Concept |
| **Arwana Sentral** (transit) | The LRT interchange, bus bays, a food court, crowds | Tap-card records, CCTV, lost-and-found, people passing through | Transit hub; a chase-free case | Concept |
| **Batu Hampar** (industrial) | Warehouses, workshops, lorry yards, workers' hostels | Isolation, vehicles, shift rosters | The late season (*Titik Buta*) | Concept |
| **Kompleks Awam** (civic, in Kota Lama) | Hospital Besar Arwana and its mortuary, the courts, the JPKA headquarters, the land office | Forensics results, records, the institutional voice | Visits and records, not free roam | Concept |

**Start with two places, not eight:** the Level 9 floor (built) and Pelangi
Square (CASE-002). Kota Lama's Balai Lama follows as the hub.

## 4. Density rules

- **Walkable.** A district crosses on foot in about 2–3 minutes. If it takes
  longer, it's too big for what's in it.
- **5–10 enterable places per district**, each earning its keep. Every
  enterable interior must host at least one of:
  - a case scene;
  - a side mystery;
  - a persistent local (Tier 2).
- **Everything else is facade.** A good facade (signboard, grille, light,
  noise) is worth more than an empty interior.
- **Interiors are sets, not simulations.** A flat is one unit; a tower is its
  lobby, a lift and the floors a case needs.
- **Reuse with changes.** A shoplot row is a kit, but no two rows share the same
  signboards, stock or owners.
- **The street is readable.** Road names (*Jalan Pelangi 3*), unit numbers
  (*12-1*), signboards and notices are legible, because reading them is how
  you navigate (see `DETECTIVE_TOOLKIT.md`, address pins).

## 5. Getting around

| Mode | Use | Why |
|---|---|---|
| **Walking** | Inside a district, always | Investigation happens at walking pace |
| **LRT** | Between districts: board at a station, pick a station, arrive | Diegetic fast travel, very Malaysian, no driving systems |
| **E-hailing** (the working-name app *Naik*) | To a place you have **pinned** | Rewards reading addresses; a short ride cutscene, never a drive |
| **Driving** | **Never** (for now) | Costly to build, invites a GTA drift, adds nothing to deduction |

## 6. Time, weather and the hub

- **Case time, not world time.**
  - Each main case sets the world's time and weather for its scenes.
  - CASE-001 is 12:40 AM in rain; CASE-002 is a Wednesday evening, dry and
    humid, with a pasar malam.
  - There is no global clock to simulate, and no day/night cycle to break a
    case's clues.
- **Weather is authored.**
  - The 4 PM thunderstorm, a flash-flooded underpass, the haze.
  - Used when a case wants it, and sometimes *as* a clue (a dry patch under a
    car that "hadn't moved all evening").
- **The hub: Balai Lama, Kota Lama.**
  - The SCU works from the top floor of a 1930s police station.
  - Inside: Nora's office, a **case board** (cases, the Dossier, notes) and an
    evidence room.
  - Stairs go down to the old town. The hub opens after CASE-001.

## 7. Malaysian identity catalogue

The sources are real Malaysian urban life. The rules are in §8.

**Architecture**
- Pre-war shophouses with five-foot ways and timber shutters; post-war shoplot
  rows (*kedai deret*) with the unit number over the door.
- Condos with a guardhouse, a boom gate and visitor registration; low-cost flats
  with laundry poles.
- Double-storey terraces with auto-gates and window grilles; covered walkways;
  monsoon drains; surau and temple rooftops; mosque domes on the skyline.

**Roads and parking**
- *Jalan* names with numbered sections (*Jalan Pelangi 3*, *Jalan 14/2*);
  U-turn lanes, flyovers.
- Parking by app or coupon, parking attendants, double-parking with a phone
  number on the dashboard.
- Motorbikes sheltering under flyovers in rain, and the delivery riders
  everywhere.

**Signage**
- A real mix: Malay, English and Chinese (and Tamil where the neighbourhood
  would have it). In-game player-facing signage is English (Phase 5.6);
  proper nouns stay local (*Wisma Delima*, *ROSAK*).
- Official and handmade notices: *NO PARKING*, *AWAS*,
  *EXIT*, *ROSAK*, *Tap access card*.
- Hand-written shop signs; prices in RM.

**Businesses**
- The 24-hour mamak, the kopitiam, economy rice, the pasar malam.
- The hardware shop, the phone-repair and used-laptop shop, the laundromat.
- The goldsmith, the money changer, the tuition centre, the car wash, the
  printing shop, the 24-hour convenience store.
- **All brands fictional.**

**Food as information**
- Receipts that say *Teh O Ais Limau*, *Roti Telur*, *Nasi Lemak Bungkus*,
  with a time.
- A teh tarik ring on a table; a bungkus left on a car seat; who orders what
  at 2 AM.

**Transport**
- The LRT and tap cards, feeder buses, e-hailing, food-delivery riders.
- Riders are the city's night witnesses (`NPC_WORLD_DESIGN.md`).

**Technology** (all fictional apps, working names cleared before ship)
- QR e-wallet payments (*SenPay*) that leave a merchant, a time and a name.
- Messaging (*Sembang*) with read receipts; family and residents' group chats.
- Food delivery (*Bungkus*) with order codes; ride-hailing (*Naik*).
- Dashcams in most cars; CCTV everywhere, half of it broken.

**Documents**
- Identity cards in a fictional format (never a copy of the real MyKad design).
- Tenancy agreements, parking summonses (*saman*), statutory declarations.
- Guardhouse visitor logs, second-hand dealers' seller records, company forms
  (*Sdn. Bhd.*).

**Names**
- Malay names with *bin/binti*; Chinese names surname-first with an English
  name in daily use.
- Indian names with *a/l* and *a/p*; Eurasian surnames (Rozario, De Souza);
  Iban and Kadazan-Dusun names (*anak*); migrant workers from Nepal, Indonesia,
  Bangladesh and Myanmar.

**Language**
- English gameplay with natural Malay and Manglish code-switching (OD-07).
- UI in English; the environment speaks Malay. Guide: `NPC_WORLD_DESIGN.md` §6.

**Rhythm**
- The mamak full at midnight, the 4 PM storm, Friday midday on the streets.
- The Wednesday pasar malam; the Subuh call at first light (optional, reviewed
  per use); festival seasons as backdrop, never as a plot trick.

**Social texture**
- Neighbours who notice everything; the aunty network; the guard who knows
  everyone's car.
- **Saving face**: people who hide things out of shame, not guilt.
- Hospitality: someone always offers you a drink.

## 8. Guardrails

1. **Fictional institutions only.**
   - JPKA and its SCU are invented.
   - Real agencies are never named or imitated: no Royal Malaysia Police, no
     real road or transport authorities, no real banks or telcos.
   - Generic real concepts are fine: 999, the LRT as a *kind* of train, Subuh.
2. **No real brands.** Every app, shop, company and building is invented, and
   invented names are checked (§9).
3. **No community is coded as criminal.** Culprits, victims and witnesses rotate
   across communities. The casting ledger lives in `NPC_WORLD_DESIGN.md` §8.
4. **Religion is setting, never a device.**
   - Surau, temples, churches, prayer times and festivals appear as part of
     life.
   - No clue, alibi or twist exploits a religious practice.
   - Sacred spaces can be seen from outside or passed through respectfully;
     they are never searched.
5. **No caricature.** No comic accents, no "lah" at the end of every line, no
   exotic filters or "Asian" music stingers.
6. **Real social issues with care.** Loan sharks, phone scams and migrant labour
   can appear, grounded and humane, without lectures and without mockery.
7. **A Malaysian reader reviews** names, dialogue and cultural beats for every
   case before it ships.

## 9. Naming check (before any name ships)

For every district, building, company, app or character name:
- Search it together with "Malaysia".
- It must not be a notable real business, building, product, agency or public
  figure.
- Generic place words (*Taman*, *Jalan*, *Bukit*) are fine on their own.

Names in these documents are **working names** until checked. Examples:
- *Wisma Delima*, *PANTAU Sekuriti*, *Naik*, *Bungkus*, *SenPay*, *Sembang*,
  *Kemas Joinery Enterprise*.

## 10. What not to build yet

- More than the Level 9 floor, Pelangi Square and (later) Balai Lama.
- Driving, traffic simulation, a day/night cycle.
- An open map to explore without a case pulling you through it.
- Ambient systems (schedules, needs, crowds with memory).
- Any district before the case that needs it is written.
