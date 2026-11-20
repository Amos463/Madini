# MADINI V1.9 — Hardening ya mwisho ya source candidate

## Msingi
V1.9 imetokana na `MADINI_V1_8_DORE_HISTORY_CANDIDATE.zip`. Hakuna formula ya msingi ya Ore au Doré iliyobadilishwa; `formulaVersion` imeachwa `MADINI v1.8-recovery-dore-decimal` ili rekodi za zamani zisipate alama ya formula mpya bila sababu.

## Marekebisho ya source
1. **Backup/restore validation:** kikomo cha faili zima 120 MB; restore hukagua IDs zinazojirudia, JSON ya assessments, references za samples, grades, bei, audit event structure, IDs za vyeti, jumla ya vyeti 30 MB na SHA-256 ya kila cheti kabla ya kuandika data.
2. **Recompute integrity:** Ore na Doré sasa zinakataa scenarios zilizokosekana, fields muhimu zilizokosekana/si namba, na thamani zisizolingana. Ore assay-grade range inathibitishwa kuwa finite, non-negative na imepangwa.
3. **Actual outcome history:** namba za matoleo zinaendelea kutoka namba ya juu kabisa iliyopo, si `history.length`; historia yenye version isiyo sahihi au inayojirudia inakataliwa.
4. **Database integrity:** baada ya kufungua database, na baada ya migration, `quick_check` pamoja na `foreign_key_check` lazima zipite.
5. **Dore scale resolution:** resolution ya mizani lazima iwe ndogo kuliko uzito uliopimwa.
6. **Uwazi wa ushahidi:** UI na reports hazidai tena kuwa programu imethibitisha ripoti ya Fire Assay au metallurgical evidence. Programu inaonyesha kuwa rejea imetajwa na mtumiaji; uhalisi wake hauhakikiwi.
7. **Uwazi wa Doré:** fomu inaeleza kuwa hesabu ya sasa ni Au-only; Ag credits, impurity penalties na refinery settlement terms hazijajumuishwa.
8. **Local search:** utafutaji sasa unajumuisha assessment content pamoja na metadata za assay samples, certificates na audit events zilizounganishwa na assessment. Standalone price history na audit za assessments zilizofutwa bado hazionyeshwi.

## Injini: Ore, Doré au vyote?
- Ore: ndiyo, kwa tathmini ya ore kwa grade g/t, uzito, moisture, recovery na payability.
- Doré: ndiyo, kwa tathmini ya dhahabu iliyochakatwa kwa uzito, gold purity, payability na gharama.
- Vyote: ndiyo ndani ya programu moja na historia moja, lakini kila loti ina aina moja ya tathmini; hesabu hazichanganywi.
- Si metallurgical simulator: recovery inaingizwa na mtumiaji, haikokotolewi kutokana na ore type/sulfide.
- Si refinery settlement engine kamili: doré haijumuishi silver/Ag credits au settlement deductions maalumu.

## Vipimo vilivyoongezwa
- Tests za missing Ore/Doré scenarios.
- Tests za ore grade range iliyopinduliwa.
- Tests za scale resolution isiyowezekana.
- Test ya actual-outcome version sequencing yenye history gaps.

## Vipimo ambavyo HAVIJATEKELEZWA
Hakuna `flutter pub get`, `flutter analyze`, `flutter test`, Android build, AAB/APK signing, 16 KB runtime/device validation au security review iliyotekelezwa kwenye mazingira haya kwa sababu Flutter/Dart/Android SDK hazikupatikana. Hivyo V1.9 ni **source-hardening candidate**, si build iliyothibitishwa kuwa release-ready.

## Release blockers bado zipo
- Universal search bado haionyeshi standalone gold-price history au audit events za assessments zilizofutwa.
- `pubspec.lock` lazima itengenezwe na Flutter dependency solver na ihifadhiwe kwenye Git.
- CI lazima ipite bila makosa.
- Android device tests: install/upgrade, SQLCipher, backup/restore, migration, PIN, PDF, certificate files, low storage, app kill/restart.
- Independent security review ya Keystore/SQLCipher/AES/backup.
- Metallurgist, assay lab na accountant review ya formula, sampling, recovery, payability, makato na doré settlement.
- Pilot ya data halisi; usitangaze accuracy bila dataset na metric.
- Legal/privacy review na Play Console release requirements.

## Mapungufu yanayobaki
- Search haionyeshi standalone gold-price history au audit za assessments zilizofutwa.
- Actual-outcome history si cryptographically tamper-proof; SHA-256 seal haijumuishi history hiyo.
- Doré ni Au-only; Ag credits/penalties/refinery settlement terms hazipo.
- Hakuna Flutter build/tests/device validation, signing au independent security review.

## Hitimisho
V1.9 inaimarisha source na kuondoa baadhi ya njia za kupitisha data/hesabu zisizokamilika kimya kimya. Haifuti hitaji la CI, kifaa halisi, review ya kitaalamu na pilot. Usitumie build ambayo haijapita release gates kufanya maamuzi ya manunuzi ya thamani kubwa.
