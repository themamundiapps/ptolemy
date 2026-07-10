# Ptolemy — Current State & Reflection

2026-07-09. Repo: `C:\ptolemy` (GitHub: `themamundiapps/ptolemy`). Written assuming familiarity with what Ptolemy is (traditional/Hellenistic astrology app — natal chart, temperament, electional astrology tools) — this is a state-of-the-project check-in, not an onboarding doc.

## 1. Architecture recap

- **Frontend**: Flutter (`lib/`), targets **Web (Vercel)** and **Android** built, **Windows desktop** present (looks like a side effect of developing on Windows, not an intentional ship target), **no iOS** (`ios/` doesn't exist).
- **Backend**: FastAPI (`backend/app/main.py`), deployed to **Railway** at `https://ptolemy-production.up.railway.app` (hardcoded in `lib/services/api_client.dart`). 6 routers under `/api/v1`: chart, geocode, interpretations, temperament, electional, user.
- **Astronomical engine**: `pyswisseph`, Moshier analytical ephemeris (no `.se1` high-precision data files present — fine for this use case, but worth knowing if precision complaints ever come up).
- **Only external paid API**: Anthropic (`ANTHROPIC_API_KEY` in `backend/.env`) — used solely by `backend/app/services/synthesis.py` for one feature: AI-generated 3-4 sentence natal-placement synthesis (`claude-haiku-4-5-20251001`). Geocoding (OpenStreetMap Nominatim) and timezone resolution are free/keyless.
- **Persistence**: no real database. `backend/app/services/user_store.py` is a JSON-file-backed store (`backend/data/user_charts.json`) mapping Google account id → last-saved birth data — explicitly documented in-code as a deliberate scope-limiting choice, not an oversight.
- **Auth**: Google Sign-In is currently **mocked** (`lib/services/auth_service.dart` — `MockGoogleAccount`, fixed fake account after a simulated delay). No real OAuth client ID configured yet; `google_sign_in` also has no Windows desktop implementation, which is presumably why this was deferred.

## 2. Feature inventory

| Feature | State |
|---|---|
| Natal chart calculation + display | Done — chart wheel (custom-painted, Astronomicon font glyphs), planet positions, dignities, Lots, aspects, all tappable for detail sheets |
| Temperament calculation + display | Done — quality bars, per-factor breakdown, citations |
| Electional scan (checklist engine) | Done — this is the most sophisticated piece of the codebase, heavily tested (`test_electional.py` is 973 lines) |
| Electional synthesis paragraphs | Done, but **template-based, not AI** — `lib/screens/electional_synthesis.dart` rotates hand-written sentence banks (3 phrasing variants) so repeats don't read identically. Distinct from the natal AI-synthesis feature — don't confuse the two. |
| Natal AI synthesis | Done — real Anthropic API call, requires `ANTHROPIC_API_KEY` |
| City search / geocoding | Done (Nominatim) |
| Timezone resolution | Done — historically-accurate DST handling via `timezonefinder` + `pytz` |
| Onboarding carousel | Done — 3-page, shown once |
| Google Sign-In | **Mocked**, not real |
| Cross-device chart sync (signed-in users) | Backend endpoint exists (`/user/chart`) and is wired up, but sits on the mock auth + JSON-file store, so it's not production-real yet |
| Pro / paywall (Business & Career, Health & Body, Spiritual & Learning, Home & Family themes) | **UI-only stub** — "Unlock with Pro" button exists, does nothing |
| Purchase restore | **UI-only stub** — button exists with empty `onPressed` |
| Android release build | Configured but **signs with the debug keystore** — not Play-Store-submittable as-is |
| iOS | Not started — no `ios/` directory |
| Astronomicon font glyph migration | **Just completed this session** (see §3) — all 4 locations now use the bundled font instead of raw Unicode astrological symbols |

## 3. Current repo state (as of this report)

- HEAD: `52c2366` ("Fix the same Unicode-glyph bug in the Electional tab"), branch `master`, up to date with `origin/master`.
- **Uncommitted working-tree changes** (not yet committed — do this first if picking up mid-stream):
  - `lib/screens/chart_result_screen.dart` — aspect list row now uses Astronomicon glyphs instead of raw Unicode
  - `lib/widgets/aspect_detail_sheet.dart` — aspect detail sheet header now uses `Text.rich`/`TextSpan` to scope the Astronomicon font to just the glyph character (mixing it with plain English text corrupts the English letters, since the font remaps plain Latin codepoints)
  - Both verified with `flutter analyze` — no issues.
  - Context: earlier commits (`1ee569f`, `52c2366`) migrated the chart wheel and Electional tab off raw Unicode astrological Unicode symbols (BrowserStack testing found distorted/oversized glyphs on real devices) onto a bundled Astronomicon font (astronomicon.co, OFL-1.1). Two more call sites using the same raw-Unicode pattern were found and fixed this session (chart result screen's aspect list, and the aspect detail sheet). The mapping (Sun=Q, Moon=R, ... aspects: conjunction=!, sextile=%, square=#, trine=$, opposition=") is now consistent across all 4 usage sites: `chart_wheel.dart`, `electional_helpers.dart`/`electional_tab.dart`, `chart_result_screen.dart`, `aspect_detail_sheet.dart`.
- Git history is short and coarse (7 commits total) — commit messages reference "Session 8," "Session 9" in code comments that don't map 1:1 to commits, suggesting development happens in long working sessions that get committed in batches rather than incrementally. `.claude/` in this repo is full of scratch debug logs/screenshots (`flutter_run_*.log`, `screen*.png`, `wheel_*.png`) from past sessions — these appear gitignored (not in `git status`), safe to ignore or clean up but not investigated this session.

## 4. Test coverage

- **Backend** (`backend/tests/`, 1,255 lines): strong on electional logic (`test_electional.py`, 973 lines — pure-logic + real-ephemeris integration tests pinned to actual 2026 Mercury retrograde/eclipse dates) and interpretation content parsing (`test_interpretations.py`). Light on `test_user.py` (56 lines, basic save/load).
- **Not covered on the backend**: `chart.py` router directly, `temperament.py` service, `geocode.py`, `synthesis.py` (AI-dependent — reasonably left untested/unmocked).
- **Flutter** (`test/`, 1,382 lines): good coverage of Electional (helpers, results widget, synthesis template, tab flow — 4 of 6 test files) and the aspect detail sheet. Only a smoke test for the top-level app.
- **Not covered on Flutter**: `api_client.dart`, `storage_service.dart`, `app_flow.dart`, `auth_service.dart`, chart wheel rendering, temperament screen, settings screen, onboarding, birth data form.

## 5. Reflection — what's left to do or polish

Roughly in priority order, based on what would block real users vs. what's cosmetic:

**Blocking for any real launch:**
1. **Real Google Sign-In.** The mock auth means cross-device sync (`/user/chart`) is currently untestable end-to-end and unshippable. This also blocks Android release meaningfully — a debug-keystore-signed app with fake auth isn't submittable.
2. **Android release signing.** Trivial to fix (generate a real keystore, wire it into `build.gradle.kts`) but currently blocks Play Store submission entirely.
3. **User data store.** The JSON-file `user_store.py` is explicitly a placeholder. Fine for a handful of users on Railway's single instance; will not survive concurrent writes, restarts losing the file, or any real scale. Needs a real DB (even SQLite-on-a-volume would be a step up) before wider release.
4. **Pro paywall / purchase restore are both no-ops.** If Pro gating is meant to generate revenue, this is unimplemented, not "partially implemented" — no payment provider is integrated anywhere in the codebase.

**Worth doing before wider testing, not launch-blocking:**
5. **iOS.** Not started. If iOS is in scope, this is a from-scratch platform setup, not a fix.
6. **Commit the two pending glyph fixes** described in §3 — small, done, just needs a commit.
7. **Fill the biggest test gaps**: `chart.py` (the natal chart endpoint — arguably the app's single most-used code path — has no direct router test), and any Flutter service-layer tests (`api_client.dart` especially, since it silently hardcodes the prod URL with no dev/staging override visible from what was surveyed — worth double-checking there's a way to point it at a local backend for development).
8. **`.claude/` scratch files.** Dozens of debug logs and screenshots from past sessions accumulated in `.claude/` (gitignored, so not a repo-hygiene issue, just local clutter). Not urgent, but worth a cleanup pass if it gets confusing to navigate.

**Genuinely minor / cosmetic:**
9. Windows desktop target exists but is almost certainly not an intentional ship surface — worth confirming with the user rather than assuming, since removing it is easy but assuming wrong is annoying.
10. No `vercel.json` committed despite deploying to Vercel — currently relying on Vercel's zero-config detection or manual dashboard settings. Not broken, but means the web deployment config lives outside the repo, which is a bit fragile (a dashboard misconfiguration wouldn't show up in code review).

**What's notably *not* a problem**: the astrology logic itself (electional engine, temperament calculation, interpretation content) is deep, well-tested, and well-documented — this is not a shallow MVP on the domain-logic side. The gaps are almost entirely in "productionization" (auth, payments, data persistence, release signing) rather than in the core feature set. Someone picking this up should not assume the astrology needs rework; it doesn't.
