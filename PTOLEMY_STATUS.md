# Ptolemy — Current State & Reflection

2026-07-11. Repo: `C:\ptolemy` (GitHub: `themamundiapps/ptolemy`). Written assuming familiarity with what Ptolemy is (traditional/Hellenistic astrology app — natal chart, temperament, electional astrology tools) — this is a state-of-the-project check-in, not an onboarding doc. Supersedes the 2026-07-09 version of this file; §3 and §4 are the parts that changed most.

## 1. Architecture recap

- **Frontend**: Flutter (`lib/`), targets **Web (Vercel)** and **Android** built, **Windows desktop** present in the project but **does not currently build in this dev environment** (`flutter run -d windows` fails: "Unable to find suitable Visual Studio toolchain" — the device shows up in `flutter devices` but the toolchain isn't installed here; unclear if it works on whatever machine originally set it up), **no iOS** (`ios/` doesn't exist).
- **Backend**: FastAPI (`backend/app/main.py`), deployed to **Railway** at `https://ptolemy-production.up.railway.app` (hardcoded in `lib/services/api_client.dart` — still no dev/staging override; confirmed this session by needing to hand-inject an `ApiClient(baseUrl: ...)` override to test locally at all). 6 routers under `/api/v1`: chart, geocode, interpretations, temperament, electional, user.
- **Astronomical engine**: `pyswisseph`, Moshier analytical ephemeris (no `.se1` high-precision data files present — fine for this use case, but worth knowing if precision complaints ever come up).
- **Only external paid API**: Anthropic (`ANTHROPIC_API_KEY` in `backend/.env`) — used solely by `backend/app/services/synthesis.py` for one feature: AI-generated 3-4 sentence natal-placement synthesis (`claude-haiku-4-5-20251001`). Geocoding (OpenStreetMap Nominatim) and timezone resolution are free/keyless.
- **Persistence**: no real database. `backend/app/services/user_store.py` is a JSON-file-backed store (`backend/data/user_charts.json`) mapping Google account id → last-saved birth data — explicitly documented in-code as a deliberate scope-limiting choice, not an oversight. Unchanged this session.
- **Auth**: Google Sign-In is currently **mocked** (`lib/services/auth_service.dart` — `MockGoogleAccount`, fixed fake account after a simulated delay). No real OAuth client ID configured yet. Unchanged this session.
- **CORS**: production `main.py` allowlists `ptolemy.vercel.app` + `*.vercel.app` (regex) + a couple of localhost web-dev ports. It does **not** allow arbitrary `http://127.0.0.1:<port>` origins, so pointing a local Flutter *web* build at a local backend for testing requires launching uvicorn with `ALLOWED_ORIGIN_REGEX=".*"` (or similar) — native targets (Android/Windows) aren't affected, since they're not subject to browser CORS at all. Worth knowing if anyone tries to develop against a local backend again.

## 2. Feature inventory

