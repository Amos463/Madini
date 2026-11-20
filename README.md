> **V1.9:** hardening ya backup/restore, uthibitishaji mkali wa kurudia hesabu na matoleo ya matokeo halisi; imeendeleza ununuzi wa doré/dhahabu (purity + njia ya kupima), matoleo ya matokeo halisi (historia isiyofutwa), kifuta cha vyeti salama zaidi na nyaraka zilizosasishwa. Angalia `CHANGES_V1_9_SW.md`, `AUDIT_REPORT_V1_9_SW.md` na `RELEASE_CHECKLIST_SW.md`. **Haijacompile wala kupimwa kwenye kifaa**: hatua ya kwanza ni CI (`flutter pub get && flutter analyze && flutter test`).

# MADINI — V1.9 Candidate (Offline)

> Hii bado ni candidate: build/test na ukaguzi wa kifaa lazima upite kabla ya pilot/soko. Hakuna madai ya kuwa tayari kwa public launch mpaka release gates zipite. Angalia `PRODUCTION_READINESS_SW.md` na `RELEASE_CHECKLIST_SW.md`.


MADINI ni programu ya Android ya kusaidia kurekodi ushahidi wa sampuli za madini ya dhahabu na kufanya makadirio ya kiuchumi ya ununuzi wa **ore** (assay grade, uzito, moisture, recovery, payability) na wa **doré/dhahabu** (uzito, purity na njia ya kuipima, payability), pamoja na gharama na bei ya dhahabu iliyoingizwa na mtumiaji. Ore na doré ni workflows tofauti zinazotumia injini moja ya huduma lakini formula tofauti; zinaweza kuhifadhiwa kwenye historia moja, si kuunganishwa kuwa loti moja.

**Hali ya toleo:** correction candidate ya majaribio ya ndani. Si kifaa cha kupima dhahabu, si maabara, si cheti cha assay, si bei rasmi ya Serikali, na si kibali cha kufanya biashara ya madini.

## Kwa nini bidhaa hii ina nafasi ya matumizi

Tanzania ina mfumo rasmi wa masoko na vituo vya ununuzi wa madini, na Tume ya Madini inaeleza kuwa maabara yake inahudumia wachimbaji, wafanyabiashara, wanunuzi na wauzaji nje. Huduma zake zinajumuisha sampling, sample preparation, moisture determination na gold analysis kwa fire assay. Hivyo programu hii inalenga pengo tofauti: kuhifadhi taarifa za sampuli na assumptions za biashara, kulinganisha assay nyingi, kuweka chanzo/muda wa bei na kuonyesha hesabu ya makadirio kabla ya uamuzi wa ununuzi.

MADINI haichukui nafasi ya sampling ya kitaalamu, maabara yenye mfumo wa ISO/IEC 17025, ukaguzi wa Tume ya Madini, Commodity Register au nyaraka za kisheria za biashara.

## Kilichojumuishwa katika correction candidate hii

- Android-first Flutter app yenye UI ya Kiswahili/Kiingereza na light/dark themes.
- Local SQLCipher database encryption; random database key huhifadhiwa kwa `flutter_secure_storage`.
- Jaribio la kuhamisha database ya awali ya SQLite v2 kwenda SQLCipher bila kuifuta kabla ya uthibitisho wa rekodi zilizohamishwa.
- Database tables za assessments, assay samples, certificate attachment metadata, gold-price history na audit events.
- Certificate files (PDF/JPG/PNG) huhifadhiwa zikiwa AES-256-GCM encrypted ndani ya app-private storage.
- Encrypted backup ya rekodi za tathmini: PBKDF2-HMAC-SHA256 (310,000 iterations) + AES-256-GCM. Restore hukagua authentication, ukubwa, IDs zinazojirudia, marejeo ya foreign keys, grades, bei na SHA-256 ya kila cheti kabla ya kuandika rekodi.
- Multiple assay grade entry na descriptive comparison: mean, standard deviation, coefficient of variation na tahadhari za matokeo.
- Decimal arithmetic inaendelea katika hatua zote za hesabu za valuation; double inatumika tu kwenye boundary za UI/database.
- Field screening imezuiwa kuingia kwenye valuation engine; field observations hazitoi g/t wala maximum bid.
- Chanzo na muda wa bei ya dhahabu vinaandikwa kwenye assessment na price history. Bei bado inaingizwa na mtumiaji.
- PDF report inaonyesha assumptions, chanzo/muda wa bei na assay comparison.
- Audit events za kuunda/kubadilisha assessments na ku-import backup.
- Kurudia hesabu kunakagua scenario zote, fields zote muhimu, na kukataa rekodi zenye sehemu za hesabu zilizokosekana.
- Matoleo ya matokeo halisi yanafuata namba inayoongezeka hata kama historia ya zamani ina gaps; data ya historia yenye muundo usio sahihi hukataliwa.

## Kanuni za hesabu

- Uzito unaingizwa kwa kg; grade kwa g/t; bei kwa TZS/g.
- Dry kg = wet kg × (1 − moisture fraction).
- Contained gold (g) = dry tonnes × grade (g/t).
- Recovered gold = contained gold × recovery fraction.
- Payable gold = recovered gold × payability fraction.
- Revenue = payable gold × gold price per gram.
- Statutory deductions = revenue × (royalty + inspection + other statutory %) .
- Fixed target: maximum bid = revenue − statutory deductions − costs − fixed target profit.
- Percentage target: maximum bid = revenue − statutory deductions − costs − (revenue × target margin %).

