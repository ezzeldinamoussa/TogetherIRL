# TogetherIRL

A mobile app for planning group hangouts: shared preferences, AI-generated
itineraries from real nearby places, live group voice, bill splitting and
shared photo albums.

CCNY Senior Design Project — CSC 59866 / 59867.

## Stack

| Part | Built with |
|---|---|
| Mobile app | Flutter / Dart 3, `provider` for state |
| API backend | Dart with `shelf`, port 3000 |
| Voice signaling | Python with FastAPI, deployed on Render |
| Database, storage, auth | Supabase (Postgres, Storage, email/password auth) |
| External services | Google Gemini, OpenStreetMap/Overpass, OCR.space, LiveKit Cloud, Zippopotam |

## Running it locally

You need the Flutter SDK, the Dart SDK and Android Studio with an emulator.

**1. Clone and install dependencies**

```bash
git clone <repo-url>
cd TogetherIRL
flutter pub get
cd backend && dart pub get && cd ..
```

**2. Create `backend/.env`**

Not in git. Ask a teammate for the Supabase and OCR values:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...
OCR_SPACE_API_KEY=...
PORT=3000

# Get your own free key at https://aistudio.google.com/apikey
GEMINI_API_KEY=...
```

Use **your own** Gemini key. Free-tier quota is metered per project, so a
shared key means a shared daily cap and generation starts failing for
everyone once it runs out.

**3. Run the backend, then the app**

```bash
cd backend && dart run server.dart    # leave this running
flutter run                            # in a second terminal
```

The app reaches the backend at `10.0.2.2:3000`, which is the Android
emulator's alias for your machine. Running on a physical phone needs the
backend deployed somewhere reachable — that hasn't been done yet.

### Itinerary generation

Generation takes about 50 seconds, most of it waiting in the queue at the
public Overpass endpoint. It is not frozen. Overpass also returns 429 and 502
intermittently; a failed batch retries on its own, and the backend logs a
warning if the place list still came back incomplete. Watch the backend
terminal — it logs each stage, which Gemini model answered, and the plan
titles.

Every member needs a starting location set, or generation fails with an error.

### TableTalk

No local setup needed. The Python signaling service is already deployed at
`togetherirl.onrender.com` and the app points at it. You only need
`signaling/` if you are changing or redeploying that service — the LiveKit
setup steps are in this file's git history, before November 2026.

Voice needs a real microphone. Two Android emulators on one machine share
the host's single microphone, so test across two machines or two phones.
The iOS Simulator has no microphone at all.

### Memories

Photos stay sealed until the collection's 24-hour window closes or every
member has uploaded or skipped, whichever comes first. Before that you only
see your own, so a photo that looks missing during testing is usually the gate
working as intended.

In a two-person group the gate opens as soon as both respond, so to see the
sealed state you need one member to stay pending.

## Project layout

```
lib/              Flutter app
  screens/        one file per screen
  services/       everything that talks outside the app
  providers/      ChangeNotifier state, one per feature
  widgets/        shared UI
backend/          Dart API server
  src/controllers/  one per feature
  src/config/       env and the Supabase wrapper
  src/middleware/   JWT auth
signaling/        Python voice service
android/          platform config — keep this in git
```

Useful entry points:

| If you need to change | Look at |
|---|---|
| The backend URL | `lib/config.dart` — the only place it appears |
| Any call to the backend | `lib/services/api_service.dart` |
| Backend routes | `backend/server.dart` mounts every controller |
| Authentication | `backend/src/middleware/auth_middleware.dart` |
| Database schema | `backend/schema.sql` — **incomplete, see below** |
| Itinerary generation | `lib/services/itinerary_ai_service.dart` and `places_service.dart` |

## Branches

| Branch | What it is |
|---|---|
| `main` | Production |
| `test_main` | Integration branch under final testing, merges to `main` when it passes |
| `audio` | TableTalk development. Merged into `test_main`; can be deleted afterwards |
| `backend` | Abandoned April scaffolding. Do not merge — it predates the app code and a merge deletes files silently |

## Known gaps

- **`backend/schema.sql` defines 6 of 12 tables.** Running it against a fresh
  Supabase project will not produce a working database.
- **No test suite.** `test/widget_test.dart` is the unmodified Flutter template.
- **Itinerary generation takes about 50 seconds**, most of it queue wait at the
  public Overpass endpoint.
- **Release builds are signed with debug keys**, which app stores reject.
