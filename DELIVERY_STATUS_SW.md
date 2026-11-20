# MADINI — Delivery status na historia ya marekebisho

## Mabadiliko yaliyowekwa kwenye source

- Valuation engine imeandikwa upya ili intermediate calculations za mass, gold na fedha zibaki `Decimal` hadi matokeo ya mwisho.
- Valuation engine sasa inakataa `mode != laboratory`, sample/title tupu, grade hasi, bei sifuri/hasi, namba zisizo finite na fractions zisizokubalika.
- SQLCipher local database imeongezwa; database key inazalishwa kwa random na kuhifadhiwa kwa `flutter_secure_storage`.
- Njia ya one-time migration kutoka SQLite v2 plaintext imeongezwa: soma legacy rows, hamisha kwa encrypted DB, hakiki idadi ya rekodi, kisha futa nakala ya plaintext. Ikishindwa, jaribu kurudisha faili la awali.
- Tables za assay samples, certificate metadata, gold-price records na audit events zimeongezwa.
- Multiple assay grade comparison imeongezwa kwenye fomu; mfumo huhesabu mean, sample standard deviation, CV na tahadhari. Hakuna grade ya loti inayochaguliwa moja kwa moja kutokana na wastani huo.
- Certificate PDF/JPG/PNG inawekwa encrypted kwa AES-256-GCM kwenye app-private storage; metadata inahifadhiwa kwenye DB iliyosimbwa.
- Backup/restore ya assessment records imeongezwa kwa PBKDF2-HMAC-SHA256 na AES-256-GCM.
- Chanzo na muda wa bei vinaandikwa kwenye assessment, PDF na price history.
- PDF inaonyesha assay comparison, laboratory/certificate metadata na chanzo/muda wa bei.
- Settings UI imeongezwa kwa encrypted backup na restore.
- Backend na deployment configuration zimeondolewa kwa ombi la kubaki na offline mobile correction candidate.
- `LICENSE.md` imebadilishwa kutoka maandishi yasiyo leseni kwenda taarifa ya all-rights-reserved; umiliki na masharti ya mwisho ya kisheria bado yahakikiwe na mmiliki.

## Vipimo vilivyotekelezwa katika mazingira haya

- ZIP imefunguliwa na source files zimekaguliwa.
- Marekebisho ya source yameandikwa.
- Python/backend checks hazitumiki tena kwa sababu backend imeondolewa kwenye offline-only ZIP.
- `flutter analyze`, `flutter test`, `flutter pub get`, Android build na device tests HAZIJAENDESHWA: Flutter/Dart/Android SDK hazipo kwenye mazingira ya ujenzi huu.

## Mambo ambayo hayadaiwi kuwa yamekamilika

- OCR ya vyeti haipo.
- Backup haijumuishi certificate attachment files wala gold price history; inahifadhi assessment records pekee.
- Certificate authenticity haithibitishwi; jina la maabara na certificate number ni taarifa za mtumiaji.
- SQLCipher/Keystore integration inahitaji independent security review na Android device matrix.
- Database migration/restore inahitaji tests kwenye nakala ya database ya toleo la awali kabla ya ku-update simu za watumiaji.
- CV/outlier thresholds ni heuristic ya awali, si QA/QC protocol iliyoidhinishwa.
- Hakuna live price feed wala uthibitishaji wa bei rasmi.
- Formula, sampling plan, recovery/payability assumptions na commercial terms zinahitaji review ya metallurgist, assay laboratory na mtaalamu wa biashara/kisheria.
- Backend, subscriptions na malipo hayapo kwenye offline-only package.

## Hitimisho

Hii ni correction candidate yenye ulinzi na workflows zaidi kuliko V1.1. Si sahihi kuitangaza kuwa 95–98% imehakikishwa au kuwa tayari kwa soko bila Flutter build/tests, security review na pilot ya kitaalamu. Usitumie kwa ununuzi wa thamani kubwa kabla ya gates hizo kupita.


## V1.3
Angalia `CHANGES_V1_3_SW.md`. Marekebisho yameandikwa bila Flutter SDK; `flutter analyze/test/build` na majaribio ya kifaa bado hayajaendeshwa.


## V1.4
Marekebisho 9 ya ukaguzi (angalia `CHANGES_V1_4_SW.md`). Bado hakuna compile/test/jaribio la kifaa; fuata `RELEASE_CHECKLIST_SW.md`.


## V1.8
Angalia `CHANGES_V1_8_SW.md`. Bado hakuna compile/test/jaribio la kifaa; fuata `RELEASE_CHECKLIST_SW.md`.


## V1.9
Angalia `CHANGES_V1_9_SW.md` na `PRODUCTION_READINESS_SW.md`. Source hardening imeongezwa lakini hakuna Flutter analyze/test/build, signing au kifaa halisi kilichothibitishwa. Hii si release-ready APK/AAB.
