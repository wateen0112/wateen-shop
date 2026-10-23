# Backend Guide — أبو وتين

> Module-by-module reference of the Express/Mongoose API. Endpoint bodies and examples
> live in [`api.md`](./api.md); the permission matrix lives in [`permissions.md`](./permissions.md).

- [1. Bootstrap (`server.js`)](#1-bootstrap-serverjs)
- [2. Middleware (`middleware/auth.js`)](#2-middleware-middlewareauthjs)
- [3. Permission catalogue (`permissions.js`)](#3-permission-catalogue-permissionsjs)
- [4. Utilities (`barcode.js`, `rates.js`)](#4-utilities-barcodejs-ratesjs)
- [5. Models](#5-models)
- [6. Route modules](#6-route-modules)
- [7. Environment variables](#7-environment-variables)
- [8. Scripts & operations](#8-scripts--operations)

---

## 1. Bootstrap (`server.js`)

Responsibilities, in order:

1. `require('dotenv').config()` — loads `backend/.env`.
2. `app.use(cors())` — open CORS (the frontend is served from another origin in production).
3. `app.use(express.json())` — JSON body parsing (default 100 kb limit).
4. `wrapAsync(router)` — wraps every handler of a router so that a rejected promise is
   forwarded to `next()` instead of becoming an unhandled rejection.
5. Route mounting:

   | Mount | Auth | Router |
   |---|---|---|
   | `/api/products` | `authenticate` | `routes/products.js` |
   | `/api/sales` | `authenticate` | `routes/sales.js` |
   | `/api/expenses` | `authenticate` | `routes/expenses.js` |
   | `/api/inventory` | `authenticate` | `routes/inventory.js` |
   | `/api/customers` | `authenticate` | `routes/customers.js` |
   | `/api/cashbox` | `authenticate` | `routes/cashbox.js` |
   | `/api/users` | `authenticate` | `routes/users.js` (then `requireAdmin` inside) |
   | `/api/auth` | public except `/me` + `/change-password` | `routes/auth.js` |
   | `/api` | public | `routes/rates.js` → `GET /api/rate` |

6. `app.use('/api', …)` → `404 { error: 'المسار غير موجود' }` for anything unmatched.
7. Global error handler → `{ error }` with `err.status || 500`.
8. `process.on('unhandledRejection' | 'uncaughtException')` → log only, never crash.
9. `mongoose.connect(MONGO_URI)` → `ensureAdmin()` → `app.listen(PORT || 5000)`.

### `ensureAdmin()`

Seeds the **first** admin account, but only when the `users` collection is completely empty:

```js
username = (process.env.ADMIN_USERNAME || 'admin').toLowerCase()
password = process.env.ADMIN_PASSWORD || 'admin123'
role     = 'admin'          // full permission set
```

The credentials are printed once to the server console:
`[auth] تم إنشاء حساب الأدمن: admin / admin123`.

> After changing `ADMIN_PASSWORD` in `.env` the account is **not** updated automatically —
> change it from the app (*حسابي → تغيير كلمة المرور*) or delete the user and restart.

---

## 2. Middleware (`middleware/auth.js`)

### `signToken(user)` → `string`

Creates a HS256 JWT signed with `process.env.JWT_SECRET`:

```js
{ sub: user._id, role: user.role }, { expiresIn: '30d' }
```

### `authenticate(req, res, next)`

1. Reads `Authorization: Bearer <token>`.
2. No header → `401 { error: 'يجب تسجيل الدخول' }`.
3. `jwt.verify` failure → `401 { error: 'جلسة غير صالحة — سجّل الدخول من جديد' }`.
4. Loads the user from MongoDB → not found or `active === false` → `401 { error: 'هذا الحساب معطّل — راجع الأدمن' }`.
5. Sets `req.user` (the Mongoose document) and calls `next()`.

> The user is re-read from the database on every request, so deactivating a user or
> changing their permissions takes effect immediately — no token revocation needed.

### `requirePerm(...keys)` → middleware

```js
if (req.user.role === 'admin') return next();          // admins bypass everything
if (keys.some(k => req.user.permissions.includes(k))) return next();
return res.status(403).json({ error: 'لا تملك صلاحية لهذا الإجراء' });
```

Several keys mean **OR**: `requirePerm('barcodes.manage', 'products.edit')` passes when the
user owns *either* permission.

### `requireAdmin(req, res, next)`

```js
if (req.user.role === 'admin') return next();
res.status(403).json({ error: 'هذه الصفحة للأدمن فقط' });
```

---

## 3. Permission catalogue (`permissions.js`)

The **single source of truth**, shared by the API and the admin UI.

```js
const PERMISSIONS = [
  { key: 'products.view',  label: 'عرض الأصناف',                    group: 'الأصناف والمخزون' },
  { key: 'products.edit',  label: 'إضافة وتعديل الأصناف والأسعار',   group: 'الأصناف والمخزون' },
  { key: 'barcodes.view',  label: 'عرض الباركودات',                 group: 'الأصناف والمخزون' },
  { key: 'barcodes.manage',label: 'توليد وطباعة الباركودات',        group: 'الأصناف والمخزون' },
  { key: 'inventory.view', label: 'عرض الجرد',                      group: 'الأصناف والمخزون' },
  { key: 'inventory.edit', label: 'تنفيذ الجرد',                    group: 'الأصناف والمخزون' },
  { key: 'sales.create',   label: 'إجراء عمليات البيع',             group: 'المبيعات' },
  { key: 'debts.view',     label: 'عرض الديون',                     group: 'الديون والمالية' },
  { key: 'debts.edit',     label: 'إدارة الديون والأشخاص',          group: 'الديون والمالية' },
  { key: 'expenses.view',  label: 'عرض المصروفات',                  group: 'الديون والمالية' },
  { key: 'expenses.edit',  label: 'إضافة وتعديل المصروفات',         group: 'الديون والمالية' },
  { key: 'cashbox.view',   label: 'عرض الصندوق',                    group: 'الديون والمالية' },
  { key: 'cashbox.edit',   label: 'تعديل رصيد الصندوق',             group: 'الديون والمالية' },
  { key: 'reports.view',   label: 'عرض الأرباح والملخصات',           group: 'التقارير والإدارة' },
  { key: 'users.manage',   label: 'إدارة المستخدمين والصلاحيات',    group: 'التقارير والإدارة' },
];
```

Exports:

| Export | Value | Used by |
|---|---|---|
| `PERMISSIONS` | the array above | `GET /api/auth/permissions`, admin UI matrix |
| `ALL_PERMISSIONS` | `['products.view', …]` | filtering unknown keys, admin seeding |
| `DEFAULT_USER_PERMISSIONS` | `products.view, barcodes.view, sales.create, debts.view, expenses.view, cashbox.view` | applied when a user is created without an explicit list |

Adding a permission = add one line here → it immediately appears in the admin matrix and
becomes assignable. Remember to also add a `requirePerm` guard on the relevant routes.

---

## 4. Utilities (`barcode.js`, `rates.js`)

### `backend/barcode.js`

| Export | Behaviour |
|---|---|
| `normalizeBarcode(code)` | `String(code \|\| '').replace(/[\s-]/g, '')` |
| `gtinCheckDigit(payload)` | weights 3,1,3,1… from the right → `(10 - sum % 10) % 10` |
| `isValidBarcode(code)` | digits only **and** length ∈ {8,12,13,14} **and** check digit matches |

### `backend/rates.js`

`getUsdRate()` → `Promise<number|null>`

- 10-minute in-memory cache (`{ rate, at }`).
- Fetches `process.env.CURRENCY_API_URL` with header `x-api-key: CURRENCY_API_KEY`.
- Reads `data.rates.find(r => r.code === 'USD').cities[CURRENCY_CITY].sell`
  (falls back to the first available city).
- On any error → logs `Rate fetch failed: …` and returns the last cached value.
- CLI self-test: `node rates.js` prints the rate and exits with code 1 when it cannot fetch one.

---

## 5. Models

| File | Collection | Key fields | Virtuals / methods |
|---|---|---|---|
| `models/Product.js` | `products` | `name*`, `barcode` (unique+sparse), `unit*`, `quantity`, `purchasePrice*`, `purchaseCurrency`, `salePrices[]`, `createdAt` | `currentSalePrice` |
| `models/Sale.js` | `sales` | `product*`, `quantity*`, `salePrice*`, `purchasePrice*`, `purchaseCurrency*`, `usdRate*`, `onCredit`, `customer`, `date` | `profitPerUnitSYP`, `totalProfitSYP`, `totalSYP` |
| `models/Expense.js` | `expenses` | `title*`, `amount*`, `currency`, `date`, `note` | — |
| `models/Inventory.js` | `inventories` | `items[{product,name,recordedQty,actualQty}]`, `note`, `date` | — |
| `models/Customer.js` | `customers` | `name*`, `phone`, `note`, `initialBalance`, `createdAt` | — |
| `models/Debt.js` | `debts` | `customer*`, `type` (`debit`/`credit`), `amount*`, `note`, `source` (`manual`/`sale`), `sale`, `date` | — |
| `models/Cashbox.js` | `cashboxes` | `key` (`main`, unique), `initialBalance`, `updatedAt` | — |
| `models/User.js` | `users` | `username*` (unique, lowercase), `passwordHash*`, `name`, `role`, `permissions[]`, `active`, `createdAt` | `setPassword`, `checkPassword`, `toSafe` |

`*` = required. `toJSON` strips `passwordHash` on every model that has one.

---

## 6. Route modules

### 6.1 `routes/auth.js` — public router mounted at `/api/auth`

| Method | Path | Auth | Behaviour |
|---|---|---|---|
| GET | `/permissions` | public | Returns the `PERMISSIONS` catalogue (used to build the admin matrix before login). |
| POST | `/login` | public | Validates credentials, returns `{ token, user }`. 400 if a field is missing, 401 on bad credentials, 403 if the account is disabled. |
| GET | `/me` | `authenticate` | Returns `req.user.toSafe()` — used on boot to revalidate the session. |
| POST | `/change-password` | `authenticate` | Body `{ currentPassword, newPassword }`. 400 if the new password is shorter than 4 characters or the current one is wrong. Returns `{ ok: true }`. |

`username` is lower-cased and trimmed before lookup, so `Sara` and `sara` are the same user.

### 6.2 `routes/users.js` — admin-only router mounted at `/api/users`

`router.use(requireAdmin)` applies to every route in the file.

| Method | Path | Behaviour |
|---|---|---|
| GET | `/` | All users sorted by creation date, mapped through `toSafe()`. |
| POST | `/` | Creates a user. Validation: username required, password ≥ 4 chars, username unique. Role `admin` ⇒ all permissions; role `user` ⇒ the submitted list, or `DEFAULT_USER_PERMISSIONS` when the list is empty. Unknown permission keys are dropped. |
| PUT | `/:id` | Partial update: `name`, `role`, `permissions[]`, `active`, `password`. Guards: the **last active admin** cannot be demoted or deactivated; password shorter than 4 chars is rejected. |
| DELETE | `/:id` | 400 when deleting your own account or the last admin. Otherwise the document is removed. |

### 6.3 `routes/products.js` — `/api/products`

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| GET | `/` | `products.view` | Optional `?search=` → matches `name` (case-insensitive regex) **or** exact `barcode`. Sorted by `-createdAt`. |
| GET | `/no-barcode` | `barcodes.view` \| `products.view` | Products whose barcode is not a valid GTIN (name, unit, barcode only). |
| POST | `/` | `products.edit` | Creates a product. Empty/invalid barcode ⇒ a valid internal EAN-13 is generated. Response includes `barcodeGenerated: true/false`. 400 `الباركود مستخدم مسبقاً` on duplicate. |
| POST | `/generate-barcodes` | `barcodes.manage` \| `products.edit` | Body `{ ids: [] }` for a selection, or `{ all: true }` for every product. Generates codes only where the current barcode is invalid; returns `[{ id, name, barcode, generated }]`. |
| POST | `/:id/sale-price` | `products.edit` | Appends `{ price, note }` to `salePrices` (price history). 404 if the product is missing. |
| PUT | `/:id` | `products.edit` | Partial update; an invalid `barcode` in the body is replaced by a generated one. |
| DELETE | `/:id` | `products.edit` | Removes the product. |

### 6.4 `routes/sales.js` — `/api/sales`

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| POST | `/` | `sales.create` | Body `{ barcode }` or `{ productId }`, `quantity`, optional `onCredit` + `customerId`. 404 if the product does not exist, 400 if the stock is insufficient or the product has no sale price, 400 if a credit sale has no valid customer. On success: decrements `product.quantity`, stores the sale with price/rate snapshots, and — for credit sales — creates a `Debt` (`type:'debit'`, `source:'sale'`). |
| GET | `/profit` | `reports.view` \| `cashbox.view` | `{ totalProfitSYP, salesCount }` over all sales. |

### 6.5 `routes/expenses.js` — `/api/expenses`

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| GET | `/` | `expenses.view` | All expenses, newest first. |
| POST | `/` | `expenses.edit` | `{ title*, amount*, currency, note }` → 201. |
| DELETE | `/:id` | `expenses.edit` | `{ ok: true }`. |
| GET | `/total` | `expenses.view` \| `reports.view` | `{ totalSYP }` — USD expenses converted with the current rate. |

### 6.6 `routes/inventory.js` — `/api/inventory`

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| GET | `/sheet` | `inventory.view` | All products with `name, unit, quantity, barcode` — the rows of the stock-take sheet. |
| GET | `/` | `inventory.view` | Historical stock-take documents, newest first. |
| POST | `/` | `inventory.edit` | Body `{ items: [{ productId, actualQty }], note }`. For each item the previous quantity is stored as `recordedQty` and **`product.quantity` is overwritten with `actualQty`**. Unknown product ids are skipped. |

### 6.7 `routes/customers.js` — `/api/customers`

Balance helper `withBalances(customers)` aggregates all `debts` once and attaches
`balance = initialBalance + Σdebit − Σcredit` to every customer.

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| GET | `/` | `debts.view` | All customers with their balances, sorted by name. |
| GET | `/:id` | `debts.view` | One customer + `movements` (debt history, newest first). 404 if missing. |
| POST | `/` | `debts.edit` | Creates a person; `initialBalance` is the opening debt. |
| PUT | `/:id` | `debts.edit` | Updates name/phone/note/initialBalance. |
| DELETE | `/:id` | `debts.edit` | Deletes the person **and all their debt movements**. |
| POST | `/:id/debt` | `debts.edit` | Body `{ type: 'debit'\|'credit', amount, note }`. 400 when the amount is missing/≤ 0 or the person does not exist. `source:'manual'`. |
| DELETE | `/:customerId/debt/:debtId` | `debts.edit` | Removes one movement (scoped to the customer). |

### 6.8 `routes/cashbox.js` — `/api/cashbox`

| Method | Path | Guard | Behaviour |
|---|---|---|---|
| GET | `/` | `cashbox.view` | Full summary: `initialBalance, salesCash, salesCredit, salesProfit, expensesTotal, current, netProfit, debtsTotal, salesCount`. |
| PUT | `/` | `cashbox.edit` | Body `{ initialBalance }` → upserts the `main` document and returns the fresh summary. |

### 6.9 `routes/rates.js` — `/api/rate`

`GET /api/rate` (public) → `{ usdToSYP, source: 'api' | 'not-configured' }`.

---

## 7. Environment variables

`backend/.env` (never commit it):

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `PORT` | no | `5000` | API port |
| `MONGO_URI` | **yes** | — | MongoDB connection string |
| `CURRENCY_API_URL` | no | — | sp-today compatible API URL; without it the rate is `null` |
| `CURRENCY_API_KEY` | no | — | Sent as `x-api-key` |
| `CURRENCY_CITY` | no | `damascus` | City price used |
| `JWT_SECRET` | **yes** | — | HS256 signing key — use a long random string |
| `ADMIN_USERNAME` | no | `admin` | Username of the seeded admin |
| `ADMIN_PASSWORD` | no | `admin123` | Password of the seeded admin — **change it** |
| `ADMIN_NAME` | no | `المدير` | Display name of the seeded admin |

---

## 8. Scripts & operations

| Command | Description |
|---|---|
| `npm run dev` (in `backend/`) | `node --watch server.js` — restarts on file changes |
| `npm start` (in `backend/`) | Plain `node server.js` |
| `node rates.js` | Self-test of the currency-rate fetch |
| `npm run dev` (repo root) | Starts backend + frontend together via `concurrently` |

Operational notes:

- The API logs `Running on 5000` and, on the very first start, the seeded admin credentials.
- API errors are logged as `API error: <message>`; unhandled rejections are logged too.
- Because MongoDB is shared, test data created during development must be deleted
  (products, customers, debts, sales, expenses, inventories) before going live.
