# Faststore Final Inventory UPSERT dry run

Workbook: Faststore-Complete-Inventory-For-Update.xlsx
Preview hash: ee7ee1387f3ff8e696b7eaba0ea0d82a293ff03ad43aa6464b6ae13e4511bb1a

- Excel rows read from Final Inventory: 378
- Unique product variants after combining duplicate source rows: 374
- New records to insert: 12
- Existing records to update: 350
- Duplicate or ambiguous records requiring review: 5
- Total manual-review records: 12
- Proposed price changes: 0
- Proposed stock changes: 2
- Proposed location changes: 0

No database writes were performed. `--apply` also requires this exact preview hash.

| Excel rows | Product | Type | Action | Price old -> new | Stock old -> new | Location old -> new | Detail |
|---|---|---|---|---|---|---|---|
| 2 | Aaha Laundry Soap (piece) | retail | update | 100 -> 100 | 27 -> 27 | 2 -> 2 | Update valid product fields. |
| 3 | Aaha Soap - piece (piece) | retail | update | 100 -> 100 | 27 -> 27 | 2 -> 2 | Update valid product fields. |
| 4 | Aayo Ultra - piece - 200g (piece) | retail | update | 100 -> 100 | 3 -> 3 | 2 -> 2 | Update valid product fields. |
| 5 | Aayo Ultra soap (piece) | retail | update | 55 -> 55 | 20 -> 20 | 1 -> 1 | Update valid product fields. |
| 6 | Advanced Tea – 15 g - packet (packet) | retail | update | 100 -> 100 | 20 -> 20 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 7 | Advanced Tea – 30 g - packet (packet) | retail | update | 260 -> 260 | 20 -> 20 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 8 | Agni Detergent – 3 kg - packet (packet) | retail | update | 150 -> 150 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 9 | Agni Ghadi Detergent – 1 kg - packet (packet) | retail | update | 80 -> 80 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 10 | Agni Ghadi Detergent – 200 g - packet (packet) | retail | update | 20 -> 20 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 11 | Agni Ghadi Detergent – 3 kg - packet (packet) | retail | update | 300 -> 300 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 12 | Agni Ghadi Detergent – 500 g - packet (packet) | retail | update | 50 -> 50 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 13 | Agni Tata Tea – 10 g - bag (bag) | retail | update | 820 -> 820 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 14 | Agni Tata Tea – 14 g - bag (bag) | retail | update | 160 -> 160 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 15 | Agni Tata Tea – 33 g - bag (bag) | retail | update | 680 -> 680 | 14 -> 14 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 16 | Ajanta Colour Bottle - kg (kg) | retail | update | 550 -> 550 | 49999 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 17 | Amrit Plus - bag (bag) | retail | update | 33000 -> 33000 | 5 -> 5 | 1 -> 1 | Update valid product fields. |
| 18 | Amrit Plus - bundle (bundle) | retail | update | 8000 -> 8000 | 125 -> 125 | 1 -> 1 | Update valid product fields. |
| 19 | Amrit Plus - packet (packet) | retail | update | 325 -> 325 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 20 | Badal - carton (carton) | retail | update | 100 -> 100 | 4 -> 4 | 2 -> 2 | Update valid product fields. |
| 21 | Badal — cartoon (packet) | retail | update | 100 -> 100 | 4 -> 4 | 2 -> 2 | Update valid product fields. |
| 22 | Bajaj Oil - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 23 | Beat Chocolate - Packet (packet) | retail | update | 90 -> 90 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 24 | Bhai Tika Chandan colour - Packet (packet) | retail | update | 100 -> 100 | 14 -> 14 | 1 -> 1 | Update valid product fields. |
| 25 | Bhola - Packet (packet) | retail | update | 100 -> 100 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 26 | Bikaji Bhujiya - 400g (piece) | retail | update | 235 -> 235 | 477 -> 477 | 1 -> 1 | Update valid product fields. |
| 27 | Bikaji Papad - Packet (packet) | retail | update | 90 -> 90 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 28 | Bikaji Soan Papdi - piece (piece) | retail | update | 120 -> 120 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 29 | Black Stone agarbatti - Packet (packet) | retail | update | 100 -> 100 | 72 -> 72 | 1 -> 1 | Update valid product fields. |
| 30 | BMU Chilli Powder - Packet - 500g (packet) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 31 | BMU Chilli Powder - Packet - 200g (piece) | retail | review |  -> 130 |  -> 0 |  ->  | Missing category or packaging. |
| 32 | BMU Mixed Masala - Packet - 500g (packet) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 33 | BMU Mixed Masala - Packet - 200g (piece) | retail | review |  -> 130 |  -> 0 |  ->  | Missing category or packaging. |
| 34 | BMU Turmeric Powder - Packet - 500g (packet) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 35 | BMU Turmeric Powder - Packet - 200g (piece) | retail | review |  -> 150 |  -> 0 |  ->  | Missing category or packaging. |
| 36 | Bounce Biscuits - carton (carton) | retail | update | 1100 -> 1100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 37 | Bounce Biscuits - packet (packet) | retail | update | 1160 -> 1160 | 3 -> 3 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 38 | Brahma agarbatti - Packet (packet) | retail | update | 100 -> 100 | 360 -> 360 | 1 -> 1 | Update valid product fields. |
| 39 | Brighter - dozen (dozen) | retail | update | 80 -> 80 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 40 | Camphor (Kapoor) Large - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 41 | Camphor (Kapoor) Large - packet (packet) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 42 | Camphor (Kapoor) Small - dozen (dozen) | retail | update | 400 -> 400 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 43 | Camphor (Kapoor) Small - packet (packet) | retail | update | 13 -> 13 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 44 | Candle (Large) - bundle (bundle) | retail | update | 250 -> 250 | 2 -> 2 | 2 -> 2 | Update valid product fields. |
| 45 | Candle (Small) - bundle (bundle) | retail | update | 120 -> 120 | 3 -> 3 | 2 -> 2 | Update valid product fields. |
| 46 | Century Garam Masala Sachet - Bundle (bundle) | retail | update | 200 -> 200 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 47 | Century Masala Sachet - Bundle (bundle) | retail | update | 200 -> 200 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 48 | Chahora (Dry Khajoor) - Kilogram (kg) | retail | update | 500 -> 500 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 49 | Chakki Aata (piece) | retail | update | 580 -> 580 | 498 -> 498 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 50 | Chana Dal (kg) | retail | update | 172 -> 172 | 498000 -> 498000 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 51 | Cheese Balls - piece (piece) | retail | update | 100 -> 100 | 8 -> 8 | 2 -> 2 | Update valid product fields. |
| 52 | Chicken Masala (piece) | retail | update | 20 -> 20 | 540 -> 540 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 53 | Chicken Masala - bundle (bundle) | retail | update | 250 -> 250 | 13 -> 13 | 7 -> 7 | Update valid product fields. |
| 54 | Choco Kiddo - Packet (packet) | retail | update | 70 -> 70 | 7 -> 7 | 1 -> 1 | Update valid product fields. |
| 55 | Choco Kids - piece (piece) | retail | update | 100 -> 100 | 1 -> 1 | 7 -> 7 | Update valid product fields. |
| 56 | Chura - Packet (packet) | retail | update | 100 -> 100 | 33 -> 33 | 1 -> 1 | Update valid product fields. |
| 57 | Cloth Soap 200g - dozen (dozen) | retail | update | 300 -> 300 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 58 | Cloth Soap 200g - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 59 | Cloth Soap 250g - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 60 | Cloth Soap 250g - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 61 | Cloth Soap A 150g - dozen (dozen) | retail | update | 300 -> 300 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 62 | Cloth Soap A 150g - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 63 | Cloth Soap B 150g - dozen (dozen) | retail | update | 300 -> 300 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 64 | Cloth Soap B 150g - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 65 | Coca Cola (packet) | drinks | update | 95 -> 95 | 95 -> 95 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 66 | Coconut Candy - Piece (piece) | retail | update | 90 -> 90 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 67 | Colgate 100g - piece (piece) | retail | update | 110 -> 110 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 68 | Colgate 200g - piece (piece) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 69 | Colgate 34g (crossed out) - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 70 | Colgate 34g - bundle (bundle) | retail | update | 330 -> 330 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 71 | Colgate Large (crossed out) - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 72 | Colgate MaxFresh Toothpaste 150g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 73 | Colgate MaxFresh Toothpaste 76g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 74 | Colgate Medium (crossed out) - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 75 | Colgate Toothpaste - 190g (piece) | retail | update | 165 -> 165 | 487 -> 487 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 76 | Comfort Dhoop - dozen (dozen) | retail | update | 180 -> 180 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 77 | Comfort Dhoop - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 78 | Cup Ship - piece (piece) | retail | insert |  -> 300 |  -> 333 |  -> Unassigned | Insert as retail. |
| 79 | Current Non-Veg Noodles - packet (packet) | retail | update | 460 -> 460 | 9 -> 9 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 80 | Cycle Brand Dhoop - box (box) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 81 | Dabur Red Toothpaste 100g - piece (piece) | retail | update | 65 -> 65 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 82 | Dabur Red Toothpaste 175g - piece (piece) | retail | update | 185 -> 185 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 83 | Dabur Red Toothpaste 200g (unclear) - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 84 | Dabur Red Toothpaste 90g - piece (piece) | retail | update | 95 -> 95 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 85 | Dalchini whole masala (kg) | retail | update | 100 -> 100 | 25000 -> 25000 | 1 -> 1 | Update valid product fields. |
| 86 | DETOL S0AP (piece) | retail | update | 60 -> 60 | 489 -> 489 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 87 | DETOL SKINCARE SOAP (piece) | retail | update | 60 -> 60 | 488 -> 488 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 88 | Dhobi 200g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 89 | Dhoni 200g - piece (piece) | retail | update | 100 -> 100 | 25 -> 25 | 2 -> 2 | Update valid product fields. |
| 90 | Dhoni 250g - dozen (dozen) | retail | update | 600 -> 600 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 91 | Dhoni 250g - piece (piece) | retail | update | 60 -> 60 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 92 | Dhoni 300g - dozen (dozen) | retail | update | 680 -> 680 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 93 | Dhoni 300g - piece (piece) | retail | update | 70 -> 70 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 94 | Dhoni Detergent – 1 kg - packet (packet) | retail | update | 110 -> 110 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 95 | Dhoni Detergent – 500 g - packet (packet) | retail | update | 55 -> 55 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 96 | Dhoni Dishwash Bar 200g - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 97 | Dhoni Dishwash Bar 200g - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 98 | Dhoni Laundry Soap 200g (piece) | retail | update | 100 -> 100 | 25 -> 25 | 2 -> 2 | Update valid product fields. |
| 99 | Dhoni Xtraa Soap 200g - dozen (dozen) | retail | update | 600 -> 600 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 100 | Dhoni Xtraa Soap 200g - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 101 | Dhoop / Agarbatti - Dozen (dozen) | retail | update | 400 -> 400 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 102 | Do Phool Cooking Oil - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 103 | Doodh Biscuit Box (packet) | retail | update | 1700 -> 1700 | 15 -> 15 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 104 | Double Duck Large (piece) | retail | insert |  -> 400 |  -> 333 |  -> Unassigned | Insert as retail. |
| 105 | Double Duck Small (piece) | retail | insert |  -> 250 |  -> 333 |  -> Unassigned | Insert as retail. |
| 106 | Dream Cream - Piece (piece) | retail | update | 90 -> 90 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 107 | Dream Cream Packet (piece) | retail | review |  ->  |  -> 0 |  ->  | Missing category or packaging. |
| 109 | Druk - piece (piece) | retail | update | 100 -> 100 | 8 -> 8 | 2 -> 2 | Update valid product fields. |
| 110 | Druk Laundry Soap (piece) | retail | update | 100 -> 100 | 8 -> 8 | 2 -> 2 | Update valid product fields. |
| 111 | Eclairs Pop - packet (packet) | retail | update | 300 -> 300 | 2 -> 2 | 7 -> 7 | Update valid product fields. |
| 112 | Elaichi - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 113 | English Copy – Rs. 10 variety - piece (piece) | retail | update | 10 -> 10 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 114 | English Copy – Rs. 20 variety - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 115 | English Copy – Rs. 30 variety - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 116 | English Copy – Rs. 40 variety - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 117 | English Copy – Rs. 50 variety - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 118 | ENO Fruit Salt - piece (piece) | retail | update | 15 -> 15 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 119 | Eveready AA batteries - Packet (packet) | retail | update | 250 -> 250 | 5 -> 5 | 1 -> 1 | Update valid product fields. |
| 120 | Eya Eya Yo Noodles [check name] - packet (packet) | retail | update | 250 -> 250 | 32 -> 32 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 121 | Fevi Kwik - bundle (bundle) | retail | update | 550 -> 550 | 3 -> 3 | 7 -> 7 | Update valid product fields. |
| 122 | Fevi Kwik - packet (packet) | retail | update | 180 -> 180 | 333 -> 333 | 7 -> 7 | Update valid product fields. |
| 123 | Fevi Kwik (piece) | retail | update | 20 -> 20 | 333 -> 333 | 7 -> 7 | Update valid product fields. |
| 124 | Fizz (piece) | retail | update | 100 -> 100 | 6 -> 6 | 2 -> 2 | Update valid product fields. |
| 125 | Fizz Dozen (piece) | retail | review |  -> 500 |  -> 0 |  ->  | Missing category or packaging. |
| 126 | Flair Mist / Black Gel Pen [check product wording] - packet (packet) | retail | update | 40 -> 40 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 127 | Fortune Oil - 1 Litre (piece) | retail | update | 300 -> 300 | 150 -> 150 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 128 | Frooti Mango Drink - packet (packet) | drinks | update | 575 -> 575 | 43 -> 43 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 129 | Frooti Mango Drink – 800 ml bottle - piece (piece) | drinks | update | 100 -> 100 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 130 | Garam Masala 100g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 131 | Garam Masala 250g - piece (piece) | retail | update | 250 -> 250 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 132 | Ghee 100g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 133 | Ghee 250g - piece (piece) | retail | update | 250 -> 250 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 134 | Ghee Sachet - packet (packet) | retail | update | 240 -> 240 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 135 | Gillette Blade Reel - packet (packet) | retail | update | 550 -> 550 | 333 -> 333 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 136 | Gillette Razor Blade (Blue Pack) - packet (packet) | retail | review |  -> 400 |  -> 666 |  -> Unassigned | Ambiguous match: retail/FASTSTORE-XLSX-S1-R140, retail/FASTSTORE-XLSX-S1-R141. |
| 137 | Gillette Razor Blade (Blue Pack) - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 | 7 -> 7 | Update valid product fields. |
| 139 | Gillette Razor Blade (Red Pack) - packet (packet) | retail | review |  -> 500 |  -> 666 |  -> Unassigned | Ambiguous match: retail/FASTSTORE-XLSX-S1-R138, retail/FASTSTORE-XLSX-S1-R139. |
| 140 | Gillette Razor Blade (Red Pack) - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 | 7 -> 7 | Update valid product fields. |
| 142 | Gits Gulab Jamun (packet) | retail | update | 100 -> 100 | 29 -> 29 | 1 -> 1 | Update valid product fields. |
| 143 | Good Day Biscuits - carton (carton) | retail | update | 1450 -> 1450 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 144 | Good Day Biscuits - packet (packet) | retail | update | 1400 -> 1400 | 2 -> 2 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 145 | Gugal agarbatti - Packet (packet) | retail | update | 100 -> 100 | 60 -> 60 | 1 -> 1 | Update valid product fields. |
| 146 | Gul Box - packet (packet) | retail | review |  -> 290 |  -> 666 |  -> 7, Unassigned | Ambiguous match: retail/FASTSTORE-XLSX-S1-R125, retail/FINAL-INV-ed7ad63487aa-89. |
| 148 | Gul Sachet Packet - bundle (bundle) | retail | update | 250 -> 250 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 149 | Gundam Premium CTC Tea - packet (packet) | retail | update | 115 -> 115 | 30 -> 30 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 150 | Hajmola - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 151 | Hajmola Chocolate - piece (piece) | retail | update | 150 -> 150 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 152 | Harpic Super Harpic - Piece (piece) | retail | update | 80 -> 80 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 153 | Herbal Patanjali Detergent – 450 g - packet (packet) | retail | update | 50 -> 50 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 154 | Herbal Patanjali Detergent – 850 g - packet (packet) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 155 | Honey Sachet (Gayatree) - packet (packet) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 156 | Horlicks - 15 sachet packet (packet) | retail | update | 125 -> 125 | 34 -> 34 | 1 -> 1 | Update valid product fields. |
| 157 | Horlicks Box - box (box) | drinks | update | 420 -> 420 | 12 -> 12 | 7 -> 7 | Update valid product fields. |
| 158 | Horlicks Small Sachet (piece) | drinks | update | 10 -> 10 | 391 -> 391 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 159 | Hot n Spicy Rumpum Noodles - packet (packet) | retail | update | 480 -> 480 | 16 -> 16 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 160 | Ice Pop Ice Puff - piece (piece) | retail | update | 160 -> 160 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 161 | Ice Puff - Packet (packet) | retail | update | 100 -> 100 | 12 -> 12 | 1 -> 1 | Update valid product fields. |
| 162 | Icy Mint - piece (piece) | retail | update | 150 -> 150 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 163 | Imli Chilli Candy - Piece (piece) | retail | update | 90 -> 90 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 164 | Jackpot Noodles - packet (packet) | retail | update | 360 -> 360 | 23 -> 23 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 165 | Jayfal - Piece (piece) | retail | update | 5 -> 5 | 333 -> 333 | 1 -> 1 | Update valid product fields. |
| 166 | Jayfal and Jaypatri - Piece (piece) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 167 | Jeera Marich - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 168 | Jibya - bundle (bundle) | retail | update | 250 -> 250 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 169 | Jibya - dozen (dozen) | retail | update | 35 -> 35 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 170 | Jiwan Jal Relyte - Carton (carton) | retail | update | 700 -> 700 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 171 | Jiwan Jal Relyte - Dozen (dozen) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 172 | Jiwan Jal Relyte - Piece (piece) | retail | update | 10 -> 10 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 173 | Kacha Mango - Piece (piece) | retail | update | 85 -> 85 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 174 | Kaka Jeera - Kilogram (kg) | retail | update | 600 -> 600 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 175 | Kashi Dhoop - dozen (dozen) | retail | update | 180 -> 180 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 176 | Kashi Dhoop - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 177 | Kerau Seed - Kilogram (kg) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 178 | Khetan's Mausam Gold Masala / Premium CTC Tea – 1 kg - packet (packet) | retail | update | 750 -> 750 | 20 -> 20 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 179 | Khetan's Mausam Gold Masala / Premium CTC Tea – 500 g - packet (packet) | retail | update | 380 -> 380 | 50 -> 50 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 180 | Khukuri - packet (packet) | retail | update | 70 -> 70 | 1 -> 1 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 181 | Kismis - Kilogram (kg) | retail | update | 800 -> 800 | 333 -> 333 | 1 -> 1 | Update valid product fields. |
| 182 | Krish Noodles - packet (packet) | retail | update | 360 -> 360 | 40 -> 40 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 183 | KTM Soap 100g - carton (carton) | retail | update | 800 -> 800 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 184 | KTM Soap 100g - dozen (dozen) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 185 | KTM Soap 100g - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 186 | KTM Soap 150g - carton (carton) | retail | update | 800 -> 800 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 187 | KTM Soap 150g - dozen (dozen) | retail | update | 300 -> 300 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 188 | KTM Soap 150g - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 189 | KTM Soap 200g - carton (carton) | retail | update | 800 -> 800 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 190 | KTM Soap 200g - dozen (dozen) | retail | update | 400 -> 400 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 191 | KTM Soap 200g - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 192 | KTM Soap 250g - carton (carton) | retail | update | 1000 -> 1000 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 193 | KTM Soap 250g - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 194 | KTM Soap 250g - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 195 | Kuchkuch Dalbut (piece) | retail | insert |  -> 215 |  -> 493 |  -> Unassigned | Insert as retail. |
| 196 | Lali Piro 2x Spicy - packet (packet) | retail | update | 460 -> 460 | 4 -> 4 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 197 | Laung - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 198 | LAYS - LARGE (piece) | retail | update | 80 -> 80 | 492 -> 492 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 199 | Lays - small (piece) | retail | update | 50 -> 50 | 492 -> 492 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 200 | Leechi - Piece (piece) | retail | update | 90 -> 90 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 201 | Lifebuoy Soap 20rs - dozen (dozen) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 202 | Lifebuoy Soap 50rs - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 203 | Lighter - packet (packet) | retail | update | 500 -> 500 | 4 -> 4 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 204 | Litchi Juice - carton (carton) | drinks | update | 950 -> 950 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 205 | Litchi Juice - piece (piece) | drinks | update | 90 -> 90 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 206 | Lux Body Wash - Piece (piece) | retail | update | 30 -> 30 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 207 | Lux Soap 20rs - dozen (dozen) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 208 | Lux Soap 50rs - dozen (dozen) | retail | update | 560 -> 560 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 209 | Madhu gutka (piece) | retail | update | 100 -> 100 | 50 -> 50 | 1 -> 1 | Update valid product fields. |
| 210 | Madhu Sopari (kg) | retail | update | 100 -> 100 | 100000 -> 100000 | 1 -> 1 | Update valid product fields. |
| 211 | Mahashakti Jaiindary Soap - dozen (dozen) | retail | update | 450 -> 450 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 212 | Mahashakti Jaiindary Soap - piece (piece) | retail | update | 45 -> 45 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 213 | Mango Bite Chocolate - packet (packet) | retail | update | 90 -> 90 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 214 | Manoj Sesame Oil – 1 litre - packet (packet) | retail | update | 350 -> 350 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 215 | Manoj Sesame Oil – ½ litre - packet (packet) | retail | update | 175 -> 175 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 216 | Marie Gold Biscuit (piece) | retail | update | 20 -> 20 | 483 -> 483 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 217 | Matchsticks - carton (carton) | retail | update | 850 -> 850 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 218 | Matchsticks - piece (piece) | retail | update | 85 -> 85 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 219 | Math Copy – Rs. 10 variety - piece (piece) | retail | update | 10 -> 10 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 220 | Math Copy – Rs. 20 variety - piece (piece) | retail | update | 20 -> 20 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 221 | Math Copy – Rs. 30 variety - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 222 | Math Copy – Rs. 40 variety - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 223 | Math Copy – Rs. 50 variety - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 224 | Melody - Piece (piece) | retail | update | 180 -> 180 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 225 | Mini Shikhar - Packet (packet) | retail | update | 100 -> 100 | 8 -> 8 | 7 -> 7 | Update valid product fields. |
| 226 | Moong Dal (g) | retail | update | 210 -> 210 | 500000 -> 500000 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 227 | More Light (Liril) - Piece (piece) | retail | update | 40 -> 40 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 228 | Nagu Ji Oil? – 1 litre - carton (carton) | retail | update | 5600 -> 5600 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 229 | Nagu Ji Oil? – ½ litre - carton (carton) | retail | update | 4350 -> 4350 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 230 | Nataraj Pencil - bag (bag) | retail | update | 80 -> 80 | 333 -> 333 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 231 | Navaratan Oil - 24 sachet packet (packet) | retail | update | 100 -> 100 | 50 -> 50 | 1 -> 1 | Update valid product fields. |
| 232 | Neem Soap (piece) | retail | insert |  -> 60 |  -> 333 |  -> Unassigned | Insert as retail. |
| 233 | Nepali Copy – Rs. 10 (piece) | retail | insert |  -> 10 |  -> 333 |  -> 3 | Insert as retail. |
| 234 | Nepali Copy – Rs. 20 (piece) | retail | insert |  -> 20 |  -> 333 |  -> 3 | Insert as retail. |
| 235 | Nepali Copy – Rs. 30 (piece) | retail | insert |  -> 30 |  -> 333 |  -> 3 | Insert as retail. |
| 236 | Nepali Copy – Rs. 40 (piece) | retail | insert |  -> 40 |  -> 333 |  -> 3 | Insert as retail. |
| 237 | Nepali Copy – Rs. 50 (piece) | retail | insert |  -> 50 |  -> 333 |  -> 3 | Insert as retail. |
| 238 | Nihar Hair Oil 150g - piece (piece) | retail | update | 120 -> 120 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 239 | Nihar Hair Oil 250g - piece (piece) | retail | update | 400 -> 400 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 240 | Nihar Naturals Hair Oil 200g - piece (piece) | retail | update | 300 -> 300 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 241 | Nilkamal - 1 Litre (packet) | retail | update | 2800 -> 2800 | 100 -> 100 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 242 | Nilkamal - 1/2 Litre Box (packet) | retail | update | 2800 -> 2800 | 50 -> 50 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 243 | Nischal Masala Mix CTC Tea – 800 g - packet (packet) | retail | update | 270 -> 270 | 30 -> 30 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 244 | Nutrela Soya Chunks - Bag (bag) | retail | update | 900 -> 900 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 245 | Nutrela Soya Chunks - Packet (packet) | retail | update | 40 -> 40 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 246 | Nycil (piece) | retail | update | 100 -> 100 | 42 -> 42 | 1 -> 1 | Update valid product fields. |
| 247 | Ocean Dhoop - dozen (dozen) | retail | update | 480 -> 480 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 248 | Ocean Dhoop - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 249 | Orange Bite Chocolate - packet (packet) | retail | update | 90 -> 90 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 250 | Oreo Biscuit (piece) | retail | update | 20 -> 20 | 516 -> 516 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 251 | Packet Garam Masala - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 252 | Packet Sopari - packet (packet) | retail | update | 80 -> 80 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 253 | Pan King - Packet (packet) | retail | update | 310 -> 310 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 254 | Panchmeva [check spelling] - packet (packet) | retail | update | 160 -> 160 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 255 | Pandit Ji Dhoop - Packet (packet) | retail | update | 100 -> 100 | 2 -> 2 | 1 -> 1 | Update valid product fields. |
| 256 | Parachute Coconut Oil - piece (piece) | retail | update | 770 -> 770 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 257 | Parle-G Biscuits - bundle (bundle) | retail | update | 200 -> 200 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 258 | Patanjali Dant Kanti Toothpaste 200g - piece (piece) | retail | update | 170 -> 170 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 259 | Patanjali Dant Kanti Toothpaste 34g - piece (piece) | retail | update | 35 -> 35 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 260 | Patanjali Haldi Chandan Kanti Soap (Small) - dozen (dozen) | retail | update | 420 -> 420 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 261 | Patanjali Haldi Chandan Kanti Soap (Small) - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 262 | Patanjali Haldi Chandan Kanti Soap - dozen (dozen) | retail | update | 900 -> 900 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 263 | Patanjali Haldi Chandan Kanti Soap - piece (piece) | retail | update | 80 -> 80 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 264 | Patanjali Neem Kanti Soap - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 265 | Patanjali Popular Detergent – 2 kg - packet (packet) | retail | update | 200 -> 200 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 266 | Patanjali Popular Detergent – 750 g - packet (packet) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 267 | Patanjali Super Dishwash - dozen (dozen) | retail | update | 350 -> 350 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 268 | Patanjali Super Dishwash - piece (piece) | retail | update | 30 -> 30 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 269 | Pena Agni Detergent (Nepali) – 1 kg - packet (packet) | retail | update | 120 -> 120 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 270 | Pena Agni Detergent (Nepali) – 3 kg - packet (packet) | retail | update | 250 -> 250 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 271 | Pena Detergent (Indian) – 1 kg - packet (packet) | retail | update | 120 -> 120 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 272 | Pepsi (piece) | drinks | update | 90 -> 90 | 494 -> 494 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 273 | Peri Kiwi — bundle (l) | retail | update | 550 -> 550 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 274 | Peri Kiwi — packet (packet) | retail | update | 180 -> 180 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 275 | Peri Kiwi — piece (piece) | retail | update | 20 -> 20 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 276 | Phenyl - Piece (piece) | retail | update | 100 -> 100 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 277 | Playing Cards (Taash) - bundle (bundle) | retail | update | 350 -> 350 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 278 | Playing Cards (Taash) - piece (piece) | retail | update | 40 -> 40 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 279 | Popular Dishwash Soap - carton (carton) | retail | update | 950 -> 950 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 280 | Popular Dishwash Soap - piece (piece) | retail | update | 60 -> 60 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 281 | Rajnigandha (piece) | retail | update | 50 -> 50 | 593 -> 593 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 282 | Rajniwas - Bag (bag) | retail | update | 1180 -> 1180 | 333 -> 333 | 2 -> 2 | Update valid product fields. |
| 283 | Rajniwas - Packet (packet) | retail | update | 230 -> 230 | 333 -> 333 |  ->  | Update valid product fields. |
| 284 | Rakesh Garam Masala - Bundle (bundle) | retail | update | 360 -> 360 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 285 | Rakesh Hing 50g - bundle (bundle) | retail | update | 600 -> 600 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 286 | Rakesh Hing 50g - piece (piece) | retail | update | 80 -> 80 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 287 | Rakesh Meat Masala - Bundle (bundle) | retail | update | 360 -> 360 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 288 | Red Bull Soap - bundle (bundle) | retail | update | 580 -> 580 | 6 -> 6 | 7 -> 7 | Update valid product fields. |
| 289 | Red Bull Soap - carton (carton) | retail | update | 2000 -> 2000 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 290 | Redbull - 250ml (piece) | drinks | update | 115 -> 115 | 575 -> 575 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 291 | Riddhi Siddhi Tea - piece (piece) | retail | update | 100 -> 100 | 10 -> 10 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 292 | Rio (Mango & Glucose) Frooti Drink - carton (carton) | drinks | update | 450 -> 450 | 151 -> 151 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 293 | Rock n Roll - piece (piece) | retail | update | 100 -> 100 | 1 -> 1 | 7 -> 7 | Update valid product fields. |
| 294 | Rock n Roll B - piece (piece) | retail | update | 150 -> 150 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 295 | Rohini Dhoop - dozen (dozen) | retail | update | 400 -> 400 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 296 | Rohini Dhoop - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 297 | Rose Soap - dozen (dozen) | retail | update | 450 -> 450 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 298 | Rose Soap - piece (piece) | retail | update | 53 -> 53 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 299 | Rumpum Non-Veg Noodles - packet (packet) | retail | update | 480 -> 480 | 214 -> 214 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 300 | Rumpum Veg Noodles - packet (packet) | retail | update | 480 -> 480 | 16 -> 16 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 301 | Sagar MilkPowder - 500g (piece) | retail | update | 560 -> 560 | 100 -> 100 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 302 | Salimar Coconut Oil 175g - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 303 | Samar Soap - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 304 | Sargam – 900 g - packet (packet) | retail | update | 80 -> 80 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 305 | Sattu - 500g (piece) | retail | insert |  -> 147 |  -> 475 |  -> Unassigned | Insert as retail. |
| 306 | Sep Special Sadhya Tea - bag (bag) | retail | update | 800 -> 800 | 6 -> 6 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 307 | Shalimar Coconut Oil - dozen (dozen) | retail | update | 240 -> 240 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 308 | Shubharam Premium CTC Masala Tea – approx. 500 g - packet (packet) | retail | update | 150 -> 150 | 20 -> 20 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 309 | Small Kapoor - Packet (packet) | retail | update | 100 -> 100 | 324 -> 324 | 1 -> 1 | Update valid product fields. |
| 310 | Snackers - packet (packet) | retail | update | 240 -> 240 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 311 | SOIL (piece) | retail | update | 120 -> 120 | 5 -> 5 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 312 | Sprite- 90ml (piece) | drinks | update | 95 -> 95 | 63 -> 63 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 313 | Sugar (kg) | retail | update | 120 -> 120 | 199340 -> 199340 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 314 | Sunflower - 1 litre Box (piece) | retail | update | 300 -> 300 | 60 -> 60 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 315 | Surf Excel Detergent – 1 kg - packet (packet) | retail | update | 210 -> 210 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 316 | Surf Excel Detergent – 500 g - packet (packet) | retail | update | 110 -> 110 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 317 | Swastik Ghee – 1 litre - packet (packet) | retail | update | 290 -> 290 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 318 | Swastik Ghee – ½ litre - packet (packet) | retail | update | 145 -> 145 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 319 | Swastik Vanaspati - carton (carton) | retail | update | 2850 -> 2850 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 320 | Tea Dost - Packet (packet) | drinks | update | 165 -> 165 | 333 -> 333 | 5 -> 5 | Update valid product fields. |
| 321 | Tez Soap 200g - dozen (dozen) | retail | update | 500 -> 500 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 322 | Tez Soap 200g - piece (piece) | retail | update | 50 -> 50 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 323 | Tiger Biscuits - carton (carton) | retail | update | 1450 -> 1450 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 324 | Tiger Biscuits - packet (packet) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 325 | Tokla tea (piece) | drinks | update | 50 -> 50 | 478 -> 478 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 326 | Tokla Tea small sachet (piece) | drinks | update | 10 -> 10 | 483 -> 483 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 327 | Tokla Tea – 500 g - packet (packet) | retail | update | 275 -> 275 | 3 -> 3 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 328 | Trishul - 1 Litre Box (packet) | retail | update | 2800 -> 2800 | 60 -> 60 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 329 | Trishul - 1/2 Litre Box (packet) | retail | update | 2800 -> 2800 | 40 -> 40 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 330 | V Series - piece (piece) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 331 | V Series - dozen (piece) | retail | review |  -> 500 |  -> 0 |  -> 2 | Missing category or packaging. |
| 332 | Vaseline - bundle (bundle) | retail | update | 500 -> 500 | 1 -> 1 | 7 -> 7 | Update valid product fields. |
| 333 | Vim Dishwash Bar - dozen (dozen) | retail | update | 100 -> 100 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 334 | Vim Dishwash Bar - piece (piece) | retail | update | 10 -> 10 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 335 | Vim Washing soap (packet) | retail | update | 45 -> 45 | 486 -> 486 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 336 | Wai Wai Mama Bhujya - carton (carton) | retail | update | 250 -> 250 | 2 -> 2 | 3 -> 3 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 337 | Wai Wai Non-Veg Noodles - packet (packet) | retail | update | 530 -> 530 | 12 -> 12 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 338 | Wai Wai Veg Noodles - packet (packet) | retail | update | 530 -> 530 | 20 -> 5 | 4 -> 4 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 339 | Wheel Detergent – 500 g - packet (packet) | retail | update | 50 -> 50 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 340 | Xtraa Detergent Powder – 500 g - packet (packet) | retail | update | 50 -> 50 | 333 -> 333 | 6 -> 6 | Update valid product fields. |
| 341 | Xtraa Plus Soap 200g - dozen (dozen) | retail | update | 700 -> 700 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 342 | Xtraa Plus Soap 200g - piece (piece) | retail | update | 70 -> 70 | 333 -> 333 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 343 | Ajanta assorted colours - Box (box) | wholesale | update | 100 -> 100 | 48 -> 48 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 344 | Bidi - Bundle (bundle) | wholesale | update | 100 -> 100 | 57 -> 57 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 345 | butter back biscuit box (box) | wholesale | update | 2800 -> 2800 | 4 -> 4 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 346 | Center Fruit (box) | wholesale | update | 290 -> 290 | 126 -> 126 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 347 | choco choco pouch (box) | wholesale | review |  -> 390 |  -> 4200 |  -> Unassigned | New packaging could be retail or wholesale; the workbook does not explicitly identify its inventory type. |
| 348 | Choco Choco chocolate - Box (box) | wholesale | update | 100 -> 100 | 6 -> 6 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 349 | Choco Kids (box) | wholesale | update | 350 -> 350 | 18 -> 18 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 350 | Coca cola (packet) | wholesale | update | 960 -> 960 | 89 -> 89 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 351 | Coffee Chocolate - Box (box) | wholesale | update | 100 -> 100 | 40 -> 40 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 352 | current 2x spicy (piece) | wholesale | update | 380 -> 380 | 20 -> 20 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 353 | Current spicy chips (packet) | wholesale | update | 380 -> 380 | 6 -> 6 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 354 | Eclairs - piece (piece) | wholesale | update | 100 -> 100 | 1 -> 1 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 355 | Exo Soap (piece) | wholesale | update | 570 -> 570 | 8 -> 8 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 356 | fortune 1 litre box (box) | wholesale | update | 2850 -> 2850 | 70 -> 70 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 357 | Frooti Mango Drink (box) | wholesale | update | 625 -> 625 | 488 -> 488 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 358 | Hajmola Anardana - 1 Box (piece) | wholesale | update | 250 -> 250 | 35 -> 35 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 359 | Hajmola Regular (piece) | wholesale | update | 250 -> 250 | 9 -> 9 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 360 | HUNK piece (piece) | wholesale | update | 100 -> 100 | 24 -> 24 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 361 | Imli bomb (piece) | wholesale | update | 220 -> 220 | 23 -> 23 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 362 | Lotte Choco Pie box (box) | wholesale | update | 300 -> 300 | 7 -> 7 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 363 | Lux Soap 12 pieces (piece) | wholesale | insert |  -> 500 |  -> 42 |  -> Unassigned | Insert as wholesale. |
| 364 | Makhan - Bag (bag) | wholesale | update | 100 -> 100 | 4 -> 4 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 365 | Mero Lacto (piece) | wholesale | update | 100 -> 100 | 1 -> 1 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 366 | Neha Mehndi Box (box) | wholesale | update | 100 -> 100 | 25 -> 25 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 367 | Orange Creme biscuit Bundle (bundle) | wholesale | update | 600 -> 600 | 4 -> 4 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 368 | Power soap (box) | wholesale | update | 800 -> 800 | 15 -> 15 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 369 | Rock n Roll (box) | wholesale | update | 450 -> 450 | 6 -> 6 | 2 -> 2 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 370 | shree brand (box) | wholesale | update | 2800 -> 2800 | 14 -> 14 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 371 | Soan Papdi Box - box (box) | wholesale | update | 200 -> 200 | 333 -> 333 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 372 | Sumo Lacto - piece (piece) | wholesale | update | 100 -> 100 | 1 -> 1 | 7 -> 7 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 373 | Tata tea leaves 100g - Bundle (bundle) | wholesale | update | 800 -> 800 | 84 -> 84 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 374 | Technotip Black (packet) | wholesale | update | 150 -> 150 | 500 -> 500 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 375 | Technotip Blue (packet) | wholesale | update | 150 -> 150 | 500 -> 500 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 376 | Technotip Blue (box) | wholesale | review |  -> 550 |  -> 56 |  -> Unassigned | New packaging could be retail or wholesale; the workbook does not explicitly identify its inventory type. |
| 377 | Waiwai Noodles (box) | wholesale | update | 350 -> 350 | 496 -> 496 |  ->  | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 378 | Zareen Mehndi - Box (box) | wholesale | update | 100 -> 100 | 17 -> 17 | 1 -> 1 | Update valid product fields. Location remains unchanged because the Excel room is missing or not configured. |
| 379 | Suji (piece) | retail | review |  -> 160 |  -> 0 |  -> 7 | Missing category or packaging. |