Recovery na payability ni assumptions za mtumiaji, si ahadi ya plant. Rejea ya testwork/production history ni tamko la mtumiaji tu; MADINI haihakiki uhalisi wa ripoti, maabara au data za uzalishaji. Negative maximum bid inamaanisha hakuna bei chanya inayofikia gharama na target iliyowekwa. V1.3 ina sehemu za royalty, inspection fee na makato mengine kama asilimia ya mapato (HAKUNA thamani za awali: mtumiaji anaweka viwango rasmi vya sasa kutoka Tume ya Madini, 0 kama hakuna; makato yanapunguzwa kutoka bei ya juu, yaani mnunuzi anayabeba); refining charges, penalties na masharti ya mkataba bado ni ya mtumiaji kuongeza kwenye gharama baada ya ushauri wa kitaalamu.

## Doré: mipaka ya formula

Fomu ya doré inakokotoa thamani ya dhahabu (Au) kwa uzito halisi × purity. Haijumuishi silver (Ag) credits, penalties za impurities, treatment/refining settlement schedules au masharti maalumu ya refinery. Fire Assay reference ni taarifa iliyoingizwa na mtumiaji; app haithibitishi uhalisi wa cheti/maabara. Kwa hiyo hii si smelter/refinery settlement engine.

## Sampling na assay: tahadhari

CV na outlier warnings ni takwimu za kulinganisha matokeo yaliyoingizwa tu. Hazithibitishi kuwa sampuli zinawakilisha ore lot. Gold inaweza kuwa heterogeneously distributed; sampuli, preparation, duplicate/umpire assays, blanks na certified reference materials vinahitaji utaratibu wa QA/QC wa mtaalamu. Usitumie wastani wa sampuli kama grade ya loti bila kuidhinishwa na mtaalamu.

## Kuendesha na kupima

Mahitaji: Flutter SDK inayolingana na `environment.sdk` ya `pubspec.yaml`, Android SDK na Android 6.0+ (API 23+).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK inayotarajiwa: `build/app/outputs/flutter-apk/app-release.apk`.

**Muhimu:** SDK haikuwepo kwenye mazingira yaliyotumika kuandaa ZIP hii. Kwa hiyo `flutter pub get`, analyzer, tests na APK build hazijatekelezwa hapa. `pubspec.lock` imeondolewa kwa makusudi ili dependency solver itengeneze lockfile mpya kwa mazingira halisi ya build; hakikisha lockfile mpya inakaguliwa na kuhifadhiwa kabla ya release.

## Mipaka inayobaki kabla ya majaribio ya biashara

1. Hakuna OCR ya kusoma cheti; cheti kinaweza kuhifadhiwa encrypted na metadata inaingizwa kwa mkono. Uhalali wa cheti hauhakikishwi.
2. Dore engine inathamini Au pekee; Ag credits, impurity penalties na refinery settlement terms hazipo.
3. CV/outlier logic ni screening statistic tu; lazima ipitiwe na statistician/metallurgist na kuthibitishwa kwa datasets za assay.
4. Backup v2 inajumuisha assessments, assay samples, bei na vyeti (hadi MB 30 jumla); audit events zimejumuishwa. Ukubwa wa backup nzima una kikomo cha MB 120.
5. Hakuna independent audit ya security ya SQLCipher/Keystore, reverse engineering, rooted-device, backup leakage au Android version matrix.
6. Hakuna majaribio ya migration yaliyotekelezwa kwenye vifaa halisi; kabla ya ku-update app ya mtumiaji, fanya backup ya kifaa na jaribu migration kwenye nakala.
7. Hakuna live gold-price feed; mtumiaji lazima aandike source na timestamp sahihi.
8. Hakuna verification huru ya maabara, assay certificate, representativeness ya sampuli, recovery testwork au metallurgical balance. Rejea za nyaraka ni user-declared.
9. Mfumo haujathibitishwa kama unaendana na kila wajibu wa kisheria wa mineral dealer/broker, Commodity Register, tax, royalty, inspection na trading permits. Pata ushauri wa Tume ya Madini/wanasheria kabla ya matumizi ya kibiashara.
10. Backend, account licensing na payment processing hazijajumuishwa kwenye ZIP hii; programu hii inabaki offline-first/local-only.
11. Hakuna accessibility, usability au field-pilot sign-off iliyofanyika.
12. Search inatafuta assessments, values/results na metadata za assay samples, vyeti na audit events zilizounganishwa na assessment; bado haionyeshi standalone gold-price history au audit za assessments zilizofutwa.
13. Actual-outcome history inalindwa na application logic, si cryptographically tamper-proof; SHA-256 seal haijumuishi outcome history na si keyed signature.

## Release policy

Usitangaze “98% accuracy”, “98% secure” au “98% production ready” kutokana na source code pekee. Release inahitaji Flutter tests/analyze, Android device tests, migration/restore tests, security review, professional formula review, na pilot inayolinganishwa na certified assay results. Matokeo ya MADINI ni decision-support estimates, si msingi pekee wa kufanya manunuzi ya thamani kubwa.

## Vyanzo vya utafiti

- Mining Commission — Mineral Laboratory Services: https://www.tumemadini.go.tz/pages/mineral-laboratory-services/
- Mining Commission — Directorates and Mineral Audit/Trade mandate: https://www.tumemadini.go.tz/pages/departments/
- Mining Commission — Mineral royalties and inspection fees: https://www.tumemadini.go.tz/pages/mineral-royalties-and-inspection-fees-rates/
- OWASP MASVS storage controls: https://mas.owasp.org/MASVS/05-MASVS-STORAGE/
- OWASP Android cryptographic key storage: https://mas.owasp.org/MASTG/knowledge/android/MASVS-STORAGE/MASTG-KNOW-0047/
- SQLCipher Flutter package: https://pub.dev/packages/sqflite_sqlcipher
