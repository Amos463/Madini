# MADINI V1.9 — Ukaguzi wa kina wa V1.8 na hali ya injini

## Uamuzi wa ukaguzi
V1.8 ilikuwa source candidate yenye Ore na Doré workflows, lakini haikuwa imecompile/test/build kwenye mazingira ya uandishi. V1.9 imefanyiwa source-hardening kwenye maeneo yaliyoainishwa hapa chini. **Haijathibitishwa kuwa release-ready** kwa sababu Flutter toolchain, Android build, device tests, independent security review na professional sign-off havijafanyika.

## Je, injini inaweza kufanya Ore, Doré au vyote?
**Vyote ndani ya app moja, lakini kwa tathmini tofauti.**
- Ore assessment: grade ya maabara (g/t), uzito (kg), moisture, recovery, payability, bei na gharama.
- Doré assessment: uzito (g), gold purity, purity method, payability, bei na gharama.
- Historia inaweza kuwa na aina zote mbili. Rekodi moja haiwezi kuwa Ore na Doré kwa wakati mmoja na formula hazichanganywi.
- Ore engine si metallurgical simulator. Recovery huingizwa na mtumiaji; ore type/sulfide% havitabiri recovery.
- Doré engine ni Au-only. Haijumuishi silver/Ag credits, impurity penalties au refinery-specific settlement schedule.

## Mapungufu yaliyorekebishwa katika V1.9

| Eneo | Kasoro iliyokutwa V1.8 | Marekebisho ya V1.9 |
|---|---|---|
| Recompute Ore | Missing scenario/field ingeweza kupita bila kuonekana | Scenarios zote na fields muhimu sasa lazima ziwepo na zilingane |
| Recompute Doré | Missing scenario/field ingeweza kupita bila kuonekana | Ukaguzi mkali wa scenario zote, numeric na exact fields |
| Ore scenarios | Grade range iliyopinduliwa haikukataliwa mapema | Range sasa lazima iwe finite, non-negative na ordered |
| Actual outcome history | Version mpya ilitegemea history length na ingeweza kurudia/kupunguza namba | Inatumia max version, inakataa duplicates na current version iliyo nyuma |
| Backup restore | Validation ya records/certificates haikuwa kamili | Unique IDs, JSON, sample references, grade, prices, audit fields, cert hash na 30 MB cap hukaguliwa kabla ya DB write |
| Backup size | File nzima haikuwa na cap ya awali kabla ya JSON decode | File nzima ina cap ya 120 MB kabla ya decode; output nayo inakaguliwa |
| Certificate recovery | Metadata iliyopo yenye file iliyopotea ingeweza kuzuia restore ya cheti | Restore inaweza kusasisha private path ya metadata ikiwa file haipo |
| Database integrity | Quick check pekee | Quick check + foreign key check baada ya open na migration |
| Scale resolution | Resolution isiyowezekana ikilinganishwa na mass ilikubaliwa | Resolution lazima iwe ndogo kuliko mass |
| Evidence claims | Fire assay/recovery evidence ingeonekana kama imethibitishwa na app | UI/report zinaeleza wazi kuwa nyaraka/rejea zimetajwa na mtumiaji, si authenticated |
| Search | Search ilikuwa kwenye assessment contents pekee | Search imepanuliwa kwa linked assay samples, certificate metadata na audit events |

## Mapungufu yanayobaki (hayajafichwa)

### Blockers kabla ya public launch
1. Hakuna `pubspec.lock`; lazima itengenezwe na `flutter pub get` na ihifadhiwe Git.
2. Hakuna `flutter analyze`, `flutter test`, APK/AAB build au signed release iliyotekelezwa hapa.
3. Hakuna test kwenye vifaa halisi: migration, SQLCipher, restore, PIN, PDF, certificates, low storage, app restart na Android version matrix.
4. Hakuna independent security audit ya Keystore/SQLCipher/AES-GCM/backup.
5. Formula, sampling, recovery, payability, statutory deductions na doré purchase terms zinahitaji sign-off ya metallurgist, assay lab, refinery/buyer na mhasibu.
6. Hakuna pilot dataset ya kuthibitisha usahihi; usitangaze accuracy percentage.
7. Privacy policy/terms ni rasimu na zinahitaji mapitio ya kisheria.

### Product limitations
1. Doré engine inathamini Au pekee; Ag/silver credits, penalties na settlement terms hazipo.
2. Ore recovery ni input ya mtumiaji; hakuna process model ya kutabiri recovery kutokana na ore chemistry.
3. Search sasa inajumuisha assessment content na linked samples/certificates/audit; standalone gold-price history na audit za assessments zilizofutwa hazionyeshwi.
4. Actual-outcome history ni append-only kwa application logic, si cryptographically tamper-proof. SHA-256 seal haijumuishi outcome history na si keyed signature.
5. Fire Assay/metallurgical reference ni user-declared; MADINI haihakiki authenticity ya cheti, maabara au data.
6. Hakuna live gold-price feed, backend, cloud sync, account licensing au payment processing kwenye package hii.

## Uamuzi wa matumizi
- Internal engineering test: inaweza kuanza baada ya kuweka source kwenye Codespaces/kompyuta yenye Flutter SDK na quality gates kupita.
- Controlled pilot: baada ya build, device/security/formula review na approval za wataalamu.
- Public commercial launch: **usiitangaze kuwa tayari** mpaka release blockers zote zifungwe.
