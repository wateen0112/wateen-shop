# واتين شوب — Wateen Shop

تطبيق إدارة متجر عربي (RTL) بواجهة React وخادم Express/MongoDB: أصناف وباركودات، بيع سريع، ديون، مصروفات، صندوق، جرد، تعدد مستخدمين وصلاحيات، وسجل عمليات.

## البنية

| المجلد | التقنية | الوصف |
|---|---|---|
| `backend/` | Node.js + Express + Mongoose | REST API على المنفذ 5000 |
| `frontend/` | React + Vite | واجهة المستخدم (تتصل بـ `/api`) |

## التشغيل

```bash
# 1) الخادم
cd backend
npm install
cp .env.example .env   # ثم املأ MONGO_URI وJWT_SECRET
npm run dev

# 2) الواجهة (طرفية ثانية)
cd frontend
npm install
npm run dev
```

- الواجهة: http://localhost:5173 (أو https عبر إعداد Vite الحالي)
- الـ API: http://localhost:5000/api
- يُنشأ حساب أدمن تلقائياً عند أول تشغيل من متغيرات `ADMIN_USERNAME` / `ADMIN_PASSWORD`.

## المسارات الأساسية

`/api/auth` تسجيل الدخول · `/api/products` الأصناف · `/api/units` وحدات القياس · `/api/sales` المبيعات · `/api/customers` الزبائن والديون · `/api/expenses` المصروفات · `/api/cashbox` الصندوق · `/api/inventory` الجرد · `/api/users` المستخدمون · `/api/audit` سجل العمليات.
