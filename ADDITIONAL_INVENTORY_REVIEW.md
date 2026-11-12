# Additional inventory import review

Source: additional_store_inventory_corrected.xlsx

Imported and read back: 3 entries. Existing product prices, stock and records preserved. No schema changes.

| Added | Menu | Price NPR | Quantity | Room |
|---|---|---:|---:|---|
| Lotte Choco Pie - Box | Wholesale | 300 | 7 box | 7 Counter |
| Eclairs Pop - Packet | Retails | 300 | 2 pack | 7 Counter |
| Soan Papdi - Box | Wholesale | 200 | 6 box | 7 Counter |

Images are blank: workbook links are Google image searches, not verified product image files.

## Pending rows

Blank quantities have not been assumed to be zero. Pack/bundle variants have not been imported as independent duplicate stock. Confirm missing quantities, pack conversions and identities before importing these rows.

| Sheet | Excel row | S.N. | Product | Packaging | Price | Quantity / notes | Reason |
|---|---:|---|---|---|---:|---|---|
| 1 | 2 | 1 | Sumo Lacto | piece | 100 | 1 | Identity or pack size needs confirmation; Possible existing item: Sumo lacto |
| 1 | 3 | 2 | HUNK | piece | 100 | 24 | Identity or pack size needs confirmation; Possible existing item: HUNK |
| 1 | 6 | 5 | Vaseline | bundle | 500 | 1 | Confirm variant/pack size and shared-stock relationship |
| 1 | 7 | 6 | Bikaji Soan Papdi | piece | 120 | 100x12 | Confirm actual stock versus pack conversion |
| 1 | 8 | 7 | Snackers | packet | 240 | Not supplied | Stock quantity missing |
| 1 | 9 | 8 | Shalimar Coconut Oil | dozen | 240 | Not supplied | Stock quantity missing |
| 1 | 10 | 9 | ENO Fruit Salt | piece | 15 | Not supplied | Stock quantity missing |
| 1 | 11 | 10 | Rose Soap | piece | 53 | Not supplied | Stock quantity missing |
| 1 | 12 | 10 | Rose Soap | dozen | 450 | Not supplied | Stock quantity missing |
| 1 | 13 | 11 | Colgate 200g | piece | 200 | Not supplied | Stock quantity missing |
| 1 | 14 | 11 | Colgate 100g | piece | 110 | Not supplied | Stock quantity missing |
| 1 | 15 | 12 | Horlicks Box | box | 420 | 12 pieces | Confirm actual stock versus pack conversion |
| 1 | 16 | 13 | Chicken Masala | bundle | 250 | 13 bundles | Confirm actual stock versus pack conversion; Possible existing item: Chicken Masala |
| 1 | 17 | 14 | Parle-G Biscuits | bundle | 200 | Not supplied | Stock quantity missing |
| 1 | 18 | 15 | Good Day Biscuits | carton | 1450 | Not supplied | Stock quantity missing |
| 1 | 19 | 16 | Bounce Biscuits | packet | 100 | Not supplied | Stock quantity missing |
| 1 | 20 | 16 | Bounce Biscuits | carton | 1100 | Not supplied | Stock quantity missing |
| 1 | 21 | 17 | Peri Kiwi | piece | 20 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 22 | 17 | Peri Kiwi | packet | 180 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 23 | 17 | Peri Kiwi | bundle | 550 | 3 packets | Confirm actual stock versus pack conversion; Identity or pack size needs confirmation |
| 1 | 24 | 18 | Nihar Naturals Hair Oil 200g | piece | 300 | 260x12 noted | Confirm actual stock versus pack conversion |
| 1 | 25 | 19 | Match Sticks | piece | 85 | Not supplied | Stock quantity missing |
| 1 | 26 | 19 | Match Sticks | carton | 850 | Not supplied | Stock quantity missing |
| 1 | 27 | 20 | Playing Cards Tass | piece | 40 | 10 per bundle | Confirm actual stock versus pack conversion |
| 1 | 28 | 20 | Playing Cards Tass | bundle | 350 | Not supplied | Stock quantity missing |
| 1 | 29 | 21 | Patanjali Soap Haldi Chandan Kanti | piece | 80 | Not supplied | Stock quantity missing |
| 1 | 30 | 21 | Patanjali Soap Haldi Chandan Kanti | dozen | 900 | Not supplied | Stock quantity missing |
| 1 | 31 | 21 | Patanjali Soap Haldi Chandan Kanti Small | piece | 40 | Not supplied | Stock quantity missing |
| 1 | 32 | 21 | Patanjali Soap Haldi Chandan Kanti Small | dozen | 420 | Not supplied | Stock quantity missing |
| 1 | 33 | 22 | Comfort Dhoop | piece | 20 | Not supplied | Stock quantity missing |
| 1 | 34 | 22 | Comfort Dhoop | dozen | 180 | Not supplied | Stock quantity missing |
| 1 | 35 | 23 | Gul Sachet Packet | bundle | 250 | Not supplied | Stock quantity missing |
| 1 | 36 | 24 | Lux Soap 20rs | dozen | 200 | Not supplied | Stock quantity missing |
| 1 | 37 | 25 | Patanjali Neem Kanti Soap | piece | 40 | Not supplied | Stock quantity missing |
| 1 | 38 | 26 | Dhoni Dishwash 200g | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 39 | 26 | Dhoni Dishwash 200g | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 40 | 27 | Samar Soap | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 41 | 28 | Red Bull Soap | bundle | 580 | 6 pieces | Confirm actual stock versus pack conversion |
| 1 | 42 | 28 | Red Bull Soap | carton | 2000 | Not supplied | Stock quantity missing |
| 1 | 43 | 29 | Vim Dishwash | piece | 10 | Not supplied | Stock quantity missing |
| 1 | 44 | 29 | Vim Dishwash | dozen | 100 | Not supplied | Stock quantity missing |
| 1 | 45 | 30 | Colgate Large (crossed out) | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 46 | 31 | Colgate Medium (crossed out) | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 47 | 32 | Colgate 34g (crossed out) | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 48 | 33 | Dabur Red Toothpaste 200g (unclear) | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 49 | 34 | Dabur Red Toothpaste 100g | piece | 65 | Not supplied | Stock quantity missing |
| 1 | 50 | 35 | Dabur Red Toothpaste 175g | piece | 185 | Not supplied | Stock quantity missing |
| 1 | 51 | 36 | Dabur Red Toothpaste 90g | piece | 95 | Not supplied | Stock quantity missing |
| 1 | 52 | 37 | Colgate MaxFresh 76g | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 53 | 38 | Dant Kanti 200g | piece | 170 | Not supplied | Stock quantity missing |
| 1 | 54 | 38 | Dant Kanti 34g | piece | 35 | Not supplied | Stock quantity missing |
| 1 | 55 | 39 | Colgate MaxFresh 150g | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 56 | 40 | Lifebuoy Soap 20rs | dozen | 200 | Not supplied | Stock quantity missing |
| 1 | 57 | 40 | Lifebuoy Soap 50rs | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 58 | 41 | Lux Soap 50rs | dozen | 560 | Not supplied | Stock quantity missing |
| 1 | 59 | 42 | Patanjali Super Dishwash | piece | 30 | Not supplied | Stock quantity missing |
| 1 | 60 | 42 | Patanjali Super Dishwash | dozen | 350 | Not supplied | Stock quantity missing |
| 1 | 61 | 43 | Dhoni 250g | piece | 60 | Not supplied | Stock quantity missing |
| 1 | 62 | 43 | Dhoni 250g | dozen | 600 | Not supplied | Stock quantity missing |
| 1 | 63 | 44 | Dhoni 300g | piece | 70 | Not supplied | Stock quantity missing |
| 1 | 64 | 44 | Dhoni 300g | dozen | 680 | Not supplied | Stock quantity missing |
| 1 | 65 | 45 | Xtraa Plus Soap 200g | piece | 70 | Not supplied | Stock quantity missing |
| 1 | 66 | 45 | Xtraa Plus Soap 200g | dozen | 700 | Not supplied | Stock quantity missing |
| 1 | 67 | 46 | Dhoni Xtraa Soap 200g | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 68 | 46 | Dhoni Xtraa Soap 200g | dozen | 600 | Not supplied | Stock quantity missing |
| 1 | 69 | 47 | Tez Soap 200g | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 70 | 47 | Tez Soap 200g | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 71 | 48 | KTM Soap 100g | piece | 20 | Not supplied | Stock quantity missing |
| 1 | 72 | 48 | KTM Soap 100g | dozen | 200 | Not supplied | Stock quantity missing |
| 1 | 73 | 48 | KTM Soap 100g | carton | 800 | Not supplied | Stock quantity missing |
| 1 | 74 | 49 | KTM Soap 150g | piece | 30 | Not supplied | Stock quantity missing |
| 1 | 75 | 49 | KTM Soap 150g | dozen | 300 | Not supplied | Stock quantity missing |
| 1 | 76 | 49 | KTM Soap 150g | carton | 800 | Not supplied | Stock quantity missing |
| 1 | 77 | 50 | KTM Soap 200g | piece | 40 | Not supplied | Stock quantity missing |
| 1 | 78 | 50 | KTM Soap 200g | dozen | 400 | Not supplied | Stock quantity missing |
| 1 | 79 | 50 | KTM Soap 200g | carton | 800 | Not supplied | Stock quantity missing |
| 1 | 80 | 51 | KTM Soap 250g | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 81 | 51 | KTM Soap 250g | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 82 | 51 | KTM Soap 250g | carton | 1000 | Not supplied | Stock quantity missing |
| 1 | 83 | 52 | Mahashakti Jaiindary Soap | piece | 45 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 84 | 52 | Mahashakti Jaiindary Soap | dozen | 450 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 85 | 53 | Cloth Soap 200g | piece | 40 | Not supplied | Stock quantity missing |
| 1 | 86 | 53 | Cloth Soap 200g | dozen | 300 | Not supplied | Stock quantity missing |
| 1 | 87 | 53 | Cloth Soap A 150g | piece | 30 | Not supplied | Stock quantity missing |
| 1 | 88 | 53 | Cloth Soap A 150g | dozen | 300 | Not supplied | Stock quantity missing |
| 1 | 89 | 53 | Cloth Soap B 150g | piece | 30 | Not supplied | Stock quantity missing |
| 1 | 90 | 53 | Cloth Soap B 150g | dozen | 300 | Not supplied | Stock quantity missing |
| 1 | 91 | 53 | Cloth Soap 250g | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 92 | 53 | Cloth Soap 250g | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 93 | 59 | Garam Masala 250g | piece | 250 | Not supplied | Stock quantity missing |
| 1 | 94 | 60 | Garam Masala 100g | piece | 100 | Not supplied | Stock quantity missing |
| 1 | 95 | 71 | Nihar Oil 250g | piece | 400 | Not supplied | Stock quantity missing |
| 1 | 96 | 72 | Nihar Oil 150g | piece | 120 | Not supplied | Stock quantity missing |
| 1 | 97 | 73 | Shalimar Coconut Oil 175g | piece | 100 | Not supplied | Stock quantity missing |
| 1 | 98 | 74 | Ghee 250g | piece | 250 | Not supplied | Stock quantity missing |
| 1 | 99 | 74 | Ghee 100g | piece | 100 | Not supplied | Stock quantity missing |
| 1 | 100 | 75 | Hing Rakesh 50g | piece | 80 | Not supplied | Stock quantity missing |
| 1 | 101 | 75 | Hing Rakesh 50g | bundle | 600 | 10 per bundle | Confirm actual stock versus pack conversion |
| 1 | 102 | 76 | Parachute Coconut Oil | piece | 770 | Not supplied | Stock quantity missing |
| 1 | 103 | 77 | Amrit Plus | bag | 33000 | 5 bags; 4 bundles/bag | Confirm actual stock versus pack conversion; Identity or pack size needs confirmation |
| 1 | 104 | 77 | Amrit Plus | bundle | 8000 | 125 packets/bundle | Confirm actual stock versus pack conversion; Identity or pack size needs confirmation |
| 1 | 105 | 77 | Amrit Plus | packet | 325 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 1 | 106 | 78 | Popular Dishwash Soap | piece | 60 | Not supplied | Stock quantity missing |
| 1 | 107 | 78 | Popular Dishwash Soap | carton | 950 | Not supplied | Stock quantity missing |
| 1 | 108 | 79 | Ghee Sachet | packet | 240 | Not supplied | Stock quantity missing |
| 1 | 109 | 80 | Honey Sachet (Gayatree) | packet | 200 | Not supplied | Stock quantity missing |
| 1 | 110 | 81 | Kapoor Small | packet | 13 | Not supplied | Stock quantity missing |
| 1 | 111 | 81 | Kapoor Small | dozen | 400 | Not supplied | Stock quantity missing |
| 1 | 112 | 82 | Kapoor Big | packet | 50 | Not supplied | Stock quantity missing |
| 1 | 113 | 82 | Kapoor Big | dozen | 500 | Not supplied | Stock quantity missing |
| 1 | 114 | 83 | Ajanta Colour Bottle | kg | 550 | Not supplied | Stock quantity missing |
| 1 | 115 | 84 | Eclairs | piece | 100 | 1 | Identity or pack size needs confirmation; Possible existing item: Eclairs |
| 1 | 116 | 85 | Choco Kids | piece | 100 | 1 | Identity or pack size needs confirmation; Possible existing item: Choco Kids |
| 1 | 117 | 86 | Rock n Roll | piece | 100 | 1 | Identity or pack size needs confirmation; Possible existing item: Rock n Roll |
| 1 | 118 | 87 | Double Duck | piece | 400 | 2 noted | Confirm actual stock versus pack conversion |
| 1 | 119 | 88 | Mero Lacto | piece | 100 | 1 | Identity or pack size needs confirmation; Possible existing item: Mero lacto |
| 1 | 121 | 90 | Litchi Juice | piece | 90 | Not supplied | Stock quantity missing |
| 1 | 122 | 90 | Litchi Juice | carton | 950 | Not supplied | Stock quantity missing |
| 1 | 123 | 91 | Colgate 34g | bundle | 330 | 9 per bundle | Confirm actual stock versus pack conversion |
| 1 | 124 | 92 | Brighter | dozen | 80 | Not supplied | Stock quantity missing |
| 1 | 125 | 93 | Gul Box | packet | 290 | Not supplied | Stock quantity missing |
| 1 | 126 | 94 | Jibya | bundle | 250 | Not supplied | Stock quantity missing |
| 1 | 127 | 94 | Jibya | dozen | 35 | Not supplied | Stock quantity missing |
| 1 | 128 | 95 | Tiger Packet | packet | 100 | Not supplied | Stock quantity missing |
| 1 | 129 | 95 | Tiger Packet | carton | 1450 | Not supplied | Stock quantity missing |
| 1 | 130 | 96 | Cycle Brand Dhoop | box | 100 | Not supplied | Stock quantity missing |
| 1 | 131 | 97 | Rohini Dhoop | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 132 | 97 | Rohini Dhoop | dozen | 400 | Not supplied | Stock quantity missing |
| 1 | 133 | 98 | Ocean Dhoop | piece | 50 | Not supplied | Stock quantity missing |
| 1 | 134 | 98 | Ocean Dhoop | dozen | 480 | Not supplied | Stock quantity missing |
| 1 | 135 | 99 | Kashi Dhoop | piece | 20 | Not supplied | Stock quantity missing |
| 1 | 136 | 99 | Kashi Dhoop | dozen | 180 | Not supplied | Stock quantity missing |
| 1 | 137 | 100 | Neem | piece | 60 | Not supplied | Stock quantity missing |
| 1 | 138 | 101 | Gillette Blade Red | piece | 30 | Not supplied | Stock quantity missing |
| 1 | 139 | 101 | Gillette Blade Red | packet | 500 | Not supplied | Stock quantity missing |
| 1 | 140 | 102 | Gillette Blade Blue | piece | 20 | Not supplied | Stock quantity missing |
| 1 | 141 | 102 | Gillette Blade Blue | packet | 400 | Not supplied | Stock quantity missing |
| 1 | 142 | 103 | Bajaj Oil | packet | 160 | Not supplied | Stock quantity missing |
| 1 | 143 | 104 | Hajmola Chocolate | piece | 150 | Not supplied | Stock quantity missing |
| 1 | 144 | 105 | Cup Ship | piece | 300 | Not supplied | Stock quantity missing |
| 1 | 145 | 106 | Icy Mint | piece | 150 | Not supplied | Stock quantity missing |
| 1 | 146 | 107 | Rock n Roll B | piece | 150 | Not supplied | Stock quantity missing; Possible existing item: Rock n Roll |
| 1 | 147 | 108 | Double Duck | piece | 250 | Not supplied | Stock quantity missing |
| 1 | 148 | 109 | Ice Pop Ice Puff | piece | 160 | Not supplied | Stock quantity missing |
| 1 | 149 | 110 | Hajmola | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation; Possible existing item: Hajmola Anardana - 1 Box, Hajmola Regular |
| 2 | 2 | 1 | Aaha Laundry Soap | piece | 100 | 27 | Identity or pack size needs confirmation |
| 2 | 3 | 2 | Fizz | piece | 100 | 6 | Identity or pack size needs confirmation |
| 2 | 4 | 3 | Aayo Ultra | piece | 100 | 3 | Identity or pack size needs confirmation; Possible existing item: Aayo Ultra soap |
| 2 | 5 | 4 | Druk Laundry Soap | piece | 100 | 8 | Identity or pack size needs confirmation |
| 2 | 6 | 5 | Dhoni 200g | piece | 100 | 25 | Identity or pack size needs confirmation |
| 2 | 7 | 6 | Dhoni 250g | piece | 100 | 36 | Identity or pack size needs confirmation |
| 2 | 8 | 7 | Cheese Ball | piece | 100 | 8 | Identity or pack size needs confirmation |
| 2 | 9 | 8 | Candle Small | bundle | 120 | 3 cartons noted | Confirm actual stock versus pack conversion |
| 2 | 10 | 8 | Candle Large | bundle | 250 | 2 pieces per 5 | Confirm actual stock versus pack conversion |
| 2 | 11 | 9 | V-Series | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |
| 2 | 12 | 10 | Beat Chocolate | packet | 90 | Not supplied | Stock quantity missing |
| 2 | 13 | 11 | Badal | carton | 100 | 4 | Confirm variant/pack size and shared-stock relationship |
| 2 | 14 | 12 | Dhobi 200g | piece | 100 | Not supplied | Stock quantity missing; Identity or pack size needs confirmation |

