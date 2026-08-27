# Kansjor Borewell — Business Context

> Business facts only, scoped to the Flutter apps (mobile + desktop via shared package) and the Laravel backend.
> No design, layout, colour, type, or UI-flow notes live here.
> `[PLACEHOLDER]` = made-up data. Replace before use. `[CONFIRM]` = check this fact.

## 1. Identity

- Legal name: Kansjor Borewell Pvt Ltd
- Display name: Kansjor Borewell (renamed from JP / J.P Bricks; technical IDs like package name stay unchanged)
- Business: Brick factory. It does not drill borewells. The name is old. The land and family are the same.
- Address: Kansjor Industrial Area, near NH-16, Jatani–Khordha Road, Bhubaneswar, Odisha 752050 `[PLACEHOLDER]`
- Area served: Jatani, Khordha, Bhubaneswar, Cuttack
- Start year: 2016 `[CONFIRM]`
- Type: Maker of hydraulic-pressed bricks and paver blocks
- Fleet: Own trucks. About 80 km range from plant. Two trucks + backup `[PLACEHOLDER]`

## 2. History

- Name Kansjor is the village and land parcel. First firm was Kansjor Borewell for ground water work. Rigs are gone. Name stays.
- Start: One pan mixer and Hydraulic Press 1. Made fly ash bricks for local builders.
- Later: Added Press 2 and steel paver moulds for parking pavers. Moulds: I Shape, Milano, Zig Zag, Hexagon, Basil. Sizes 60 mm and 80 mm.
- Now: Two presses, curing yard, own trucks.

## 3. Products

| Product | Size | Strength (28 days) | Cure | Standard | Use | Code |
|---|---|---|---|---|---|---|
| Fly Ash Brick | 230×110×75 mm | 7.5–10 N/mm² | 14 days water | IS 12894 | Load walls, boundary walls | FLY-ASH |
| Red Clay Brick | 230×110×70 mm | 3.5–5 N/mm² | Kiln fired | — | Partition, infill | CLAY-01 |
| Solid Concrete Block | 400×200×200 mm | 4–5 N/mm² | 14 days water | IS 2185 | Retaining walls | SOLID-400 |
| Paver 60 mm (I Shape / Milano / Hexagon / Basil) | ~200×165×60 mm | 30–35 N/mm² | 7–10 days water | IS 15658 | Walkways, parking, yards | PAVER-60 |
| Paver 80 mm (Zig Zag) | ~225×112×80 mm | 40–50 N/mm² | 10–14 days water | IS 15658 | Driveways, yards, light roads | PAVER-80 |
| Paver 100 mm | 100 mm thick | 50+ N/mm² | 14 days water | IS 15658 | Industrial yards | PAVER-100 |

- Tolerance: ±2 mm on length/width. Edges not chipped.
- Water absorption: <10% fly ash, <6% pavers.
- Efflorescence: nil to small.
- Colours: Red, Yellow, White, Black. Colour is in the mix, not on top.
- Moulds: I Shape, Milano, Zig Zag, Hexagon, Basil. Plus one test mould.
- Presses: Hydraulic Press 1, Hydraulic Press 2. Each production entry logs meter start and end.
- Recipe/BOM: Each product variant has its own recipe (fly ash, OPC, stone dust, aggregate by weight). Recipes are a separate domain concept from product variants; each variant retains its own recipe.

## 4. How We Make It

1. Batch and mix — Weigh fly ash, OPC, stone dust, aggregate per recipe. Each size has its own recipe. Mix in pan mixer.
2. Press — Press at high force in steel moulds. Not table mould. Not wire cut.
3. Strike and demould — Crew moves green bricks to pallets. Check edges.
4. Water cure — Cure with water spray. Fly ash 14 days. Pavers 7–14 days by thickness.
5. Stack, count, test — Stack lots. Count. Test strength, water absorption, efflorescence. Use IS 12894 and IS 15658.
6. Load and send — Count per challan. Loading crew loads. Cover with tarpaulin. Note freight and GST. Update closing stock same day.

## 5. Operating Rules

- Mix by weight, not by eye. Each product variant has its own recipe.
- Cure for full days. No short cure.
- Stock ledger is daily per product: opening + made − sent = closing. Use it for quotes. It stops double sale.
- Meter log: Each production entry has press meter start and end.
- Crews do the work: Striking Group demoulds. Loading Group stacks and loads.

