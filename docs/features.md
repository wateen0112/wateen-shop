# Features Guide — أبو وتين

> Every feature of the app from the shop owner's point of view: what it does, how to use
> it, which permission it needs, and where it lives in the code.

- [1. Feature map](#1-feature-map)
- [2. Authentication & accounts](#2-authentication--accounts)
- [3. Catalogue (الأصناف)](#3-catalogue-الأصناف)
- [4. Barcodes](#4-barcodes)
- [5. Selling](#5-selling)
- [6. Debts (الديون)](#6-debts-الديون)
- [7. Expenses](#7-expenses)
- [8. Cash box & profit (الصندوق)](#8-cash-box--profit-الصندوق)
- [9. Inventory (الجرد)](#9-inventory-الجرد)
- [10. Currency rate](#10-currency-rate)
- [11. Reports & data](#11-reports--data)

---

## 1. Feature map

| # | Feature | Page | Permissions | API |
|---|---|---|---|---|
| 1 | Login / logout / change password | `Login`, `AccountSheet` | — | `/api/auth/*` |
| 2 | Multi-user accounts with granular permissions | `Users` | admin | `/api/users` |
| 3 | Product catalogue (add / edit / delete / search) | `Products` | `products.view`, `products.edit` | `/api/products` |
| 4 | Price history per product | `Products` | `products.edit` | `POST /api/products/:id/sale-price` |
| 5 | Automatic barcode generation | `Products`, `Barcodes` | `barcodes.manage` | `POST /api/products/generate-barcodes` |
| 6 | Barcode label PDF grid | `Barcodes` | `barcodes.view`, `barcodes.manage` | same |
| 7 | Camera barcode scanning | `Products`, `Sell` | `products.view`, `sales.create` | local (zxing) |
| 8 | Quick selling with instant profit | `Sell` | `sales.create` | `POST /api/sales` |
| 9 | Credit sales (sale on account) | `Sell` | `sales.create` + `debts.view` | `POST /api/sales` → auto `Debt` |
| 10 | Customer directory & statements | `Debts` | `debts.view`, `debts.edit` | `/api/customers` |
| 11 | Debt movements (new debt / repayment) | `Debts` | `debts.edit` | `POST /api/customers/:id/debt` |
| 12 | Expenses | `Expenses` | `expenses.view`, `expenses.edit` | `/api/expenses` |
| 13 | Cash box balance & net profit | `Profit` | `cashbox.view`, `cashbox.edit` | `/api/cashbox` |
| 14 | Inventory count with difference history | `Inventory` | `inventory.view`, `inventory.edit` | `/api/inventory` |
| 15 | Live USD → SYP rate | app bar | public | `GET /api/rate` |

---

## 2. Authentication & accounts

**What it does** — every request is authenticated with a JWT; every screen and endpoint is
gated by a permission; the admin manages the accounts.

**How to use it**

1. Open the app → the login screen appears.
2. Enter اسم المستخدم + كلمة المرور → «تسجيل الدخول».
3. The bottom tab bar shows only the pages your account may open.
4. 👤 → «حسابي» shows your permissions, lets you change your password and log out.
5. 👤 → «إدارة المستخدمين والصلاحيات» (admins) to create staff accounts.

**Behaviour details**

- Wrong credentials → `اسم المستخدم أو كلمة المرور غير صحيحة`.
- A disabled account → `هذا الحساب معطّل — راجع الأدمن`.
- An expired/invalid session → the app returns to the login screen automatically.
- The first ever start creates the admin account from `ADMIN_USERNAME` / `ADMIN_PASSWORD`.

**Where**: `frontend/src/pages/Login.jsx`, `frontend/src/pages/Users.jsx`,
`frontend/src/context/AuthContext.jsx`, `backend/routes/auth.js`, `backend/routes/users.js`.

---

## 3. Catalogue (الأصناف)

**What it does** — the product master data: name, unit, stock quantity, purchase price and
currency, and a history of sale prices.

**How to use it**

1. **Add** — «صنف جديد»: fill the name, scan or type the barcode (leave it empty to get an
   internal barcode), set the unit, the quantity, the purchase price/currency and
   optionally the first sale price → «إضافة الصنف».
   If a barcode was generated, a card with a printable preview appears.
2. **Search** — the search bar matches the name or the barcode; the camera button fills
   the search field with a scanned code.
3. **Correct the stock** — the quantity field + «حفظ» on the product card.
4. **New price** — the «سعر بيع جديد» field + «إضافة»; the previous price is kept in the
   history, the newest one becomes the active price.
5. **Delete** — «حذف الصنف» (requires `products.edit`).

**Behaviour details**

- A barcode that fails the GTIN check is replaced by a generated one and a warning is
  shown while typing.
- USD purchases display the converted SYP price next to the original price.
- A product without any sale price cannot be sold (`لا يوجد سعر بيع للمنتج`).

**Where**: `frontend/src/pages/Products.jsx`, `backend/routes/products.js`.

---

## 4. Barcodes

**What it does** — makes sure every product has a scannable code and prints label sheets.

**How to use it**

1. Open «الباركود».
2. **أصناف بدون باركود صالح** — tick the products that need a code.
   - «توليد تلقائي لكل الأصناف بلا باركود صالح» fixes them all at once (`barcodes.manage`).
3. **إعادة طباعة باركودات** — tick products that already have a code to print them again.
4. «توليد وطباعة PDF (N)» → the browser downloads `barcodes.pdf`.

**Behaviour details**

- PDF layout: A4 portrait, 3 columns × 8 rows per page, product name above each barcode.
- Barcode symbology: `EAN13` for 13 digits, `EAN8` for 8, `ITF14` for 14, `CODE128`
  otherwise.
- Internally generated codes use the reserved `20…` range so they never collide with real
  EAN-13 codes.

**Where**: `frontend/src/pages/Barcodes.jsx`, `frontend/src/components/BarcodePreview.jsx`,
`backend/barcode.js`, `backend/routes/products.js`.

---

## 5. Selling

**What it does** — records a sale by barcode **or by product name** in one step and shows
the profit instantly.

**How to use it**

1. Open «بيع».
2. Tap the big «مسح باركود بالكاميرا» button and point the camera at the code.
3. Or type in «الباركود أو اسم الصنف»: matching products appear live (name, barcode, unit,
   price, available stock). Pick one with a click/tap — or with ↑/↓ + Enter — to sell it.
4. Pressing Enter on typed text sells it even without picking a suggestion: the server
   looks the text up as a barcode first, then as a product name.
5. Adjust the quantity with `−` / `+`.
6. «بيع تلقائي بعد المسح» — a scan completes the sale immediately (default: on).
7. To sell on account: enable «بيع على الحساب (دين لشخص)» and pick the person
   (or create one inline) → the sale value is added to that person's debt.
8. «تأكيد البيع» for a manual entry.

**Behaviour details**

- Not enough stock → `الكمية غير كافية (المتاح: N)`.
- Name lookup: exact (case-insensitive) match wins, otherwise the most recently updated
  product whose name contains the text; unknown text → `المنتج غير موجود`.
- Products without a barcode can be sold purely by name — no barcode required.
- The session log at the bottom lists every sale of the current session with its profit
  (or the «دين» chip for credit sales).
- The stock of the product is decremented immediately.
- Credit sales never enter the cash box — they become receivables.

**Where**: `frontend/src/pages/Sell.jsx`, `frontend/src/components/BarcodeScanner.jsx`,
`backend/routes/sales.js`.

---

## 6. Debts (الديون)

**What it does** — keeps track of who owes the shop, with a full statement per person.

**How to use it**

1. Open «الديون» → the total outstanding is shown at the top.
2. «＋ شخص جديد» → name, phone and an optional opening balance (debt from before the app
   was used) → «حفظ الشخص».
3. Tap a person → the sheet opens with the current balance and the statement.
4. Choose «دين جديد» or «تسديد», enter the amount and an optional note → save.
5. Each movement can be deleted individually; the person can be deleted entirely
   (which removes all their movements).

**Behaviour details**

```
balance = opening balance + Σ(new debts) − Σ(repayments)
```
- The statement lists every movement with its date and note.
- A person with a zero balance is marked «مسدَّد».
- A credit sale from the selling screen appears here as a movement with the note
  «بيع على الحساب — <product>».

**Where**: `frontend/src/pages/Debts.jsx`, `frontend/src/components/CustomerSelect.jsx`,
`backend/routes/customers.js`, `backend/models/Debt.js`.

---

## 7. Expenses

**What it does** — records the shop's outgoing money (rent, transport, salaries…).

**How to use it**

1. Open «المصروفات».
2. «تسجيل مصروف» → البيان, المبلغ, العملة (ليرة/دولار), optional note →
   «تسجيل المصروف».
3. The list below shows every expense; the delete button removes one.

**Behaviour details**

- USD expenses are converted with the current rate when the cash box is summarised.
- The total is subtracted from the cash box and from the net profit.

**Where**: `frontend/src/pages/Expenses.jsx`, `backend/routes/expenses.js`.

---

## 8. Cash box & profit (الصندوق)

**What it does** — one screen that answers "how much money is in the drawer and did we
make a profit?".

**How to use it**

1. Open «الصندوق».
2. The main KPI card shows the current balance; if the opening balance was never set,
   enter it once in «الرصيد الابتدائي للصندوق» → «حفظ» (`cashbox.edit`).
3. «حركة الصندوق» breaks the movement down: cash sales, expenses, credit sales and the
   net profit.
4. «الديون القائمة» shows the receivables with a link to the debts page.

**Behaviour details**

```
current   = opening balance + cash sales − expenses
netProfit = sales profit   − expenses
```
- Credit sales are shown separately — they are not cash in the drawer.
- A negative balance turns the KPI card red.

**Where**: `frontend/src/pages/Profit.jsx`, `backend/routes/cashbox.js`.

---

## 9. Inventory (الجرد)

**What it does** — counts the real stock and corrects the system quantities.

**How to use it**

1. Open «الجرد».
2. Type the counted quantity next to each product; the difference appears instantly
   (`+2`, `−1`, `0`).
3. «حفظ الجرد وتحديث الكميات» → confirmation → the product quantities are updated and the
   count is archived.
4. «عرض سجل الجردات السابقة» shows every past count with its differences.

**Behaviour details**

- Each snapshot keeps `recordedQty` (before) and `actualQty` (counted) for every item.
- Only products with a filled input are saved.
- The history is read-only.

**Where**: `frontend/src/pages/Inventory.jsx`, `backend/routes/inventory.js`,
`backend/models/Inventory.js`.

---

## 10. Currency rate

**What it does** — converts USD purchase prices into SYP and keeps the profit accurate.

**How to use it** — nothing to do: the rate chip in the app bar shows the current rate and
refreshes every 5 minutes.

**Behaviour details**

- Source: the sp-today compatible API configured in `CURRENCY_API_URL` (+ `CURRENCY_API_KEY`,
  `CURRENCY_CITY`, default `damascus`), using the `sell` price.
- Cached for 10 minutes on the server; if the API fails the last known value is reused.
- Without an API the chip shows «الدولار غير مضبوط» and the selling screen warns that the
  profit of USD purchases is inaccurate.

**Where**: `backend/rates.js`, `backend/routes/rates.js`, `frontend/src/App.jsx`.

---

## 11. Reports & data

**What the app can answer**

| Question | Where |
|---|---|
| How much money is in the drawer? | الصندوق → رصيد الصندوق الحالي |
| What is the net profit? | الصندوق → الربح الصافي |
| How much do people owe me? | الديون → إجمالي الديون القائمة / الصندوق → الديون القائمة |
| What did I sell today and for how much? | بيع → مبيعات هذه الجلسة (per session) / `/api/sales/profit` (all time) |
| Where did the money go? | المصروفات → سجل المصروفات |
| Is the stock correct? | الجرد → الفروقات |
| How much did I sell a product for? | الأصناف → سعر البيع (history via `salePrices`) |
| Who can do what? | إدارة المستخدمين → عدّاد الصلاحيات لكل مستخدم |

**Data portability** — the API is the stable contract: every screen maps 1:1 to documented
endpoints (see [`api.md`](./api.md)), so reports can be pulled with `curl` or any client.

**Data hygiene** — the MongoDB database is shared between environments. Delete test
records (products, sales, expenses, customers, debts, inventories) before going live.