## Catalogue totals

Retails: 46; drinks: 7; wholesale: 36; total: 89. Includes inactive records in the dashboard total.

Menu labels and dashboard breakdown have been changed in source. Backend deployment is required for the new breakdown fields; existing installed Windows releases do not contain these UI edits.

## Search-backed name corrections

Applied to the pending import list and normalized import data. The original workbook and live stock are unchanged. Correct spelling does not establish pack size or opening stock.

| Original | Corrected | Evidence / remaining detail |
|---|---|---|
| Salimar Coconut Oil | Shalimar Coconut Oil | [Source](https://shalimars.com/products). Brand spelling corrected; size remains unknown. |
| Nihari Hair Oil Natural 200g | Nihar Naturals Hair Oil 200g | [Source](https://marico.com/investorspdf/Subsidiary_2012-2013.pdf). Brand spelling normalized; exact variant and source 200g unit still require confirmation. Do not substitute 200ml automatically. |
| Salimar Coconut Oil 175g | Shalimar Coconut Oil 175g | [Source](https://shalimars.com/products). Brand spelling corrected; source weight retained, not verified online. |
| Aaha Soap | Aaha Laundry Soap | [Source](https://www.shardagroup.com/soapsandchemicals.php). Manufacturer confirms laundry-soap brand; size not inferred. |
| Druk | Druk Laundry Soap | [Source](https://himgirinepal.com/product/druk-laundry-soap/). Laundry category identifies product family; manufacturer lists multiple weights, so size remains unresolved. |
| V Series | V-Series | [Source](https://www.daraz.com.np/products/v-series-popular-laundry-soap-6-pcs-1200g-i128031443-s1035090084.html). Brand punctuation only; variant and size not inferred. |

Dhoni and Dhobi are separate real laundry-soap brands; do not merge them. Sources: [Dhoni](https://stcnepal.com/product/dhoni-laundry-soap/) and [Dhobi manufacturer](https://supertatasoap.com.np/product/dhoni-laundry-soap/).

Unresolved identities: Peri Kiwi, Mahashakti Jaiindary Soap, Cup Ship, Jibya, Brighter, Badal, Samar Soap and Neem. Similar-sounding search results are insufficient to rename these. Amrit Plus has a manufacturer-listed pan-masala product, but the exact stock variant is unconfirmed: [manufacturer](https://www.shudhplus.com/international-product.html). Fizz has a Dhoni Fizz soap listing, but the stock variant is unconfirmed: [listing](https://pricemandu.com/products/dhoni-fizz-soap-combo-pack-pack-of-3-b21f490c8129502862bc54e2704d2f9e/).
