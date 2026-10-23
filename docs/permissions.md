# Permissions & User Management

> How the permission system works end to end: catalogue, enforcement points, the admin
> matrix, user lifecycle rules and a security checklist.

- [1. Model](#1-model)
- [2. The 15 permissions](#2-the-15-permissions)
- [3. Enforcement points](#3-enforcement-points)
- [4. Permission → feature matrix](#4-permission--feature-matrix)
- [5. Roles](#5-roles)
- [6. User lifecycle rules](#6-user-lifecycle-rules)
- [7. Default permissions](#7-default-permissions)
- [8. The admin UI](#8-the-admin-ui)
- [9. Security checklist](#9-security-checklist)

---

## 1. Model

```
User { username, passwordHash, name, role: 'admin'|'user', permissions: string[], active }
```

- A permission is a **string key** from `backend/permissions.js`.
- The array on the user document is the source of truth; nothing about permissions is
  stored in the JWT.
- Every request re-reads the user from MongoDB → permission changes apply immediately,
  even to sessions that are already open.

---

## 2. The 15 permissions

| Group | Key | Label (Arabic, as shown in the UI) |
|---|---|---|
| الأصناف والمخزون | `products.view` | عرض الأصناف |
| | `products.edit` | إضافة وتعديل الأصناف والأسعار |
| | `barcodes.view` | عرض الباركودات |
| | `barcodes.manage` | توليد وطباعة الباركودات |
| | `inventory.view` | عرض الجرد |
| | `inventory.edit` | تنفيذ الجرد |
| المبيعات | `sales.create` | إجراء عمليات البيع |
| الديون والمالية | `debts.view` | عرض الديون |
| | `debts.edit` | إدارة الديون والأشخاص |
| | `expenses.view` | عرض المصروفات |
| | `expenses.edit` | إضافة وتعديل المصروفات |
| | `cashbox.view` | عرض الصندوق |
| | `cashbox.edit` | تعديل رصيد الصندوق |
| التقارير والإدارة | `reports.view` | عرض الأرباح والملخصات |
| | `users.manage` | إدارة المستخدمين والصلاحيات |

The catalogue is served by `GET /api/auth/permissions` (public) so the admin UI can render
the matrix — no duplication between the backend and the frontend.

---

## 3. Enforcement points

### 3.1 Server side (`requirePerm` / `requireAdmin`)

Every business endpoint declares its required permission:

```js
router.get('/',  requirePerm('products.view'), handler);
router.post('/', requirePerm('products.edit'), handler);
router.get('/no-barcode', requirePerm('barcodes.view', 'products.view'), handler); // OR
```

| Guard | Response when it fails |
|---|---|
| `authenticate` | `401 { error: 'يجب تسجيل الدخول' }` |
| `requirePerm(...)` | `403 { error: 'لا تملك صلاحية لهذا الإجراء' }` |
| `requireAdmin` | `403 { error: 'هذه الصفحة للأدمن فقط' }` |

Admins bypass every `requirePerm` check.

### 3.2 Client side

| Technique | Where |
|---|---|
| `<Guard perm="…">` around each route | `App.jsx` |
| Tab bar filtered by permission | `App.jsx` (`TABS.filter(t => can(t.perm))`) |
| `can('…')` guards around forms/buttons | every page |
| `useAuth().can(key)` / `isAdmin` | pages and components |

> Hiding a control is **UX only**. The server check is the real security boundary — never
> rely on the frontend to protect data.

---

## 4. Permission → feature matrix

### 4.1 Pages

| Page | Route | Permission |
|---|---|---|
| الأصناف | `/` | `products.view` |
| بيع | `/sell` | `sales.create` |
| الباركود | `/barcodes` | `barcodes.view` |
| المصروفات | `/expenses` | `expenses.view` |
| الصندوق | `/profit` | `cashbox.view` |
| الديون | `/debts` | `debts.view` |
| الجرد | `/inventory` | `inventory.view` |
| إدارة المستخدمين | `/users` | admin only |

### 4.2 Individual capabilities

| Capability | Permission |
|---|---|
| See the product list | `products.view` |
| Add a product | `products.edit` |
| Edit quantity / sale price / delete a product | `products.edit` |
| Generate a barcode for one product | `barcodes.manage` |
| Bulk-generate barcodes + print the PDF grid | `barcodes.manage` |
| Re-print an existing barcode (PDF) | `barcodes.view` |
| Perform a sale | `sales.create` |
| See the cash box / profit summary | `cashbox.view` |
| Edit the opening cash-box balance | `cashbox.edit` |
| See the profit report (`/api/sales/profit`) | `reports.view` or `cashbox.view` |
| See the expense list | `expenses.view` |
| Add / delete an expense | `expenses.edit` |
| See the customer list and a statement | `debts.view` |
| Create a person, add/repay a debt, delete movements, delete a person | `debts.edit` |
| Switch a sale to «على الحساب» | `debts.view` (the person picker needs `debts.edit` to create one) |
| See the stock-take sheet | `inventory.view` |
| Save a stock-take (overwrites the quantities) | `inventory.edit` |
| Create/edit/delete users and manage permissions | admin only (`users.manage`) |

---

## 5. Roles

| Role | Behaviour |
|---|---|
| `admin` | Bypasses every permission check, sees every tab, sees the user-management page, `permissions` are reported as `['*']`. |
| `user` | Only the explicitly granted permissions apply. `permissions` is always an array of real keys. |

Changing a user from `admin` to `user` resets their permission list to the default set in
the UI (the backend keeps whatever is sent, filtered to known keys).

---

## 6. User lifecycle rules

| Action | Rule | Error message |
|---|---|---|
| Create | username required, unique, lower-cased; password ≥ 4 chars | `أدخل اسم المستخدم` · `اسم المستخدم مستخدم مسبقاً` · `كلمة المرور يجب أن تكون 4 أحرف على الأقل` |
| Change role | The last active admin cannot be demoted | `لا يمكن تغيير دور آخر أدمن في النظام` |
| Deactivate | The last active admin cannot be disabled | `لا يمكن تعطيل آخر أدمن` |
| Delete | You cannot delete your own account | `لا يمكنك حذف حسابك الحالي` |
| Delete | The last admin cannot be deleted | `لا يمكن حذف آخر أدمن` |
| Reset a password | The admin can set a new password directly in the edit sheet (≥ 4 chars) | `كلمة المرور قصيرة جداً` |
| Self-service | Every user can change their own password (`POST /api/auth/change-password`) | `كلمة المرور الحالية غير صحيحة` |

A disabled account (`active: false`) is rejected at login with `403` and at every
authenticated request with `401`.

---

## 7. Default permissions

Applied when a user is created **without** an explicit list (backend) and when a role is
switched back to `user` (UI):

```
products.view, barcodes.view, sales.create, debts.view, expenses.view, cashbox.view
```

This is a sensible "cashier" profile: browse the catalogue, scan, sell, look at the debts
and the cash box — but cannot modify the catalogue, the debts, the expenses or the
cash-box balance.

The list lives in two places that must stay in sync:
`backend/permissions.js → DEFAULT_USER_PERMISSIONS` and
`frontend/src/pages/Users.jsx → DEFAULT_PERMISSIONS`.

---

## 8. The admin UI

Path: **زر الحساب 👤 (أعلى يسار الشريط، بجانب سعر الدولار) → إدارة المستخدمين والصلاحيات**
or the URL `/users`.

**Creating a user**
1. Open «مستخدم جديد».
2. Fill in اسم المستخدم, كلمة المرور, الاسم الكامل and choose الدور.
3. For the role «مستخدم», tick the permissions in the grouped matrix.
4. «إضافة المستخدم».

**Editing a user**
1. «تعديل» on the user card → the edit sheet opens.
2. Change الاسم الكامل / الدور / التفعيل, optionally set a new password.
3. Adjust the permission matrix.
4. «حفظ التعديلات» — if you edited **your own** account the session is refreshed
   automatically.

**Deleting a user** — «حذف المستخدم» with a confirmation dialog (hidden for your own card).

**Useful patterns**

| Goal | Minimum permission set |
|---|---|
| Cashier | `products.view`, `barcodes.view`, `sales.create` |
| Cashier with debts | the above + `debts.view` (+ `debts.edit` to manage people) |
| Store keeper | `products.view`, `products.edit`, `barcodes.view`, `barcodes.manage`, `inventory.view`, `inventory.edit` |
| Accountant | `debts.view`, `debts.edit`, `expenses.view`, `expenses.edit`, `cashbox.view`, `cashbox.edit`, `reports.view` |
| Supervisor | everything except user management |

---

## 9. Security checklist

**Before going live**

- [ ] Change the default admin password (`admin123`) — from the app or by deleting the
      seeded account and restarting with a new `ADMIN_PASSWORD`.
- [ ] Replace `JWT_SECRET` in `backend/.env` with a long random string
      (`openssl rand -hex 32`).
- [ ] Serve the app over HTTPS (the camera requires a secure context anyway).
- [ ] Keep `backend/.env` out of version control and use a secrets manager in production.
- [ ] Create one admin account per person — never share the admin login.
- [ ] Give each employee only the permissions their job needs.

**Already implemented**

- [x] Passwords hashed with bcrypt (cost 10), never returned by the API.
- [x] JWT signed with HS256, 30-day expiry.
- [x] All business endpoints require a valid token.
- [x] All business endpoints re-check the permission server-side.
- [x] Admins bypass permission checks; the last admin cannot be removed or disabled.
- [x] Disabled accounts are rejected on login and on every request.
- [x] `passwordHash` is stripped by `toJSON` and `toSafe`.
- [x] Unknown permission keys are filtered out on write.
- [x] The session is cleared automatically on any `401`.

**Known gaps (not implemented yet)**

- [ ] No rate limiting on `POST /api/auth/login` → add a limiter (e.g. `express-rate-limit`)
      before exposing the API to the internet.
- [ ] No refresh tokens → the session ends after 30 days and the user logs in again.
- [ ] Tokens are stored in `localStorage` → an XSS bug would expose them; consider
      httpOnly cookies if the threat model requires it.
- [ ] `cors()` is fully open → restrict it to the frontend origin in production.
