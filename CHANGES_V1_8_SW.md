# MADINI V1.8 — Doré, matoleo ya matokeo halisi, kifuta salama, nyaraka

> **Hakuna compile, analyze, test wala build iliyoendeshwa.** Mazingira ya kazi hayana Flutter/Dart/Android SDK. Namba zote za tests mpya
> zilikokotolewa upya kwa Python Decimal kutoka kwa formula zilizoandikwa kwenye hati; muundo (mabano, imports) ulikaguliwa kwa script.
> Hatua ya kwanza ni CI. Makosa ya compile yanayobaki yanawezekana.

## 4. Ununuzi wa doré / dhahabu
- Injini: `calculateDore`, `doreScenarios`, `doreAdvisories`, `compareActualDore`, `recheckStoredDore`; `PurityConverter.karatToFraction`.
- Njia ya purity: fire assay (inahitaji rejea; "imethibitishwa"), XRF na macho ("KUKADIRIA TU"; tahadhari ya purity inapunguzwa na kuonekana kwenye ripoti).
- Uzito: punguzo la unyevu/zebaki/slag, onyo la usahihi wa mizani. Purity inatumika MARA MOJA (uzito halisi × purity).
- Fomu mpya `dore_screen.dart` (Home + kiungo kwenye fomu ya ore); historia, ripoti ya PDF, muhuri, kurudia hesabu, kunakili, na matokeo halisi ya refinery zinafanya kazi kwa doré.
- Viwango vya tahadhari (0/2/5) ni mapendekezo ya awali, SI yaliyothibitishwa na mtaalamu; yanahaririwa. Makato hayana thamani za awali (kama fomu ya ore).

## 5. Matokeo halisi hayaandikwi upya kimya
- `ActualOutcomeVersioning`: marekebisho yanahitaji sababu; toleo la zamani + ulinganisho wake vinahamia `actualOutcomeHistory` (append-only); toleo jipya lina namba.
- Audit inarekodi toleo, rejea, sababu na alama ya "inahitaji ukaguzi". Muhtasari/PDF vinaonyesha "Historia ya matoleo". Muhuri hauathiriwi.

## 6. Kifuta cha vyeti yatima
- Uamuzi uko kwenye `OrphanSweep.plan` (kazi safi, imejaribiwa): hulinganisha JINA la faili (si njia nzima), umri wa saa 24+, `.mcert` tu.
- Kinga: kama zaidi ya nusu ya mafaili (5+) yangefutwa, hakuna kinachofutwa.

## 11. Nyaraka
README, PRODUCTION_READINESS, BUILD_AND_RELEASE, RELEASE_CHECKLIST, FORMULA_VERSIONS, RECOVERY_ENGINE, VALIDATION_PROTOCOL, DELIVERY_STATUS, PACKAGE_MANIFEST na `pubspec.yaml` (1.8.0+8) zimesasishwa.

## Yanayobaki (hayajabadilika na hayawezi kufanywa bila wewe)
CI kijani; majaribio ya kifaa (DB, backup/restore, migration, PIN, kifuta); `pubspec.lock`; keystore/Play; sera ya faragha/masharti (mwanasheria);
uthibitisho halisi na maabara/refinery; mhasibu/Tume ya Madini kuthibitisha makato na viwango vya tahadhari ya purity; ukaguzi huru wa usalama.
Pia: matokeo halisi ya zamani yaliyohifadhiwa kabla ya V1.8 hayana namba ya toleo (yanachukuliwa kama toleo 1).
