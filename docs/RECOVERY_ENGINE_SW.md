# Injini ya Recovery & Valuation (ore: V1.6, doré: V1.8)

Injini MOJA: `lib/services/valuation_engine.dart`. Fomu, historia, ripoti ya PDF na ukaguzi wa upya wote wanaitumia.
Ripoti na historia hazikokotoi chochote: zinasoma namba zilizohifadhiwa kupitia `lib/domain/assessment_summary.dart`.

## Formula (Decimal; double ni kwa pato tu)

| Kipimo | Formula |
|---|---|
| Uzito mkavu | wet × (1 − moisture) |
| Dhahabu iliyomo | dry tonnes × grade (g/t) |
| Dhahabu safi inayokadiriwa | contained × recovery (tayari ni dhahabu safi) |
| Dhahabu safi halisi | product mass × purity (MARA MOJA tu) |
| Dhahabu inayolipiwa | fine gold × payability |
| Mapato | payable × bei (TZS/g) |
| Makato | mapato × (royalty + inspection + mengine)% |
| Gharama | kemikali + usindikaji + usafirishaji + nyinginezo |
| Net | mapato − makato − gharama |
| Bei ya juu ya kununua | net − faida lengwa |
| Faida | net − bei ya ununuzi |

## Kanuni za ushahidi
- Aina ya ore na asilimia ya sulfide HAZIBADILISHI recovery. Zinaamua tu ushahidi unaohitajika.
- Ore ya `sulfide`/`refractory_sulfide` na recovery ya kudhani: injini inakataa (ArgumentError).
- Ushahidi (jaribio la metallurgical / historia ya uzalishaji) unahitaji rejea.
- Ore nyingine yenye dhana tu: inaruhusiwa, lakini matokeo yamewekwa `valuationGrade = indicative`, na mtumiaji lazima akiri.
- Makato ya kisheria ni makadirio ya mtumiaji; kuna alama `statutoryVerified` + rejea. Programu haithibitishi sheria.

## Makadirio dhidi ya halisi
Kwenye ukurasa wa undani: "Rekodi matokeo halisi" (uzito wa bidhaa, purity, rejea, hiari bei/gharama halisi).
Injini inakokotoa fine gold halisi, recovery halisi, tofauti (g, %, pointi), mapato na faida halisi.
Inaonya kama recovery halisi > 100%, purity < 50%, au tofauti ya recovery > pointi 10.

## Kurudia hesabu
Kila rekodi ina `values` kamili (pamoja na `ValuationInput.toMap()`, assay zote, mshtuko wa scenarios).
Ukurasa wa undani unaendesha `recheckStored`: ukilinganisha na matokeo yaliyohifadhiwa, tofauti inaonyesha
rekodi iliyobadilishwa nje ya app au formula iliyobadilika.

## Doré / dhahabu (V1.8)
Kwa ununuzi wa dhahabu iliyochakatwa. Fomu: Home > "Ununuzi wa doré / dhahabu". Hesabu ziko `ValuationEngine.calculateDore`.

| Kipimo | Formula |
|---|---|
| Uzito halisi | uzito wa doré × (1 − punguzo la unyevu/zebaki/slag) |
| Purity iliyotumika | purity iliyopimwa − tahadhari (pointi) / 100 |
| Dhahabu safi | uzito halisi × purity iliyotumika (mara moja tu) |
| Inayolipiwa | dhahabu safi × payability |
| Mapato, makato, gharama, net, bid, faida | kama ore (gharama = refining/assay + usafirishaji + nyinginezo) |

Njia za kupima purity na uaminifu wake:
- **Fire assay** (maabara): inahitaji rejea ya ripoti; mfumo huichukulia kama njia ya juu ya kipimo, lakini rejea/uhalisi wa ripoti na maabara havihakikishwi na app.
- **XRF**: hupima uso tu; inaonywa; bei ni ya kukadiria; tahadhari ya awali pointi 2.
- **Macho/uzoefu**: haijapimwa; bei ni ya kukadiria; tahadhari ya awali pointi 5.
Viwango vya tahadhari ni mapendekezo ya awali yanayohaririwa na yanaonekana kwenye ripoti; si thamani zilizothibitishwa na mtaalamu.

Matokeo halisi ya refinery (uzito, purity, bei/gharama halisi) yanalinganishwa na makadirio: fine gold, purity (pointi), mapato na faida.
Karat inabadilishwa kuwa purity (karat/24) kwa double kisha Decimal ya tarakimu 12.

## Matoleo ya matokeo halisi (V1.8)
Matokeo halisi yakirekebishwa: sababu inahitajika; toleo la zamani (pamoja na ulinganisho wake) linahamia `actualOutcomeHistory`
(matoleo ya zamani huhifadhiwa na application logic); audit inarekodi toleo na sababu. Si tamper-proof. Muhuri wa uadilifu haujumuishi matokeo halisi wala historia yake
(ndiyo maana yanaweza kuongezwa baada ya kuhifadhi), kwa hiyo historia ndiyo kumbukumbu ya mabadiliko.


## Uwezo na mipaka ya bidhaa
- Ore na doré zinaweza kuhifadhiwa kwenye programu moja na historia moja, lakini ni tathmini mbili tofauti; hazichanganywi kuwa formula moja ya loti.
- Ore engine haitabiri recovery kutoka aina ya ore au sulfide%; hutumia recovery iliyoingizwa na mtumiaji. Sulfide inahitaji testwork au production-history reference iliyotajwa na mtumiaji.
- Doré engine inathamini dhahabu (Au) pekee. Silver (Ag), impurity penalties na refinery settlement terms hazijajumuishwa.
- Fire assay / metallurgical evidence status inaonyesha njia/rejea iliyotajwa na mtumiaji, si uthibitisho wa uhalisi wa cheti, maabara au data.

## Uadilifu wa actual-outcome history
Historia huhifadhi matoleo ya awali kupitia application logic na sababu za marekebisho. SHA-256 seal ya assessment haijumuishi `actualOutcome`/`actualOutcomeHistory`, na si keyed signature. Kwa hiyo history si tamper-proof dhidi ya mtu mwenye uwezo wa kuhariri database ya kifaa; ihifadhi backup za mara kwa mara na audit receipts za nje kwa biashara zenye hatari kubwa.
