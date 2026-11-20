# MADINI V1.9 — Hali ya utayari wa uzinduzi

## Uamuzi
**HAIJAWA TAYARI KWA UZINDUZI WA SOKO**

Hii ni **Source Hardening Candidate**. V1.9 inarekebisha validation ya backup/restore, recompute checks, version sequencing ya matokeo halisi, database foreign-key integrity na maelezo ya mipaka ya Ore/Doré. Hata hivyo, Flutter/Dart/Android toolchain haikuwepo wakati wa kuandaa ZIP; hakuna compile, analyze, test, build, signing au device test iliyotekelezwa.

## Uwezo wa engine
- **Ore:** makadirio ya ununuzi kwa grade g/t, uzito, unyevu, recovery, payability, bei na gharama.
- **Doré:** makadirio ya ununuzi wa dhahabu iliyochakatwa kwa uzito, purity ya dhahabu, payability, bei na gharama.
- **Ore + Doré:** zote zipo ndani ya app na historia moja, lakini ni aina mbili tofauti za assessment. Hakuna hesabu moja inayochanganya ore na doré.
- **Ore limitation:** recovery ni input ya mtumiaji. Aina ya ore/sulfide haihesabu recovery yenyewe; sulfide inahitaji testwork au production-history reference.
- **Doré limitation:** Au-only. Silver/Ag credits, impurity penalties na refinery-specific settlement terms hazipo.
- **Evidence limitation:** Fire Assay/metallurgical references ni taarifa zilizowekwa na mtumiaji; programu hai-authenticate cheti, maabara au production records.

## Vitu vilivyoongezwa V1.9
1. Backup file size cap 120 MB; certificate payload cap 30 MB.
2. Restore validation ya IDs, JSON, sample foreign keys, grades, price records, audit fields na certificate SHA-256.
3. Strict recompute checks za scenarios zote na fields muhimu za Ore/Doré.
4. Validation ya ore grade range na dore scale resolution.
5. Actual-outcome version sequencing inayoheshimu maximum existing version na kukataa malformed/duplicate history versions.
6. Database `quick_check` na `foreign_key_check` baada ya open/migration.
7. Ujumbe wa UI/report unaoeleza kuwa evidence references hazijathibitishwa kwa kujitegemea.

## Release blockers
1. **Dependencies:** tengeneza `pubspec.lock` kwa `flutter pub get`, ikaguliwe na ihifadhiwe Git.
2. **CI:** `flutter analyze`, `flutter test`, Android debug/release build na 16 KB checks lazima zipite.
3. **Device matrix:** jaribu Android versions/devices zinazolengwa; fresh install, upgrade, app kill, low storage, backup/restore, wrong password, corrupted backup, certificates, PDF, PIN/lockout na database migration.
4. **Security:** independent review ya SQLCipher, Android Keystore, AES-GCM, key recovery, temp files, backup leakage na rooted-device scenarios.
5. **Ore metallurgy:** metallurgist/assay lab ithibitishe sampling protocol, moisture, grade, recovery, payability na process costs.
6. **Doré settlement:** buyer/refinery ithibitishe Au purity, sampling, payability, deductions, refining charges; ikiwa Ag credits zinahitajika, V1.9 haijaziunga mkono.
7. **Commercial/legal:** accountant/Mining Commission/legal review ya royalty, inspection fees, licences, taxes, Commodity Register, privacy policy na terms.
8. **Search scope:** search sasa inatafuta assessments pamoja na metadata ya assay samples, certificates na audit events zilizounganishwa; bado haionyeshi standalone gold-price history au audit za assessments zilizofutwa.
9. **History tamper evidence:** actual-outcome history ni append-only kwa application logic tu; SHA-256 seal haijumuishi history hiyo na si keyed signature. Kwa hiyo si tamper-proof dhidi ya mwenye uwezo wa kuhariri database.
10. **Pilot:** linganisha assessments dhidi ya certificates/refinery receipts halisi; weka acceptance metrics kabla ya pilot.
11. **Store release:** package ID ownership, Play Console, target SDK, signing key backup, privacy/data safety, listing, support contact na signed AAB.

## Data model
MADINI inabaki local-first. Taarifa za tathmini, assay, certificates, prices, history na audit zinahifadhiwa kwenye kifaa na encrypted local database. Hakuna server backend au cloud sync kwenye package hii.

## Hitimisho
- Internal engineering test: baada ya Codespaces/CI setup na quality gates.
- Controlled pilot: baada ya build, device/security/formula reviews.
- Public market launch: **hairuhusiwi mpaka release blockers zote zifungwe**.
