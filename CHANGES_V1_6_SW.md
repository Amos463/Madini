# MADINI V1.6 — Final Candidate (injini ya recovery + marekebisho ya release)

> **Hakuna compile, analyze, test wala build iliyoendeshwa.** Mazingira ya kazi hayana Flutter/Dart/Android SDK wala mtandao.
> Hesabu za tests zilihakikiwa kwa Python Decimal; muundo (imports, mabano) ulikaguliwa kwa script. Endesha CI kwanza.

## A. Injini ya Recovery & Valuation
- Injini moja, Decimal: moisture, dry mass, contained, recovery, fine gold (product × purity mara moja), payability, mapato, makato, gharama (pamoja na kemikali), net, bid, faida.
- Aina za ore (oxide, transition, sulfide, refractory, free-milling, alluvial, other) + sulfide % (taarifa tu).
- Sulfide pekee haibadilishi recovery; ore ya sulfide haithaminiwi bila ushahidi; ushahidi unahitaji rejea; dhana tu = INDICATIVE.
- Makato ya kisheria: makadirio ya mtumiaji + alama ya uthibitisho + rejea.
- Matokeo halisi: purity, uzito wa bidhaa, bei/gharama halisi, tofauti dhidi ya makadirio.
- Scenarios zinatoka kwenye injini ile ile (`ValuationEngine.scenarios`); kurudia hesabu: `recheckStored`.

## C. Ripoti na historia
- `AssessmentSummary` ni chanzo kimoja: historia na PDF zinaonyesha uzito, moisture, grade, recovery, purity, gharama, ushahidi, makadirio vs halisi, tofauti.
- Historia inahifadhi kila ingizo linalohitajika kurudia hesabu; ukurasa wa undani unahakiki upya.

## D. Tests (`test/recovery_engine_test.dart`)
Formula za kila hatua, moisture, purity, sulfide/ushahidi, gharama na faida, data batili, makadirio vs halisi, scenarios,
kuhifadhi-kufungua (JSON ya database), rekodi za zamani, rekodi iliyobadilishwa, muhtasari, PDF.

## Release
- Web build imeondolewa kwenye CI (SQLCipher/secure storage ni za simu). `analyze --no-fatal-infos`.
- AGP 8.5.0, Kotlin 1.9.24, Gradle 8.7 (ilikuwa 8.1.0/1.8.22/8.3; hizo ni za zamani kwa Flutter ya sasa — thibitisha CI).
- CI inapakia `pubspec.lock` kama artifact: ipakue na uiweke kwenye repo.
- Backup/PIN/migration/FLAG_SECURE: kama V1.4 (hazikubadilishwa).

## Yanayobaki — hayawezi kufanywa bila mazingira/watu wako
1. `flutter pub get/analyze/test` na CI kuwa kijani (huenda kukawa na makosa ya compile; nipe log nitarekebisha).
2. `pubspec.lock` (inatengenezwa na `pub get`).
3. Majaribio ya kifaa: DB save/open/update/delete, backup/restore, migration, kurekodi matokeo halisi.
4. Keystore ya release, Play Console, sera ya faragha/masharti (mwanasheria), 16 KB page size ya SQLCipher.
5. Hatua ya 7: uthibitisho na maabara/uchakataji halisi (`docs/VALIDATION_PROTOCOL_SW.md`) na kuidhinishwa na metallurgist/mhasibu.
6. Ukaguzi huru wa usalama wa cryptography.
7. Rekodi za zamani za database haziongezewi ore/evidence kiotomatiki (zinasomwa kwa chaguo-msingi: ore "other", ushahidi "dhana").