| Feature | State |
|---|---|
| Natal chart calculation + display | Done — chart wheel (custom-painted, Astronomicon font glyphs), planet positions, dignities, Lots, aspects, all tappable for detail sheets |
| **House Lords** | **New this session** — backend computes each whole-sign house's ruler, where it lands, and its dignity there (144 pre-written interpretation entries, `ptolemy-house-lords.md`); Chart tab gained a collapsible "House Lords" section with a detail sheet per entry |
| Temperament calculation + display | Done — quality bars, per-factor breakdown, citations, "How this was calculated" (now sits at the bottom of the tab, moved there this session) |
| **Temperament expanded content** | **New this session** — "Health Tendencies" (free, always visible) and "Traditional Recommendations" (Pro-gated, same lock/bottom-sheet pattern as Electional themes) for all 10 pure + mixed temperaments, `ptolemy-temperament-expanded.md` |
| Electional scan (checklist engine) | Done — this is the most sophisticated piece of the codebase, heavily tested (`test_electional.py` is 973 lines) |
| Electional synthesis paragraphs | Done, but **template-based, not AI** — `lib/screens/electional_synthesis.dart` rotates hand-written sentence banks (3 phrasing variants). Distinct from the natal AI-synthesis feature. |
| Natal AI synthesis | Done — real Anthropic API call, requires `ANTHROPIC_API_KEY` |
| City search / geocoding | Done (Nominatim) |
| Timezone resolution | Done — historically-accurate DST handling via `timezonefinder` + `pytz` |
| Onboarding carousel | Done — 3-page, shown once |
| Google Sign-In | **Mocked**, not real |
| Cross-device chart sync (signed-in users) | Backend endpoint exists (`/user/chart`), wired up, but sits on mock auth + JSON-file store — not production-real |
| Pro / paywall (Business & Career, Health & Body, Spiritual & Learning, Home & Family themes, **now also Temperament's Traditional Recommendations**) | **UI-only stub** — "Unlock with Pro" button exists, does nothing. The lock-sheet pattern is now duplicated in 3 places (`electional_tab.dart`, `planet_detail_sheet.dart`, `temperament_screen.dart`) with no shared widget — that's consistent with how the codebase already did it before this session, not a new inconsistency introduced here. |
| Purchase restore | **UI-only stub** — button exists with empty `onPressed` |
| Android release build | Configured but **signs with the debug keystore** — not Play-Store-submittable as-is |
| iOS | Not started — no `ios/` directory |
| Astronomicon font glyph migration | Done (completed 2026-07-09) |

## 3. Current repo state (as of this report)

- HEAD: `4718b46` ("Move 'How this was calculated' to the bottom of the Temperament tab"), branch `master`, up to date with `origin/master`. **Working tree is clean — nothing uncommitted.**
- Three commits landed this session, in order:
  1. `730c194` — House Lords feature (backend calculation + content parser + endpoint, Chart tab UI, backend tests).
  2. `0d2e9ce` — Expanded Temperament screen (backend content parser + endpoint, Temperament tab UI, backend tests).
  3. `4718b46` — Small follow-up UI reorder: moved "How this was calculated" below the two new sections instead of above them.
- New backend content files: `backend/content/ptolemy-house-lords.md`, `backend/content/ptolemy-temperament-expanded.md`. Note both also have a copy at the repo root (`C:\ptolemy\ptolemy-temperament-expanded.md`, `ptolemy-temperament-algorithm.md`) — those root copies are draft/reference docs, not what the backend actually reads at runtime; the `backend/content/` copy is the one that matters for deploys (Railway's build root is `backend/`).
- New backend endpoints: `POST /api/v1/chart/house-lords`, `GET /api/v1/interpretations/house-lord`, `GET /api/v1/temperament/expanded`.
- Git history is now 11 commits total, still coarse/batched rather than incremental — consistent with the pattern noted in the previous version of this file.

## 4. Test coverage

- **Backend** (`backend/tests/`): **144 tests, all passing** (was ~130 before this session — House Lords and Temperament-expanded each added their own test file, both covering parsing correctness, endpoint behavior, and edge cases like missing citations / unknown lookups). Still light on `test_user.py`. `chart.py`'s core `/positions` endpoint and `temperament.py`'s base `/temperament` endpoint (as opposed to the new `/expanded` one) still have no *direct* router test, only indirect coverage via other tests that call them for cross-checks.
- **Flutter** (`test/`, 6 files, unchanged count): still only Electional + aspect detail sheet + a smoke test, as before. **A real attempt was made this session** to add `test/temperament_screen_test.dart` (spinning up a local `dart:io HttpServer` to test the new UI against two different temperament results, one pure one mixed) — it had to be abandoned and deleted. Root cause, confirmed via a minimal repro: **`flutter test` forces every real HTTP request to return status 400** the moment any `HttpClient` is created in a test suite using `TestWidgetsFlutterBinding` — this is deliberate Flutter framework behavior, not a bug, and it's *why* the existing tests in this repo (e.g. `aspect_detail_sheet_test.dart`) only ever exercise the fallback/failure path, never a real successful fetch. Genuine success-path widget testing would require refactoring `ApiClient` to accept an injectable `http.Client` (so `package:http/testing.dart`'s `MockClient` could stand in) — that's a real, scoped, worthwhile improvement if someone wants to pick it up, previously flagged in vaguer form in the 07-09 version of this file's item 7. Verification for the new Temperament UI ended up being: `flutter analyze` clean, careful code review against existing patterns, and live backend verification (curl + FastAPI TestClient) of both a pure and a mixed temperament's exact JSON shape.
- `TemperamentTab` picked up an optional `apiClient` constructor param this session (defaults to the production client, same DI pattern `aspect_detail_sheet.dart` already used) — makes it *possible* to test without a live backend, even though the HTTP-mocking piece above is still missing.

## 5. Reflection — what's left to do or polish

Roughly in priority order, based on what would block real users vs. what's cosmetic. Items 1-4 and 9-10 are unchanged from the 07-09 report (still true, still not touched this session):

**Blocking for any real launch:**
1. **Real Google Sign-In.** Mock auth blocks cross-device sync end-to-end testing and meaningful Android release.
2. **Android release signing.** Trivial fix, currently blocks Play Store submission.
3. **User data store.** JSON-file store is an explicit placeholder; needs a real DB before wider release.
4. **Pro paywall / purchase restore are both no-ops.** No payment provider integrated anywhere — now true for 5 gated surfaces instead of 4 (Temperament's Traditional Recommendations joined this session), same underlying gap.

**Worth doing before wider testing, not launch-blocking:**
5. **iOS.** Not started.
6. ~~Commit the two pending glyph fixes~~ — done as of 07-09, no longer applicable.
7. **Fill remaining test gaps**: `chart.py`'s `/positions` and `temperament.py`'s base `/temperament` endpoint still lack direct router tests. Flutter service-layer/UI success-path testing is still uncovered — see §4 for the newly-diagnosed *why* (Flutter test's forced-400 behavior) and the concrete fix (inject `http.Client` into `ApiClient`).
8. **`.claude/` scratch files.** Still accumulated, still gitignored, still just local clutter — not investigated this session either.

**Genuinely minor / cosmetic:**
9. Windows desktop target — now confirmed it doesn't even build in this dev environment (missing VS toolchain), which strengthens the case that it's not an actively-maintained ship surface. Still worth confirming with the user before removing it, rather than assuming.
10. No `vercel.json` committed despite deploying to Vercel — unchanged, still fragile in the same way described previously.
11. **New this session**: no `dev`/`staging` backend URL override exists anywhere in the Flutter app — `defaultBaseUrl()` is a hardcoded single `https://` string. Confirmed as a real gap while trying to test locally (had to pass a local `ApiClient` by hand into `TemperamentTab` and separately relax backend CORS to even attempt it). If local development against the app becomes a regular need, a `--dart-define`-based override would be a small, well-contained fix.

**What's notably *not* a problem**: the astrology logic itself (electional engine, temperament calculation, house lords, interpretation content) is deep, well-tested, and well-documented — this is not a shallow MVP on the domain-logic side, and that held true through two more non-trivial features added this session. The gaps are almost entirely in "productionization" (auth, payments, data persistence, release signing, dev-environment ergonomics) rather than in the core feature set.
