# Frontend Guide — أبو وتين

> Page-by-page and component-by-component reference of the React application.
> Arabic RTL, mobile-first, permission-aware UI.

- [1. App shell (`App.jsx`)](#1-app-shell-appjsx)
- [2. Routing & guards](#2-routing--guards)
- [3. Authentication state](#3-authentication-state)
- [4. API layer (`api.js`)](#4-api-layer-apijs)
- [5. Pages](#5-pages)
- [6. Components](#6-components)
- [7. Libraries (`src/lib`)](#7-libraries-srclib)
- [8. Design system (`styles.css`)](#8-design-system-stylescss)
- [9. Build, preview, deployment](#9-build-preview-deployment)

---

## 1. App shell (`App.jsx`)

```
<BrowserRouter>
  <AuthProvider>            ← session state
    <Shell />                ← the whole UI once a session exists
```

`Shell` renders one of three states:

| State | Rendering |
|---|---|
| `booting === true` | Login-shaped loading card (`جارٍ التحميل...`) while `/auth/me` is validated |
| `user === null` | `<Login />` |
| otherwise | The application shell |

### Shell structure

```
┌──────────────────────────────────────┐
│ appbar  [logo] أبو وتين | $ chip | 👤 │   ← account button opens AccountSheet
├──────────────────────────────────────┤
│ app-main  → <Routes>…</Routes>        │
├──────────────────────────────────────┤
│ tabbar   الأصناف بيع الباركود …        │   ← bottom navigation, filtered by permission
└──────────────────────────────────────┘
```

- **Rate chip** — `GET /api/rate` on mount and every 5 minutes; shows
  `الدولار ١٤٬١٥٠ ل.س` or `الدولار غير مضبوط` when the API is unavailable.
- **Permission catalog** — `GET /api/auth/permissions` on mount, used by the admin matrix
  and by the account sheet to label the current user's permissions.
- **Tab bar** — only the tabs whose permission the user owns are rendered.

### `AccountSheet` (the "حسابي" panel)

Opens from the 👤 button in the app bar. Contains:

1. **Identity** — display name, `username`, role (أدمن / مستخدم).
2. **إدارة المستخدمين والصلاحيات** button — admins only, navigates to `/users`.
3. **صلاحياتك** — the user's permissions as chips (admins see all non-admin keys).
4. **تغيير كلمة المرور** — a collapsible `<details>` block with the current and the new
   password; the new password must be ≥ 4 characters.
5. **تسجيل الخروج** — clears the session and returns to the login screen.

---

## 2. Routing & guards

| Route | Page | Required permission |
|---|---|---|
| `/` | `Products` | `products.view` |
| `/sell` | `Sell` | `sales.create` |
| `/barcodes` | `Barcodes` | `barcodes.view` |
| `/expenses` | `Expenses` | `expenses.view` |
| `/profit` | `Profit` (الصندوق) | `cashbox.view` |
| `/debts` | `Debts` | `debts.view` |
| `/inventory` | `Inventory` | `inventory.view` |
| `/users` | `Users` | role `admin` only |
| `*` | redirects to `Products` | `products.view` |

Two components implement the guard:

- `<Guard perm="…">` — wraps a route; renders the page or `<NoAccess>`.
- `<NoAccess perm="…">` — the "لا تملك صلاحية الوصول" screen showing the missing
  permission key and a hint to ask the admin.

Direct navigation to a forbidden URL therefore shows the guard screen, not the page.

---

## 3. Authentication state

### `src/lib/auth.js`

| Function | Behaviour |
|---|---|
| `getToken()` | `localStorage.getItem('wateen_token')` |
| `getStoredUser()` | parses `localStorage.getItem('wateen_user')`, `null` on error |
| `setSession(token, user)` | writes both keys |
| `clearSession()` | removes both keys |
| `hasPermission(user, key)` | `true` for admins, otherwise `user.permissions.includes(key)` |

### `src/context/AuthContext.jsx`

```js
const { user, booting, login, logout, refresh, can, isAdmin } = useAuth();
```

| Member | Meaning |
|---|---|
| `user` | the logged-in user (or `null`) |
| `booting` | `true` while the stored session is being revalidated |
| `login(username, password)` | calls the API, stores the session, sets the user |
| `logout()` | clears the session and the user |
| `refresh()` | re-fetches `/auth/me` (used after the admin edits their own account) |
| `can(key)` | permission check — `true` for admins |
| `isAdmin` | `user.role === 'admin'` |

Boot sequence: if a token exists → `GET /auth/me` → on success refresh the stored user,
on failure clear the session. A global listener on the `wateen:unauthorized` window event
sets `user = null` whenever the axios interceptor sees a `401` (expired session → the user
is returned to the login screen automatically).

---

## 4. API layer (`api.js`)

One axios instance: `baseURL = import.meta.env.VITE_API_URL || '/api'`.

**Request interceptor** — attaches `Authorization: Bearer <token>` when a token exists.

**Response interceptor** — on `401`: clears the session, dispatches
`window.dispatchEvent(new Event('wateen:unauthorized'))`, and rejects the promise.

Every screen talks to the API exclusively through these helpers:

| Group | Functions |
|---|---|
| Auth | `login`, `getMe`, `getPermissionCatalog`, `changePassword` |
| Users | `getUsers`, `addUser`, `updateUser`, `deleteUser` |
| Products | `getProducts`, `addProduct`, `updateProduct`, `deleteProduct`, `addSalePrice`, `getNoBarcode`, `generateBarcodes`, `generateMissingBarcodes` |
| Sales | `makeSale`, `getProfit` |
| Customers / debts | `getCustomers`, `getCustomer`, `addCustomer`, `updateCustomer`, `deleteCustomer`, `addDebt`, `deleteDebt` |
| Cash box | `getCashbox`, `setCashboxInitial` |
| Expenses | `getExpenses`, `addExpense`, `deleteExpense`, `getExpensesTotal` |
| Inventory | `getInventorySheet`, `saveInventory`, `getInventories` |
| Rate | `getRate` |

Error handling in the UI is uniform: `err.response?.data?.error` is displayed inside a
`.msg.error` box (or falls back to a generic Arabic message).

---

## 5. Pages

### 5.1 `Login` — `/` (when logged out)

- Card with the shop logo, the title «أبو وتين» and the hint
  «اطلب من الأدمن إنشاء حساب لك وتحديد صلاحياتك».
- Fields: اسم المستخدم (auto-capitalize off), كلمة المرور (masked).
- Errors are rendered inline (`اسم المستخدم أو كلمة المرور غير صحيحة` …).
- On success the shell replaces the login screen automatically.

### 5.2 `Products` — `/` (الأصناف) — `products.view`

| Block | Visibility | Description |
|---|---|---|
| «صنف جديد» form | `products.edit` | Name, barcode (manual or camera), unit, quantity, purchase price, purchase currency (SYP/USD), sale price |
| Barcode preview | always | Live SVG of the typed/scanned code (`BarcodePreview`) |
| «تم توليد باركود تلقائي» card | `products.edit` | Shown after adding a product that received a generated code |
| Search bar | always | Search by name or barcode, with a camera button that fills the search field |
| Product card | always | Name, barcode (or a «بدون باركود» / «باركود غير صالح» pill), unit, quantity badge, purchase price, current sale price, and — for USD purchases — the converted SYP price |
| Quantity editor | `products.edit` | Inline number input + «حفظ» → `updateProduct` |
| New sale price | `products.edit` | Inline input + «إضافة» → `addSalePrice` (appends to the price history) |
| «توليد باركود لهذا الصنف» | `barcodes.manage` | Only shown when the barcode is invalid |
| «حذف الصنف» | `products.edit` | Deletes the product |

The camera button opens the `BarcodeScanner` overlay in two modes: `form` (fills the
barcode field) and `search` (runs the search).

### 5.3 `Sell` — `/sell` (بيع) — `sales.create`

- Big «مسح باركود بالكاميرا» button → camera overlay.
- One search field accepts **either a barcode or a product name**. Typing (≥1 char,
  debounced ~220 ms) queries `GET /api/products?search=…` (requires `products.view`) and
  shows up to 8 suggestions with name, barcode, unit, price and available quantity;
  clicking one sells it by `productId`. Arrow keys / Enter pick the highlighted row.
- If no suggestion is picked, Enter sells the typed text: the server tries it as a
  barcode first, then as a name (see `POST /api/sales`). Quantity stepper (`−` / `+`).
- «بيع تلقائي بعد المسح» switch — a scan immediately performs the sale.
- «بيع على الحساب (دين لشخص)» switch — **only with `debts.view`** — reveals a
  `CustomerSelect` (choose an existing person or create one inline, creating requires
  `debts.edit`).
- Warning banner when the USD rate is unavailable (profit of USD purchases would be wrong).
- After each sale: a success message with the profit, and a session log
  («مبيعات هذه الجلسة») listing price, quantity, time and profit — or the «دين» chip for
  credit sales.

### 5.4 `Barcodes` — `/barcodes` (الباركود) — `barcodes.view`

Two sections built by the same `Section` component:

1. **أصناف بدون باركود صالح** — items whose barcode is not a valid GTIN. Selecting them
   and printing generates the missing codes first (requires `barcodes.manage`).
2. **إعادة طباعة باركودات** — all products with a valid barcode, printable again.

Buttons:

- «توليد تلقائي لكل الأصناف بلا باركود صالح» — bulk generation, **`barcodes.manage` only**.
- «توليد وطباعة PDF (N)» — disabled when nothing is selected; for the first section it is
  also disabled without `barcodes.manage` (it must generate first).

The PDF is an A4 label grid: **3 columns × 8 rows**, 65 × 33 mm cells, each cell shows the
product name (truncated to 28 characters) above a rendered barcode image.

### 5.5 `Expenses` — `/expenses` (المصروفات) — `expenses.view`

- «تسجيل مصروف» form (`expenses.edit`): البيان, المبلغ, العملة (SYP/USD), ملاحظة.
- «سجل المصروفات» list (always): title, date, note, amount + currency, and a delete button
  for `expenses.edit`.

### 5.6 `Profit` (الصندوق) — `/profit` — `cashbox.view`

Three cards:

1. **الصندوق** — the current balance as a KPI card
   (`رصيد ابتدائي + مبيعات − مصروفات`); turns red when negative. The initial-balance
   editor is shown with `cashbox.edit`.
2. **حركة الصندوق** — مبيعات نقدية, المصروفات, مبيعات على الحساب, الربح الصافي.
3. **الديون القائمة** — the total receivables + a link to the debts page.

### 5.7 `Debts` — `/debts` (الديون) — `debts.view`

- «إجمالي الديون القائمة» KPI.
- «＋ شخص جديد» form (`debts.edit`): name, phone, opening balance, note.
- Search by name or phone.
- Person list: name, phone, balance (`عليه N ل.س` or the «مسدَّد» chip).
- Opening a person opens a bottom sheet with:
  - the current balance and the opening balance note,
  - a segmented control **دين جديد / تسديد** plus amount and note (`debts.edit`),
  - «كشف الحساب» — the movement history with delete buttons (`debts.edit`),
  - «حذف الشخص» (deletes the person and all movements, with a confirmation).

### 5.8 `Inventory` — `/inventory` (الجرد) — `inventory.view`

- A sheet with one row per product: name, recorded quantity, an input for the actual
  quantity (disabled without `inventory.edit`) and the difference chip.
- «حفظ الجرد وتحديث الكميات» (`inventory.edit`) — confirms, then overwrites the product
  quantities and stores the snapshot.
- «عرض سجل الجردات السابقة» — collapsible history, each entry shows the recorded vs the
  actual quantity and the difference.

### 5.9 `Users` — `/users` (إدارة المستخدمين) — admin only

Two parts:

1. **«مستخدم جديد» form**
   - اسم المستخدم, كلمة المرور (≥ 4 chars), الاسم الكامل, الدور (مستخدم / أدمن).
   - When the role is `user`, the **permission matrix** appears, grouped by
     «الأصناف والمخزون / المبيعات / الديون والمالية / التقارير والإدارة»
     (15 checkboxes in 4 groups).
   - Switching the role to `admin` clears the list; switching back restores the default set.
2. **«المستخدمون» list** — a card per user: display name, username pill, role pill,
   a permission-count pill («كل الصلاحيات» for admins), a «معطّل» pill when disabled,
   an «تعديل» button and a «حذف المستخدم» button (hidden for your own account).

The **edit sheet** allows changing the full name, the role, the enabled state
(«الحساب مفعّل»), an optional new password and the permission matrix.

---

## 6. Components

### `components/Icons.jsx`

Inline SVG icon components (no icon library): `BoxIcon`, `SellIcon`, `BarcodeIcon`,
`WalletIcon`, `ChartIcon`, `ClipboardIcon`, `CameraIcon`, `SearchIcon`, `TrashIcon`,
`StoreIcon`, `PrintIcon`, `CloseIcon`, `WandIcon`, `UsersIcon`, `CashboxIcon`,
`ShieldIcon`, `CheckIcon`, `LogoutIcon`, `UserIcon`.

### `components/BarcodePreview.jsx`

Renders a live barcode SVG with `jsbarcode` for the current value.
Props: `value`, `height = 64`. Shows a placeholder when empty and an error placeholder
when the code cannot be rendered.

### `components/BarcodeScanner.jsx`

Full-screen camera overlay built on `@zxing/browser`:

- `decodeFromVideoDevice(undefined, video, cb)` — the default (rear) camera.
- The first successful decode stops the reader, vibrates the device (`navigator.vibrate(60)`)
  and calls `onDetected(text)`.
- Error messages: browser without camera support, `NotAllowedError` (permission denied),
  `NotFoundError` (no camera), and a generic failure message.
- Cleanup on unmount stops the controls and the media tracks.

### `components/CustomerSelect.jsx`

A `<select>` of customers with the balance in the option label, plus:

- «＋ شخص جديد» — inline creation form (name, phone, opening balance). The button is
  disabled without `debts.edit`.
- A hint showing the selected customer's outstanding balance.

---

## 7. Libraries (`src/lib`)

### `lib/auth.js` — session storage and `hasPermission()` (see §3).

### `lib/barcode.js` — the client-side mirror of `backend/barcode.js`:

`normalizeBarcode`, `gtinCheckDigit`, `isValidBarcode`, `barcodeFormat`
(`EAN13` / `EAN8` / `ITF14` / `CODE128`).

Keep both copies in sync — the backend decides validity, the frontend decides how to draw it.

---

## 8. Design system (`styles.css`)

~820 lines of hand-written CSS with CSS custom properties:

| Token | Value | Usage |
|---|---|---|
| `--primary` | teal `#0f766e` | brand, active tab, primary button |
| `--primary-600` / `--primary-soft` | teal shades | borders, soft chips |
| `--danger` / `--success` / `--muted` / `--line` | — | states, secondary text, borders |

Layout: `.app` is a flex column with the app bar on top, `.app-main` scrolling in the
middle and the `.tabbar` fixed at the bottom (safe-area aware). Cards use `.card`,
`.card-head`, `.form`, `.field`, `.form-grid`, `.btn` (primary/secondary/danger, `sm`/`block`),
`.msg` (error/success), `.pill`, `.empty-state`.

Feature-specific blocks: `.product-card`, `.scan-hero`, `.stepper`, `.sale-list`,
`.record-list`, `.debt-total`, `.debt-item`, `.sheet` (bottom sheet), `.kpi-card`,
`.stock-item`, `.diff`, `.select-list`, `.scanner-overlay`, `.tabbar`/`.tab`,
`.login-page`/`.login-card`, `.perm-block`/`.perm-group`/`.perm-row`/`.perm-chips`,
`.user-card`, `.account-head`, `.pw-box`.

Numbers are formatted with `Number(...).toLocaleString('ar-SY')`.

---

## 9. Build, preview, deployment

| Command | Result |
|---|---|
| `npm run dev` | Vite dev server on `https://localhost:5173` with the `/api` proxy and a self-signed certificate (`@vitejs/plugin-basic-ssl`) |
| `npm run build` | Production bundle in `frontend/dist` |
| `npm run preview` | Serves `dist` on `https://localhost:4173` **with the same `/api` proxy** |

Deployment notes:

- The camera needs a secure context → serve the app over **HTTPS** (the dev server
  already does) or access it through `localhost`.
- `server.host: true` in `vite.config.js` makes the dev server reachable from other
  devices on the LAN (`https://<LAN-IP>:5173` — the certificate is self-signed, so the
  browser will ask to continue).
- For production, either put a reverse proxy (nginx/Caddy) in front of `dist` and
  forward `/api` to the backend, or set `VITE_API_URL` to the absolute API URL at build time.
- The router uses `BrowserRouter` → the web server must fall back to `index.html` for
  unknown paths.
