# J.P Bricks — Agent Build Specification

Build an inventory, recipe (BOM), paver-block production, and dispatch management system for a
fly ash brick and paver-block manufacturing company. Paver block sizes such as 60mm and 80mm
are product variants, each of which may have its own recipe (BOM). Two separate codebases in one repo root:

```
jp-bricks/
├── backend/     Laravel 13 API (MySQL, Sanctum auth)
└── mobile/      Flutter app (Android + iOS), consumes the backend API
```

Build `backend/` first and fully working (migrations, models, endpoints, auth,
seeders) before starting `mobile/`. The mobile app has no local business logic —
it is a thin client over the API.

---

## 1. Tech stack

**backend/**
- Laravel 13, PHP 8.3+
- MySQL 8
- Laravel Sanctum for token-based API auth (mobile app is a pure API consumer)
- Laravel policies for role-based permission checks
- Form Requests for validation, API Resources for response shaping

**mobile/**
- Flutter 3.x, Dart null-safety
- Riverpod for state management
- `dio` for HTTP + interceptors (auth token, error handling)
- `go_router` for navigation
- `flutter_secure_storage` for storing the auth token
- No local database — always calls the API live; a lightweight in-memory cache is fine, no offline sync in v1

---

## 2. Design guidelines (applies to mobile UI and the backend's JSON responses shaping data for it)

Keep the UI **simple, clean, and professional** — this is a factory/office tool used
by non-technical staff, not a consumer app.

- One accent color only (teal/green, e.g. `#0F6E56`), everything else neutral grays and white.
- Flat design: no gradients, no shadows beyond a subtle 1px card border, no decorative icons.
- Large tap targets and large readable numbers — screens are used on the factory floor, often in daylight.
- Every entry screen: big number input fields, a dropdown/picker instead of free text wherever a master list exists (machine, product/paver-block variant, vehicle, party) — staff should almost never have to type a name from scratch.
- Every list/report screen: today's date visible at top, most recent entries first.
- Bottom navigation with exactly the sections the logged-in role needs (see §4) — do not show tabs a role can't use.
- Support both English and Hindi labels is a nice-to-have, not required for v1.

---

## 3. Roles & permissions

| Role | Can access |
|---|---|
| admin | everything, including user management and all reports |
| manager | production entry, stock ledger, dispatch, parties/vehicles, reports (read) |
| operator | production entry only |
| accountant | dispatch entry, freight/payments, reports (read) |

Enforce with Laravel policies on every controller action, not just by hiding UI.

---

## 4. Backend — structure & build order

### 4.1 Folder structure
```
backend/
├── app/
│   ├── Models/            User, Role, RawMaterial, RawMaterialTransaction,
│   │                       Supplier, Purchase, BrickType, Recipe, RecipeIngredient,
│   │                       Machine, ProductionEntry, StockLedger, Vehicle, Driver,
│   │                       Party, Dispatch, Payment
│   ├── Http/
│   │   ├── Controllers/Api/   one controller per resource above, RESTful
│   │   ├── Requests/          StoreXRequest / UpdateXRequest per resource
│   │   └── Resources/         XResource for each model (JSON shaping)
│   ├── Policies/           one per model needing role restriction
│   └── Services/           StockLedgerService, ProductionService, DispatchService
│                            (business logic — see §4.3 — keep out of controllers)
├── database/
│   ├── migrations/         one per table in the schema doc (jp_bricks_schema.sql)
│   └── seeders/            RoleSeeder, AdminUserSeeder, BrickTypeSeeder (demo data)
└── routes/api.php
```

### 4.2 Database
Use the schema already defined in `jp_bricks_schema.sql` as the source of truth for
migrations — same table and column names, same foreign keys. Translate each
`CREATE TABLE` into a Laravel migration 1:1.

### 4.3 Core business logic (put in Services, not controllers)

**ProductionService::store(data)**
1. Create `production_entries` row.
2. Look up the active `recipe` for the selected product variant, including 60mm/80mm paver-block variants; for each `recipe_ingredients` row, compute `quantity_per_batch * (quantity_produced / recipe.output_qty)` and deduct it from `raw_materials.current_stock`, logging a `raw_material_transactions` row (`type = out`, `reference_type = production_entry`).
3. Call `StockLedgerService::applyProduction(date, brick_type_id, quantity_produced)`.

**StockLedgerService::applyProduction / applyDispatch**
- Find or create today's `stock_ledger` row for that `brick_type_id`.
- `opening_stock` = yesterday's `closing_stock` for the same brick type (0 if none exists yet).
- Update `production_qty` or `sale_qty` accordingly.
- Recompute `closing_stock = opening_stock + production_qty - sale_qty`.
- Update `brick_types.current_stock` to the new `closing_stock` (denormalized field used for fast dashboard reads).

**DispatchService::store(data)**
1. Create `dispatches` row.
2. Call `StockLedgerService::applyDispatch(date, brick_type_id, quantity_loaded)`.
3. If `freight_amount` is set and marked paid immediately, create a `payments` row.

### 4.4 API endpoints

Auth:
```
POST   /api/login            { mobile, password } -> { token, user }
POST   /api/logout
GET    /api/me
```

Masters (standard REST — index/store/show/update/destroy — admin & manager only for write):
```
/api/raw-materials
/api/suppliers
/api/brick-types
/api/recipes                 (nested: /api/recipes/{id}/ingredients)
/api/machines
/api/vehicles
/api/drivers
/api/parties
```

Transactions:
```
GET    /api/production-entries?date=&machine_id=&brick_type_id=
POST   /api/production-entries

GET    /api/dispatches?date=&party_id=&vehicle_id=
POST   /api/dispatches

GET    /api/purchases
POST   /api/purchases

GET    /api/payments
POST   /api/payments
```

Reports / dashboard:
```
GET /api/dashboard/summary            today's production, sale, closing stock per brick type
GET /api/reports/stock-ledger?from=&to=&brick_type_id=
GET /api/reports/production?from=&to=&machine_id=      machine-wise output comparison
GET /api/reports/dispatch?from=&to=&party_id=&vehicle_id=
GET /api/reports/raw-material-usage?from=&to=
GET /api/raw-materials/low-stock                       items at/below reorder_level
```

All authenticated routes go through `auth:sanctum`; role checks via policies.

### 4.5 Build order for the agent
1. Laravel install, Sanctum setup, migrations for all tables in the schema doc.
2. Models + relationships + policies.
3. Seeders: roles, one admin user, a handful of brick types/machines for demo/testing.
4. Auth endpoints, verify login works end-to-end.
5. Master-data CRUD endpoints (raw materials, brick types, recipes, machines, vehicles, drivers, parties).
6. ProductionService + production-entries endpoint; verify stock ledger updates correctly.
7. DispatchService + dispatches endpoint; verify stock deducts correctly.
8. Purchases + payments endpoints.
9. Reports/dashboard endpoints.
10. Write a Postman/Insomnia collection or `.http` file covering every endpoint for manual testing.

---

## 5. Mobile — structure & build order

### 5.1 Folder structure
```
mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api_client.dart        dio instance, base URL, token interceptor
│   │   ├── theme.dart             single accent color, text styles (see §2)
│   │   └── router.dart            go_router config, role-based route guards
│   ├── features/
│   │   ├── auth/                  login screen, token storage
│   │   ├── dashboard/             home screen — today's summary per role
│   │   ├── production/            entry form + today's list
│   │   ├── stock/                 stock ledger view (read-only, filter by brick type/date)
│   │   ├── dispatch/              entry form + today's list
│   │   ├── masters/                raw materials, recipes, brick types, machines, vehicles, drivers, parties (simple list + add/edit forms, admin/manager only)
│   │   └── reports/                production comparison, dispatch summary, low-stock alerts
│   └── shared/
│       ├── widgets/                 AppButton, AppTextField, AppDropdown, AppCard, EmptyState — shared components so every screen looks consistent
│       └── models/                  Dart models mirroring the API resources
```

### 5.2 Screens (v1)

| Screen | Roles | Notes |
|---|---|---|
| Login | all | mobile number + password |
| Home / dashboard | all (content varies by role) | today's production, sale, stock per brick type; low-stock banner |
| New production entry | admin, manager, operator | machine + brick type dropdown, quantity, meter readings, remarks |
| Today's production list | admin, manager, operator | |
| Stock ledger | admin, manager, accountant | date range + brick type filter |
| New dispatch entry | admin, manager, accountant | vehicle + driver + party dropdown, quantity, tarpaulin qty, freight |
| Today's dispatch list | admin, manager, accountant | |
| Masters (raw materials / recipes / brick types / machines / vehicles / drivers / parties) | admin, manager | simple list + add/edit sheet per item |
| Reports | admin, manager, accountant | machine-wise output, party/vehicle-wise dispatch, low-stock |
| Profile / logout | all | |

### 5.3 Build order for the agent
1. Project setup: dependencies, folder structure, theme, router skeleton.
2. `api_client.dart` with token interceptor; login screen (mobile number + password) wired to `/api/login`; token stored in secure storage; route guard redirects to login when unauthenticated.
3. Dashboard screen calling `/api/dashboard/summary`.
4. Production entry screen (form + list), wired to `/api/production-entries`, dropdowns populated from `/api/machines` and `/api/brick-types`.
5. Dispatch entry screen (form + list), wired to `/api/dispatches`, dropdowns from `/api/vehicles`, `/api/drivers`, `/api/parties`, `/api/brick-types`.
6. Stock ledger screen.
7. Masters screens (raw materials, recipes with ingredient picker, brick types, machines, vehicles, drivers, parties) — CRUD, admin/manager only.
8. Reports screens.
9. Role-based navigation: build the bottom nav bar dynamically from the logged-in user's role.
10. Empty/error/loading states on every screen using the shared `EmptyState`/`AppCard` widgets — never a blank white screen.

---

## 6. Environment / config

- `backend/.env`: standard Laravel DB vars + `SANCTUM_STATEFUL_DOMAINS` not needed (mobile uses bearer tokens, not cookies).
