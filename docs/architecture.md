# Architecture — أبو وتين (Wateen Shop)

> Layered reference of the whole application: runtime topology, repository layout,
> data model, money/price logic, barcode rules and the authentication flow.

- [1. Stack](#1-stack)
- [2. Runtime topology](#2-runtime-topology)
- [3. Repository layout](#3-repository-layout)
- [4. Data model](#4-data-model)
- [5. Money, prices and profit](#5-money-prices-and-profit)
- [6. Barcode rules](#6-barcode-rules)
- [7. Authentication flow](#7-authentication-flow)
- [8. Currency rate](#8-currency-rate)
- [9. Error handling](#9-error-handling)
- [10. Design principles](#10-design-principles)

---

## 1. Stack

| Layer | Technology | Version | Notes |
|---|---|---|---|
| Frontend | React + React Router | 18.3 / 6.24 | Vite 5.3, plain CSS (no UI framework) |
| HTTP client | axios | 1.7 | One interceptor pair for auth |
| Barcodes | `jsbarcode` | 3.11 | SVG rendering (preview + PDF) |
| PDF | `jspdf` | 2.5 | A4 label grid, SVG → image |
| Scanner | `@zxing/browser` | 0.1.5 | Camera decoding via `getUserMedia` |
| TLS in dev | `@vitejs/plugin-basic-ssl` | 1.2 | `getUserMedia` needs a secure context |
| Backend | Express | 4.19 | `cors`, `express.json()` |
| ODM | Mongoose | 8.4 | MongoDB (Atlas in production) |
| Auth | `jsonwebtoken` + `bcryptjs` | 9.0 / 3.0 | HS256 JWT, bcrypt cost 10 |
| Config | `dotenv` | 16.4 | `backend/.env` |

Everything is plain JavaScript (CommonJS in the backend, ESM in the frontend) — no TypeScript.

---

## 2. Runtime topology

```
   Phone / Desktop browser
            │  HTTPS (self-signed in dev)
            ▼
   ┌────────────────────────────┐
   │  Vite dev server :5173     │   serves React app + TLS (basic-ssl)
   │  proxy  /api  ─────────────┼──┐
   └────────────────────────────┘  │
                                   ▼
                    ┌──────────────────────────┐
                    │  Express API :5000        │
                    │  /api/* (JWT protected)   │
                    └───────────┬──────────────┘
                                │
              ┌─────────────────┼──────────────────┐
              ▼                 ▼                  ▼
        MongoDB (Atlas)   sp-today API      bcrypt / JWT
        8 collections     (USD rate)         (local)
```

- The frontend never talks to MongoDB or to the currency API directly; everything goes through the Express API.
- `/api` is proxied by Vite in both `dev` and `preview` mode (`frontend/vite.config.js`), so the frontend always calls the **same origin** `/api/...`.
- To point the frontend at another backend: `VITE_API_TARGET=https://api.example.com` (proxy target) or `VITE_API_URL=https://api.example.com/api` (absolute axios base URL).
- The camera scanner requires a **secure context**: `https://` or `localhost`. Plain `http://<LAN-IP>` will fail with `NotAllowedError`.

---

## 3. Repository layout

```
wateen-shop/
├── package.json              # root: install-all / dev / backend / frontend scripts
├── README.md                 # quick start + documentation index
├── docs/
│   ├── architecture.md       # ← this file
│   ├── backend.md            # every backend module in detail
│   ├── api.md                # full REST reference
│   ├── frontend.md           # every page / component / state
│   ├── permissions.md        # permission matrix & user management
│   └── features.md           # feature-by-feature user guide
│
├── backend/
│   ├── server.js             # app bootstrap, route mounting, admin seeding
│   ├── .env                  # secrets & configuration (never commit)
│   ├── permissions.js        # ★ single source of truth for the 15 permissions
│   ├── barcode.js            # GTIN normalisation + validation + check digit
│   ├── rates.js              # USD→SYP fetch with 10-minute cache
│   ├── middleware/auth.js    # signToken, authenticate, requirePerm, requireAdmin
│   ├── models/               # Product, Sale, Expense, Inventory, Customer, Debt, Cashbox, User
│   └── routes/               # auth, users, products, sales, expenses, inventory, customers, cashbox, rates
│
└── frontend/
    ├── index.html            # lang="ar" dir="rtl", mobile-web-app meta
    ├── vite.config.js        # react + basic-ssl + /api proxy
    └── src/
        ├── main.jsx          # React root
        ├── App.jsx           # shell, routing, tab bar, account sheet, guards
        ├── api.js            # axios instance + every API call of the app
        ├── styles.css        # complete design system (817 lines)
        ├── context/AuthContext.jsx
        ├── lib/auth.js       # token storage + hasPermission()
        ├── lib/barcode.js    # mirror of backend/barcode.js (client-side preview)
        ├── components/       # Icons, BarcodePreview, BarcodeScanner, CustomerSelect
        └── pages/            # Login, Products, Sell, Barcodes, Expenses, Profit, Debts, Inventory, Users
```

---

## 4. Data model

Eight Mongoose collections. All money fields are **numbers** (not `Decimal128`).

### 4.1 `products`

| Field | Type | Rules |
|---|---|---|
| `name` | String | required |
| `barcode` | String | unique, sparse → `null` means "no barcode yet" |
| `unit` | String | required, default `قطعة` |
| `quantity` | Number | default `0` — the live stock counter |
| `purchasePrice` | Number | required |
| `purchaseCurrency` | `'SYP' \| 'USD'` | default `SYP` |
| `salePrices[]` | sub-docs | `{ price, note, date }` — **price history** |
| `createdAt` | Date | default now |

Virtual `currentSalePrice` → the **last** element of `salePrices` (or `null`).
A sale-price entry is never overwritten: adding a new price appends a new entry, so the
price history is preserved and the old price can still be traced.

### 4.2 `sales`

| Field | Type | Notes |
|---|---|---|
| `product` | ObjectId → Product | required |
| `quantity` | Number | required |
| `salePrice` | Number | required — snapshot of the price at sale time |
| `purchasePrice` | Number | snapshot, for profit calculation |
| `purchaseCurrency` | `'SYP' \| 'USD'` | snapshot |
| `usdRate` | Number | USD rate snapshot at sale time |
| `onCredit` | Boolean | `true` = sale to a person (debt), `false` = cash |
| `customer` | ObjectId → Customer | set only when `onCredit` |
| `date` | Date | default now |

Virtuals: `profitPerUnitSYP`, `totalProfitSYP`, `totalSYP`.
Every monetary value is **snapshotted** — later changes to the product never rewrite past sales.

### 4.3 `expenses`

`{ title*, amount*, currency: 'SYP'|'USD', date, note }`

### 4.4 `inventories` (stock-take snapshots)

```
{ items: [{ product, name, recordedQty, actualQty }], note, date }
```
`recordedQty` = the quantity in the system before the count, `actualQty` = what was counted.
Saving a stock-take **overwrites** `products.quantity` with `actualQty`.

### 4.5 `customers` (people who owe the shop)

`{ name*, phone, note, initialBalance, createdAt }`
`initialBalance` = debt that existed before the app was used (opening balance).

### 4.6 `debts` (movements, not balances)

| Field | Type | Notes |
|---|---|---|
| `customer` | ObjectId → Customer | required |
| `type` | `'debit' \| 'credit'` | debit = new debt, credit = repayment |
| `amount` | Number | required, > 0 |
| `note` | String | |
| `source` | `'manual' \| 'sale'` | `sale` = auto-created by a credit sale |
| `sale` | ObjectId → Sale | set when `source === 'sale'` |
| `date` | Date | |

Balance is **derived**, never stored:

```
balance(customer) = customer.initialBalance
                  + Σ debit.amount
                  − Σ credit.amount
```

### 4.7 `cashbox` (single document)

`{ key: 'main' (unique), initialBalance, updatedAt }` — the opening float of the cash box.

### 4.8 `users`

| Field | Type | Rules |
|---|---|---|
| `username` | String | required, unique, lowercase, trimmed |
| `passwordHash` | String | bcrypt, cost 10 — never returned by the API |
| `name` | String | display name |
| `role` | `'admin' \| 'user'` | default `user` |
| `permissions` | [String] | keys from `backend/permissions.js` |
| `active` | Boolean | default `true` |
| `createdAt` | Date | |

Instance methods: `setPassword(plain)`, `checkPassword(plain)`, `toSafe()`.
`toSafe()` returns `permissions: ['*']` for admins and never includes `passwordHash`.

### 4.9 Relations

```
Product ──< Sale ──(optional)──> Customer
                    │
                    └──< Debt (source='sale')
Customer ──< Debt
Product ──< Inventory.items
```

---

## 5. Money, prices and profit

All internal arithmetic happens in **SYP (ل.س)**.

```
purchase in SYP  →  cost = purchasePrice
purchase in USD  →  cost = purchasePrice × usdRate          (usdRate snapshot of the sale)

profitPerUnitSYP = salePrice − cost
totalProfitSYP   = profitPerUnitSYP × quantity
totalSYP         = salePrice × quantity
```

**Cash-box summary** (`GET /api/cashbox`):

```
salesCash     = Σ (sales where onCredit = false) salePrice × quantity
salesCredit   = Σ (sales where onCredit = true)  salePrice × quantity
salesProfit   = Σ sales.totalProfitSYP
expensesTotal = Σ (currency = 'USD' ? amount × currentRate : amount)

current    = initialBalance + salesCash − expensesTotal      ← money physically in the box
netProfit  = salesProfit   − expensesTotal                    ← business profit
debtsTotal = Σ customer.initialBalance + Σdebit − Σcredit     ← receivables
```

Note the asymmetry that is intentional: **credit sales are excluded from the cash box**
(they are receivables, not cash) but they are included in `debtsTotal`.

---

## 6. Barcode rules

Shared logic, duplicated on both sides (`backend/barcode.js` and `frontend/src/lib/barcode.js`):

1. `normalizeBarcode(code)` → strips spaces and dashes.
2. A barcode is **valid** when it is all digits, length ∈ {8, 12, 13, 14} and the **GTIN
   check digit** matches (weights 3,1,3,1… from the right).
3. `barcodeFormat(code)` → `EAN13` (13), `EAN8` (8), `ITF14` (14), otherwise `CODE128`.

**Internal generation** (`generateInternalBarcode` in `backend/routes/products.js`):

```
payload = "200000000000" + incrementing 12-digit sequence   →  13 digits total
barcode = payload + gtinCheckDigit(payload)                  →  valid EAN-13
```

The `20…` prefix keeps internally generated codes in a reserved range that cannot collide
with real EAN-13 codes. Generation happens automatically when:

- a product is added with an empty/invalid barcode,
- a product is updated with an invalid barcode,
- the barcode page runs a bulk generation for products without a valid code.

---

## 7. Authentication flow

```
  POST /api/auth/login { username, password }
        │
        ├─ user not found OR password mismatch ──────────────► 401 "اسم المستخدم أو كلمة المرور غير صحيحة"
        ├─ user.active === false ────────────────────────────► 403 "هذا الحساب معطّل — راجع الأدمن"
        └─ OK → { token: <JWT HS256, 30 days>, user: toSafe() }
                          │
                          ▼
        localStorage: wateen_token, wateen_user
                          │
        every request →  Authorization: Bearer <token>
                          │
        401 on any request → interceptor clears the session
                            + dispatches window event "wateen:unauthorized"
                            → AuthContext sets user = null → login screen
```

- `GET /api/auth/me` is called on app boot to revalidate the stored session; a failure
  clears it and shows the login screen.
- The token is **stateless** — there is no server-side session table and no logout endpoint;
  logging out simply deletes the local token.
- `role: 'admin'` bypasses every `requirePerm` check (server side *and* client side).
- Users are stored in the `users` collection, never in a JWT payload, so permissions
  changed by the admin take effect on the user's next `/auth/me` refresh.

---

## 8. Currency rate

`backend/rates.js` → `getUsdRate()`:

- Source: `CURRENCY_API_URL` (sp-today compatible API), key sent as `x-api-key`.
- City: `CURRENCY_CITY` (default `damascus`), uses the `sell` price.
- **Cached for 10 minutes** in module scope; on failure the last known value is returned
  (or `null` if the API was never reachable).
- `GET /api/rate` is **public** so the login screen can show the rate chip.
- The frontend refreshes the chip every 5 minutes (`App.jsx`).

---

## 9. Error handling

- `wrapAsync(router)` in `server.js` wraps every route handler so rejected promises reach
  the Express error handler instead of killing the process.
- Global handler returns `{ error: "<message>" }` with the status of `err.status` or `500`.
- Unknown `/api/*` → `404 { error: 'المسار غير موجود' }`.
- `unhandledRejection` / `uncaughtException` are logged, never fatal.
- All client code reads `error.response?.data?.error` and displays it in a `.msg.error` box.

---

## 10. Design principles

1. **Server is the authority.** The UI hides controls the user cannot use, but every
   endpoint re-checks the permission — a hidden button is a convenience, not a security measure.
2. **Snapshots, never live references.** A sale stores the prices and the USD rate it used,
   so history stays correct when prices change.
3. **Derived balances.** Debts and the cash-box summary are computed from movements;
   only the opening balance is stored.
4. **One permission catalogue** (`backend/permissions.js`) is served to the admin UI via
   `GET /api/auth/permissions`, so adding a permission is a one-line change.
5. **Mobile-first, RTL, Arabic.** Single column, bottom tab bar, large touch targets,
   `dir="rtl"` throughout, numbers formatted with `ar-SY`.