## 6. Team and Roles

- Owner family on site each day.
- Crew: Two press operators, striking crew, loading crew, ledger clerk, drivers.
- Small scale. Owner knows each pallet.
- Access model: role-based administration. Admin implicitly holds all permissions and is protected from rename, deletion, and permission changes. Only non-admin roles are editable through the app.
- Authorization uses granular, feature-scoped permissions (view/create/edit/delete/export per feature), enforced by backend route middleware, mobile/desktop route guards, and UI gating. Permission gates for the same resource are identical across mobile and desktop.
- Reference/master data readable by all authenticated roles; writes restricted to admin and manager.
- Login and /me responses include the user's permission list so clients gate UI without extra round-trips.

## 7. Quality Tests

| Test | When | Standard | Pass |
|---|---|---|---|
| Compressive strength | Each batch, 7 and 28 days | IS 12894, IS 15658 | Fly ash 7.5–10, Pavers 30–50 by thickness |
| Water absorption | Each batch | IS 12894, IS 15658 | <10% fly ash, <6% pavers |
| Efflorescence | Each week | Visual | Nil to small |
| Size and square | Each press run | IS codes | ±2 mm, edges ok |
| Meter reading | Each entry | Internal | Log start and end |

## 8. Orders and Dispatch

- Retail and small sites: 500–5,000 units. Same day if stock is ready.
- Bulk: 10,000+ units. Plan lots. Daily ledger. One GST challan per load. Rate on call.
- Custom colour and size: 60/80/100 mm pavers in four colours. Need 3–5 days if mould and colour are in stock.
- Quote inputs: Product + thickness + quantity + pin code + contact name.
- Delivery: Own fleet, no broker. Range about 80 km from Kansjor plant. Lead time: stock sizes next day, custom or big lots 2–4 days. Call site contact one hour before arrival.
- Freight and GST: One price. Yard price + freight + GST 18% if due, on one challan.
- Master data (parties, vehicles, drivers, machines/products) is dynamic and managed through the app's master screens — never hardcoded.

## 9. Registers and Reports

- Production register and dispatch register both support a date-range filter capped at 30 days and CSV export for the selected period.
- The 30-day cap is enforced in both backend and client.
- CSV exports save to the device Downloads folder.
- Dates shown to users are human-readable (e.g., "12 Aug 2026"); ISO format is kept for API queries and CSV filenames.
- Stock ledger is daily per product and is the source for quotes and double-sale prevention.

## 10. Contact

> Placeholders. Replace before use.

- Yard: Kansjor Industrial Area, near NH-16, Jatani–Khordha Road, Bhubaneswar, Odisha 752050 `[PLACEHOLDER]`
- Phone: +91 99XXX XXXXX `[PLACEHOLDER]` Mon–Sat 08:00–18:00. Owner answers after hours for bulk.
- WhatsApp: +91 99XXX XXXXX `[PLACEHOLDER]`
- Email: sales@kansjorborewell.in `[PLACEHOLDER]` For POs and challans.
- Hours: Mon–Sat 08:00–18:00. Sunday closed. Phone on for urgent bulk.

## 11. Rules and Standards

- IS 12894 — Fly ash bricks
- IS 15658 — Paver blocks
- IS 2185 — Solid blocks
- GST 18% on freight if due
- Copy line: © Kansjor Borewell Pvt Ltd

## 12. Facts To Confirm Before Launch

- [ ] True yard address with plot number
- [ ] True phone / WhatsApp / email
- [ ] Start year (now 2016)
- [ ] Fleet size and truck types
- [ ] Delivery range if not 80 km
- [ ] Test lab details

## 13. Source of Truth

- Codes and names must match app and backend exactly: product codes `FLY-ASH`, `CLAY-01`, `SOLID-400`, `PAVER-60`, `PAVER-80`, `PAVER-100`; machines `Hydraulic Press 1`, `Hydraulic Press 2`; crews `Striking Group`, `Loading Group`; module `Stock Ledger`.
- Strengths, sizes, colours, mould names match plant data. Keep identical in backend seeders, API responses, and both Flutter apps.
