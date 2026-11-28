# Nitro Wheelz — ONE Android QA app (issues #67, #68)

## Rules (agents and CI)

| Fact | Value |
|---|---|
| Package (application ID) | `com.karllondor.nitrowheelz.review.pr45` (the QA app the owner already has since v0.1.50) |
| Label on the phone | **Nitro Wheelz QA** (older builds of the same app showed "Nitro Wheelz Review 45") |
| Signing certificate SHA-256 | `CD:1A:E2:A4:A2:54:19:1A:E4:23:BF:23:A6:BC:C6:0F:A8:2D:36:9D:13:96:51:4B:B1:75:4E:0C:66:9B:7B:E2` (secret `NITRO_DEBUG_KEYSTORE_B64`, CN=Nitro Wheelz Debug) |
| versionCode | strictly above `QA_LAST_VERSION_CODE` in `tools/qa_channel.env` (now 52 → candidate 53) |
| Source branch | `integration/stable-mobile-qa` only |

CI (`.github/workflows/android-debug.yml`, lane `integration/stable-mobile-qa`) **fails** when the signing secret is missing,
the versionCode is not above the last delivery, or the built APK has another package or certificate
(`tools/apk_identity.py` reads them from the APK itself). Feature branches must not create new owner-facing package IDs;
experiments stay behind DEVELOPER switches inside this app.

Package inventory known from CI (do not delete anything on the owner's phone before its data is identified):

| Package | What it is | Status |
|---|---|---|
| `com.karllondor.nitrowheelz.review.pr45` | QA app v0.1.50 → v0.1.51 → **v0.1.53** | **keep, update in place** |
| `com.karllondor.nitrowheelz` | old standard build (main v0.1.6 era) | keep until the owner decides |
| `com.karllondor.nitrowheelz.dev` | unified DEV preview v0.1.42–v0.1.45 | superseded; keep until its tracks are checked |
| `com.karllondor.nitrowheelz.forestlab` | Forest Lab pilot v0.1.50 (#64) | superseded by DEVELOPER > FOREST LAB |
| `com.karllondor.nitrowheelz.review.pr<N>` (other N), `.workshop`, `.water19` | single-PR reviews | superseded |

Saves live per package (`user://` is app-private): a track saved in one of the old apps is NOT visible in the QA app.
Moving such tracks needs an explicit export / import step (not done here, never automatic).

## Dla właściciela: KTÓRY APK INSTALOWAĆ

1. Pobierz **tylko** plik `Nitro-Wheelz-QA_v0.1.53_code53_….apk` (artefakt CI z gałęzi `integration/stable-mobile-qa`).
2. Zainstaluj go **na istniejącą** aplikację „Nitro Wheelz Review 45” — telefon zapyta o *aktualizację*, nie o nową aplikację.
   Po instalacji ikona nazywa się **Nitro Wheelz QA**. Trasy, rekordy, gwiazdki i lakiery zostają.
3. Jeśli telefon pokaże „aplikacja niezgodna / konflikt pakietu” — **nie odinstalowuj niczego**, zrób zrzut ekranu i napisz w #68.
4. Starych aplikacji (Nitro Wheelz, DEV, Forest Lab, Review N) **nie usuwaj**, dopóki nie sprawdzimy, czy mają trasy, których
   potrzebujesz. Możesz je po prostu nie otwierać.
