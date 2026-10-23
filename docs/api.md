# API Reference — أبو وتين

> Complete REST reference of the Express API. Base URL in development: `http://localhost:5000`
> (the Vite dev server proxies `/api` to it).

- [1. Conventions](#1-conventions)
- [2. Authentication](#2-authentication)
- [3. Users & permissions (admin)](#3-users--permissions-admin)
- [4. Products](#4-products)
- [5. Sales](#5-sales)
- [6. Expenses](#6-expenses)
- [7. Inventory](#7-inventory)
- [8. Customers & debts](#8-customers--debts)
- [9. Cash box](#9-cash-box)
- [10. Rate](#10-rate)
- [11. Status codes & error messages](#11-status-codes--error-messages)
- [12. Quick cheat-sheet](#12-quick-cheat-sheet)

---

## 1. Conventions

| Aspect | Convention |
|---|---|
| Base path | `/api` |
| Content type | `application/json` (request and response) |
| Authentication | `Authorization: Bearer <token>` on every protected endpoint |
| Auth errors | `401` — missing/invalid/expired token; `403` — missing permission or disabled account |
| Error shape | `{ "error": "<human readable Arabic message>" }` |
| IDs | MongoDB `ObjectId` as string |
| Money | plain numbers, internal unit = SYP (ل.س) |
| Dates | ISO-8601 strings |

```bash
# every request below needs this header (except the public ones)
-H "Authorization: Bearer <TOKEN>"
```

---

## 2. Authentication

### `GET /api/auth/permissions` — public

Returns the permission catalogue used by the admin matrix.

```json
[
  { "key": "products.view", "label": "عرض الأصناف", "group": "الأصناف والمخزون" },
  { "key": "products.edit", "label": "إضافة وتعديل الأصناف والأسعار", "group": "الأصناف والمخزون" }
  // … 15 entries in total
]
```

### `POST /api/auth/login` — public

```json
// request
{ "username": "admin", "password": "admin123" }
```

```json
// 200
{
  "token": "eyJhbGciOiJIUzI1NiIs…",
  "user": {
    "_id": "6ada01d2f1233f15b316ed0b",
    "username": "admin",
    "name": "المدير",
    "role": "admin",
    "permissions": ["*"],
    "active": true,
    "createdAt": "2026-10-22T12:30:10.651Z"
  }
}
```

| Case | Status | Body |
|---|---|---|
| Missing field | 400 | `{ "error": "أدخل اسم المستخدم وكلمة المرور" }` |
| Wrong credentials | 401 | `{ "error": "اسم المستخدم أو كلمة المرور غير صحيحة" }` |
| Disabled account | 403 | `{ "error": "هذا الحساب معطّل — راجع الأدمن" }` |

### `GET /api/auth/me` — authenticated

Returns the current user in the same shape as `user` above (never `passwordHash`).

### `POST /api/auth/change-password` — authenticated

```json
// request
{ "currentPassword": "admin123", "newPassword": "newpass123" }
```

```json
// 200
{ "ok": true }
```

| Case | Status | Body |
|---|---|---|
| New password < 4 chars | 400 | `{ "error": "كلمة المرور الجديدة قصيرة جداً (4 أحرف على الأقل)" }` |
| Wrong current password | 400 | `{ "error": "كلمة المرور الحالية غير صحيحة" }` |

---

## 3. Users & permissions (admin)

All four endpoints require **role = admin** (`requireAdmin`), otherwise
`403 { "error": "هذه الصفحة للأدمن فقط" }`.

### `GET /api/users`

```json
[
  {
    "_id": "6ada01d2f1233f15b316ed0b",
    "username": "admin",
    "name": "المدير",
    "role": "admin",
    "permissions": ["*"],
    "active": true,
    "createdAt": "2026-10-22T12:30:10.651Z"
  }
]
```

### `POST /api/users`

```json
// request
{
  "username": "kassir",
  "password": "kassir123",
  "name": "كاشير المحل",
  "role": "user",
  "permissions": ["products.view", "barcodes.view", "sales.create"]
}
```

| Field | Required | Rules |
|---|---|---|
| `username` | yes | lower-cased, trimmed, unique |
| `password` | yes | ≥ 4 characters, stored with bcrypt (cost 10) |
| `name` | no | display name |
| `role` | no | `admin` \| `user` (default `user`) |
| `permissions` | no | array of known keys; empty ⇒ `DEFAULT_USER_PERMISSIONS`; role `admin` ⇒ all keys |

```json
// 201
{ "_id": "…", "username": "kassir", "name": "كاشير المحل", "role": "user",
  "permissions": ["products.view", "barcodes.view", "sales.create"], "active": true }
```

| Case | Status | Body |
|---|---|---|
| Empty username | 400 | `{ "error": "أدخل اسم المستخدم" }` |
| Password < 4 chars | 400 | `{ "error": "كلمة المرور يجب أن تكون 4 أحرف على الأقل" }` |
| Duplicate username | 400 | `{ "error": "اسم المستخدم مستخدم مسبقاً" }` |

### `PUT /api/users/:id`

```json
// request — every field is optional
{
  "name": "سارة أحمد",
  "role": "user",
  "permissions": ["products.view", "sales.create"],
  "active": true,
  "password": "newpass"
}
```

Guards: the last active admin cannot be demoted (`"لا يمكن تغيير دور آخر أدمن في النظام"`),
the last admin cannot be deactivated (`"لا يمكن تعطيل آخر أدمن"`), a password shorter than
4 characters is rejected (`"كلمة المرور قصيرة جداً"`), unknown permission keys are dropped.

### `DELETE /api/users/:id`

```json
// 200
{ "ok": true }
```

| Case | Status | Body |
|---|---|---|
| Deleting your own account | 400 | `{ "error": "لا يمكنك حذف حسابك الحالي" }` |
| Deleting the last admin | 400 | `{ "error": "لا يمكن حذف آخر أدمن" }` |

---

## 4. Products

| Method | Path | Permission |
|---|---|---|
| GET | `/api/products` | `products.view` |
| GET | `/api/products/no-barcode` | `barcodes.view` \| `products.view` |
| POST | `/api/products` | `products.edit` |
| POST | `/api/products/generate-barcodes` | `barcodes.manage` \| `products.edit` |
| POST | `/api/products/:id/sale-price` | `products.edit` |
| PUT | `/api/products/:id` | `products.edit` |
| DELETE | `/api/products/:id` | `products.edit` |

### `GET /api/products`

Optional query parameter `search` — matches the product name (case-insensitive) or the
exact barcode.

```json
[
  {
    "_id": "6ada01d2f1233f15b316ed11",
    "name": "شاي العروسة",
    "barcode": "2000000000046",
    "unit": "قطعة",
    "quantity": 12,
    "purchasePrice": 500,
    "purchaseCurrency": "SYP",
    "salePrices": [{ "price": 900, "note": "", "date": "2026-10-22T…", "_id": "…" }],
    "currentSalePrice": 900,
    "createdAt": "2026-10-22T…"
  }
]
```

### `GET /api/products/no-barcode`

Returns only the products whose barcode is **not** a valid GTIN
(`{ name, unit, barcode }`).

### `POST /api/products`

```json
// request
{
  "name": "شاي العروسة",
  "barcode": "",              // optional
  "unit": "قطعة",
  "quantity": 20,
  "purchasePrice": 500,
  "purchaseCurrency": "SYP",  // or "USD"
  "salePrice": 900            // optional
}
```

```json
// 201
{ "…product fields…", "barcodeGenerated": true }
```

- Empty or invalid barcode → a valid internal EAN-13 is generated (`20…` + check digit).
- A valid barcode is stored as typed (digits and dashes are stripped).
- Duplicate barcode → `400 { "error": "الباركود مستخدم مسبقاً" }`.

### `POST /api/products/generate-barcodes`

```json
// request — a selection …
{ "ids": ["6ada01d2f1233f15b316ed11"] }
// … or everything
{ "all": true }
```

```json
// 200
[
  { "id": "…", "name": "شاي العروسة", "barcode": "2000000000046", "generated": true },
  { "id": "…", "name": "مناديل",      "barcode": "2000000000012", "generated": false }
]
```

Products that already own a valid barcode are returned untouched with `generated: false`.

### `POST /api/products/:id/sale-price`

```json
// request
{ "price": 950, "note": "سعر جديد بعد تغيّر السوق" }
```

Appends a new price to `salePrices`; `currentSalePrice` becomes the newest entry.

### `PUT /api/products/:id` / `DELETE /api/products/:id`

Partial update (`quantity`, `salePrices`, `barcode`, …) or deletion (`{ "ok": true }`).
An invalid barcode in the body is replaced by a generated one.

---

## 5. Sales

| Method | Path | Permission |
|---|---|---|
| POST | `/api/sales` | `sales.create` |
| GET | `/api/sales/profit` | `reports.view` \| `cashbox.view` |

### `POST /api/sales`

```json
// cash sale
{ "barcode": "2000000000046", "quantity": 2 }

// sale by product name (exact match first, then a case-insensitive "contains")
{ "name": "شاي أسود", "quantity": 1 }

// sale by product id (used by the search suggestions in the UI)
{ "productId": "6ada…", "quantity": 3 }

// credit sale
{ "barcode": "2000000000046", "quantity": 1, "onCredit": true, "customerId": "6ada…" }
```

The product is resolved in this order: `barcode` (trimmed) → `productId` → `name`
(exact, case-insensitive, then the most recently updated partial match).

```json
// 201
{
  "_id": "…",
  "product": "…",
  "quantity": 2,
  "salePrice": 900,
  "purchasePrice": 500,
  "purchaseCurrency": "SYP",
  "usdRate": 14150,
  "onCredit": false,
  "totalSYP": 1800,
  "profitPerUnitSYP": 400,
  "totalProfitSYP": 800,
  "date": "2026-10-22T…"
}
```

| Case | Status | Body |
|---|---|---|
| Unknown product | 404 | `{ "error": "المنتج غير موجود" }` |
| Not enough stock | 400 | `{ "error": "الكمية غير كافية (المتاح: 3)" }` |
| Credit sale without customer | 400 | `{ "error": "اختر الشخص صاحب الدين" }` |
| Product without a sale price | 400 | `{ "error": "لا يوجد سعر بيع للمنتج" }` |

Side effects: `product.quantity` is decremented; for a credit sale a `Debt`
(`type:'debit'`, `source:'sale'`, `amount = salePrice × quantity`) is created.

### `GET /api/sales/profit`

```json
{ "totalProfitSYP": 125000, "salesCount": 42 }
```

---

## 6. Expenses

| Method | Path | Permission |
|---|---|---|
| GET | `/api/expenses` | `expenses.view` |
| POST | `/api/expenses` | `expenses.edit` |
| DELETE | `/api/expenses/:id` | `expenses.edit` |
| GET | `/api/expenses/total` | `expenses.view` \| `reports.view` |

```json
// POST request
{ "title": "إيجار المحل", "amount": 50000, "currency": "SYP", "note": "شهري" }
// 201 → { "_id": "…", "title": "إيجار المحل", "amount": 50000, "currency": "SYP", "date": "…", "note": "شهري" }
```

`GET /api/expenses/total` → `{ "totalSYP": 120000 }` (USD converted with the current rate).

---

## 7. Inventory

| Method | Path | Permission |
|---|---|---|
| GET | `/api/inventory/sheet` | `inventory.view` |
| GET | `/api/inventory` | `inventory.view` |
| POST | `/api/inventory` | `inventory.edit` |

### `GET /api/inventory/sheet`

```json
[{ "_id": "…", "name": "شاي العروسة", "unit": "قطعة", "quantity": 12, "barcode": "2000000000046" }]
```

### `POST /api/inventory`

```json
// request
{ "items": [{ "productId": "…", "actualQty": 11 }], "note": "جرد نهاية اليوم" }
```

```json
// 201
{
  "_id": "…",
  "items": [{ "product": "…", "name": "شاي العروسة", "recordedQty": 12, "actualQty": 11 }],
  "note": "جرد نهاية اليوم",
  "date": "…"
}
```

`product.quantity` is **overwritten** with `actualQty`; `recordedQty` keeps the old value
so the difference stays visible in the history.

---

## 8. Customers & debts

| Method | Path | Permission |
|---|---|---|
| GET | `/api/customers` | `debts.view` |
| GET | `/api/customers/:id` | `debts.view` |
| POST | `/api/customers` | `debts.edit` |
| PUT | `/api/customers/:id` | `debts.edit` |
| DELETE | `/api/customers/:id` | `debts.edit` |
| POST | `/api/customers/:id/debt` | `debts.edit` |
| DELETE | `/api/customers/:customerId/debt/:debtId` | `debts.edit` |

### `GET /api/customers`

```json
[
  { "_id": "…", "name": "أبو محمد", "phone": "", "note": "", "initialBalance": 5000,
    "balance": 6500, "createdAt": "…" }
]
```

`balance` = `initialBalance + Σdebit − Σcredit`.

### `GET /api/customers/:id`

```json
{
  "_id": "…", "name": "أبو محمد", "phone": "", "note": "", "initialBalance": 5000,
  "balance": 6500,
  "movements": [
    { "_id": "…", "type": "debit", "amount": 2000, "note": "بيع على الحساب — شاي",
      "source": "sale", "sale": "…", "date": "…" }
  ]
}
```

404 → `{ "error": "الشخص غير موجود" }`.

### `POST /api/customers`

```json
// request
{ "name": "أبو محمد", "phone": "", "note": "", "initialBalance": 5000 }
// 201 → { "_id": "…", "name": "أبو محمد", …, "balance": 5000 }
```

### `POST /api/customers/:id/debt`

```json
// request
{ "type": "debit", "amount": 2000, "note": "دين جديد" }   // or "credit" for a repayment
// 201 → { "_id": "…", "type": "debit", "amount": 2000, "source": "manual", "customer": { …, "balance": 7000 } }
```

Amount ≤ 0 → `400 { "error": "أدخل مبلغاً أكبر من صفر" }`.

### `DELETE /api/customers/:id`

Deletes the person **and every movement of that person** → `{ "ok": true }`.

---

## 9. Cash box

| Method | Path | Permission |
|---|---|---|
| GET | `/api/cashbox` | `cashbox.view` |
| PUT | `/api/cashbox` | `cashbox.edit` |

### `GET /api/cashbox`

```json
{
  "initialBalance": 250000,
  "salesCash": 450000,
  "salesCredit": 120000,
  "salesProfit": 90000,
  "expensesTotal": 120000,
  "current": 580000,
  "netProfit": -30000,
  "debtsTotal": 350000,
  "salesCount": 42
}
```

- `current` = `initialBalance + salesCash − expensesTotal`
- `netProfit` = `salesProfit − expensesTotal`
- `debtsTotal` = `Σ customer.initialBalance + Σdebit − Σcredit`

### `PUT /api/cashbox`

```json
// request
{ "initialBalance": 250000 }
// 200 → the same summary object as GET
```

Upserts the single `main` document; the value is the money that was in the drawer before
the app started counting.

---

## 10. Rate

### `GET /api/rate` — public

```json
{ "usdToSYP": 14150, "source": "api" }
```

`source` is `not-configured` when no currency API is configured.

---

## 11. Status codes & error messages

| Status | Meaning | Typical messages |
|---|---|---|
| 200 / 201 | Success | — |
| 400 | Bad input | `أدخل اسم المستخدم وكلمة المرور` · `كلمة المرور يجب أن تكون 4 أحرف على الأقل` · `اسم المستخدم مستخدم مسبقاً` · `الباركود مستخدم مسبقاً` · `اختر الشخص صاحب الدين` · `الكمية غير كافية (المتاح: N)` · `لا يوجد سعر بيع للمنتج` · `أدخل مبلغاً أكبر من صفر` · `لا يمكنك حذف حسابك الحالي` · `لا يمكن حذف آخر أدمن` · `لا يمكن تعطيل آخر أدمن` · `لا يمكن تغيير دور آخر أدمن في النظام` |
| 401 | Not authenticated | `يجب تسجيل الدخول` · `جلسة غير صالحة — سجّل الدخول من جديد` · `اسم المستخدم أو كلمة المرور غير صحيحة` · `هذا الحساب معطّل — راجع الأدمن` |
| 403 | Missing permission | `لا تملك صلاحية لهذا الإجراء` · `هذه الصفحة للأدمن فقط` |
| 404 | Not found | `المسار غير موجود` · `المنتج غير موجود` · `الشخص غير موجود` · `المستخدم غير موجود` |
| 500 | Server error | `خطأ في الخادم` |

---

## 12. Quick cheat-sheet

```bash
BASE=http://localhost:5000/api

# 1) login
TOKEN=$(curl -s -X POST $BASE/auth/login -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | jq -r .token)

AUTH="Authorization: Bearer $TOKEN"

# 2) read
curl -s $BASE/products           -H "$AUTH"
curl -s $BASE/customers          -H "$AUTH"
curl -s $BASE/cashbox            -H "$AUTH"
curl -s $BASE/inventory/sheet    -H "$AUTH"
curl -s $BASE/users              -H "$AUTH"       # admin only

# 3) write
curl -s -X POST $BASE/products -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"شاي","quantity":10,"purchasePrice":500,"salePrice":900}'

curl -s -X POST $BASE/sales -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"barcode":"2000000000046","quantity":1}'

curl -s -X POST $BASE/users -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"username":"kassir","password":"kassir123","name":"كاشير","role":"user",
       "permissions":["products.view","sales.create"]}'
```

> On PowerShell use `--data-binary "@file.json"` (UTF-8 **without** BOM) instead of `-d`.
