# MADINI V1.3 — Marekebisho ya mapungufu 16

**Hali ya uthibitisho (soma kwanza):** marekebisho haya yameandikwa na kukaguliwa kwa kusoma msimbo tu.
`flutter pub get`, `flutter analyze`, `flutter test`, build ya APK na majaribio ya kifaa HAVIJAENDESHWA
(mazingira ya kazi hayakuwa na Flutter/Dart/Android SDK wala mtandao). Vilivyothibitishwa kwa zana nyingine:
(a) kwamba `values` kama jina la safu linashindwa kwenye SQLite (`near "values": syntax error`),
(b) namba zote za tests mpya zilikokotolewa upya kwa Python. Endesha `flutter analyze && flutter test`
kwanza; makosa ya compile yanayobaki yanawezekana.

## Yaliyorekebishwa kwenye msimbo

| # | Tatizo | Marekebisho |
|---|--------|-------------|
| 1 | Safu `values` (neno la SQL) | Safu mpya `values_json`; `GoldAssessment.toDbMap()`; `fromMap` inakubali `values` ya legacy/backup |
| 2 | `Decimal /` hurudisha `Rational` | Mgawanyo umeondolewa: kuzidisha kwa `0.001`/`0.01`; `toStringAsFixed(12)` badala ya `toString()` (hakuna e-notation) |
| 4 | Release ilisainiwa kwa debug key | `build.gradle` inasoma `android/key.properties`; release inashindwa kwa makusudi bila hiyo (isipokuwa `MADINI_ALLOW_DEBUG_SIGNING=1` kwa jaribio la ndani) |
| 5 | Auto-backup ilirudisha DB bila ufunguo | `allowBackup=false`, `data_extraction_rules.xml`; `DbGate` inaonyesha maelezo + "Futa na uanze upya" (kwa uthibitisho) ufunguo ukipotea |
| 6 | `REPLACE` + `CASCADE` ilifuta samples/vyeti | UPDATE-kisha-INSERT; `deleteAssessment` inafuta pia faili za vyeti |
| 7 | Backup haikuwa kamili | Backup v2: assessments, assay samples, bei, vyeti (hadi MB 30 kwa jumla; vilivyozidi vinaripotiwa); restore inakubali v1 na v2, inakagua sha256 |
| 8 | Uhifadhi si atomic | `saveBundle`: muamala mmoja; faili la cheti linafutwa muamala ukishindwa; kitufe kimefungwa wakati wa kuhifadhi; `database` inafunguliwa mara moja tu (race ya skrini 3 imeondolewa) |
| 9 | Muda wa bei ulikuwa wa kuhifadhi | Tarehe ya bei inachaguliwa na mtumiaji (inahitajika); inaonya bei ikizidi siku 7; kuna USD/oz + TZS/USD → TZS/g; bei ya mfano 120 imeondolewa |
| 10 | Grade ya kwanza tu, CV haizuii | Msingi wa grade (wastani/msingi/chini); hali 3 (conservative/expected/optimistic); CV ≥ 20% inahitaji kukiri kabla ya kuhifadhi |
| 11 | Kodi/rekodi hazimo | Royalty, inspection, makato mengine (% ya mapato), kitufe cha mpango wa BoT; sehemu za muuzaji, leseni/ID, lot ID, eneo, MTF 23/control number |
| 13 | Hakuna PIN | PIN ya tarakimu 6 (PBKDF2, lockout inayoongezeka, kufunga baada ya sekunde 45 nyuma) — inalinda skrini, haibadilishi encryption |
| 14 | History haina undani | Skrini ya undani: PDF, shiriki cheti, futa, "nakili kama mpya"; Home/History/Search zinajisasisha; field screening haionyeshi tena bid "0.0"; PDF mpya (MultiPage, maandishi salama kwa Latin-1) |
| 15 | Lugha/fomu | Kiswahili ndio msingi; maandishi mapya yote bilingual; unyevu/recovery/payability kwa %; validators zenye mipaka; hakuna thamani za mfano; grades kwa `;` (koma ni desimali); namba zenye mpangilio wa maelfu |
| 16 | "Premium valuation intelligence" | Imebadilishwa na maelezo ya kweli |
| 3 | Tests | Tests zimeandikwa upya kwa namba halisi, royalty, scenarios, parsing, model, PDF-safe — **hazijaendeshwa** |

## Yasiyofanyika — na kinachohitajika

- **#12 Uthibitisho wa soko:** inahitaji wanunuzi/wachimbaji/maabara halisi, assay 30+ zenye duplicate, metallurgist,
  mwanasheria; si kazi ya msimbo. Mpango uko kwenye `MARKET_RESEARCH_SW.md`.
- **Compile/analyze/test/build/majaribio ya kifaa:** inahitaji Flutter + Android SDK + mtandao + simu halisi.
  Hasa: migration ya SQLite→SQLCipher, Keystore, restore, auto-backup, PIN lockout, PDF.
- **Release keystore:** siwezi kutengeneza siri zako. Fuata `android/key.properties.example`.
- **Biometric:** haijaongezwa (inahitaji `local_auth`, `FlutterFragmentActivity`, majaribio ya vifaa).
- **Kuhariri rekodi:** nimeweka "nakili kama mpya" + futa (rekodi za fedha zisibadilishwe kimya); edit kamili haipo.
- **Viwango vya royalty/inspection/kodi:** ni thamani za awali zinazohaririwa; uhalali kwa kila mazingira ya mauzo
  unahitaji Tume ya Madini/mshauri wa kodi.
- **Play Store:** 16 KB page size ya SQLCipher, sera ya faragha, sheria ya ulinzi wa data binafsi, `LICENSE.md`
  (mmiliki halisi), `pubspec.lock` — vinahitaji `pub get` na uthibitisho wako.
- **Mapungufu madogo yanayojulikana:** audit events hazimo kwenye backup; vyeti vinavyozidi MB 30 jumla vinaachwa nje
  ya backup (unaonyeshwa idadi); PDF haina fonti ya Unicode (maandishi yanasafishwa kuwa Latin-1).
