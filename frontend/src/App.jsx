import React, { useEffect, useState } from 'react';
import { BrowserRouter, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { getPermissionCatalog, getRate, changePassword } from './api';
import { AuthProvider, useAuth } from './context/AuthContext';
import Products from './pages/Products';
import Sell from './pages/Sell';
import Barcodes from './pages/Barcodes';
import Expenses from './pages/Expenses';
import Profit from './pages/Profit';
import InventoryPage from './pages/Inventory';
import Debts from './pages/Debts';
import Login from './pages/Login';
import Users from './pages/Users';
import Units from './pages/Units';
import Audit from './pages/Audit';
import {
  BarcodeIcon, BoxIcon, CashboxIcon, ClipboardIcon, CloseIcon, LogoutIcon, MenuIcon, SellIcon,
  ShieldIcon, StoreIcon, UserIcon, UsersIcon, WalletIcon,
} from './components/Icons';
import './styles.css';

const PRIMARY_TABS = [
  { to: '/', label: 'الأصناف', icon: BoxIcon, end: true, perm: 'products.view' },
  { to: '/sell', label: 'بيع', icon: SellIcon, perm: 'sales.create' },
  { to: '/debts', label: 'الديون', icon: UsersIcon, perm: 'debts.view' },
  { to: '/profit', label: 'الصندوق', icon: CashboxIcon, perm: 'cashbox.view' },
];

const DRAWER_TABS = [
  { to: '/barcodes', label: 'الباركود', icon: BarcodeIcon, perm: 'barcodes.view' },
  { to: '/expenses', label: 'المصروفات', icon: WalletIcon, perm: 'expenses.view' },
  { to: '/inventory', label: 'الجرد', icon: ClipboardIcon, perm: 'inventory.view' },
];

function NoAccess({ perm }) {
  return (
    <div className="page">
      <div className="empty-state card">
        <ShieldIcon />
        <h3>لا تملك صلاحية الوصول</h3>
        <p className="muted">هذه الصفحة تحتاج صلاحية: {perm}</p>
        <small className="hint">اطلب من الأدمن تفعيلها من صفحة المستخدمين</small>
      </div>
    </div>
  );
}

function Guard({ perm, children }) {
  const { can } = useAuth();
  if (!can(perm)) return <NoAccess perm={perm} />;
  return children;
}

function DrawerMenu({ open, onClose, tabs, isAdmin, user, onAccount }) {
  if (!open || !user) return null;

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <aside className="drawer" onClick={e => e.stopPropagation()} aria-label="القائمة">
        <div className="drawer-head">
          <span className="brand-logo"><StoreIcon /></span>
          <div className="drawer-title">
            <b>{user.name || user.username}</b>
            <small>{user.name ? `${user.username} — ` : ''}{isAdmin ? 'أدمن' : 'مستخدم'}</small>
          </div>
          <button className="icon-btn ghost drawer-close" onClick={onClose} aria-label="إغلاق">
            <CloseIcon />
          </button>
        </div>

        <nav className="drawer-nav">
          {tabs.length > 0 && <span className="drawer-label">أقسام إضافية</span>}
          {tabs.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end
              className={({ isActive }) => `drawer-link ${isActive ? 'active' : ''}`}
              onClick={onClose}
            >
              <Icon />
              <span>{label}</span>
            </NavLink>
          ))}

          {isAdmin && (
            <>
              <span className="drawer-label">الإدارة</span>
              <NavLink
                to="/units"
                className={({ isActive }) => `drawer-link ${isActive ? 'active' : ''}`}
                onClick={onClose}
              >
                <BoxIcon />
                <span>وحدات القياس</span>
              </NavLink>
              <NavLink
                to="/users"
                className={({ isActive }) => `drawer-link ${isActive ? 'active' : ''}`}
                onClick={onClose}
              >
                <UsersIcon />
                <span>المستخدمون والصلاحيات</span>
              </NavLink>
              <NavLink
                to="/audit"
                className={({ isActive }) => `drawer-link ${isActive ? 'active' : ''}`}
                onClick={onClose}
              >
                <ClipboardIcon />
                <span>سجل العمليات</span>
              </NavLink>
            </>
          )}
        </nav>

        <div className="drawer-foot">
          <button className="btn secondary block sm" onClick={() => { onClose(); onAccount(); }}>
            <UserIcon /> حسابي وكلمة المرور
          </button>
          <small className="hint center">أبو وتين — إدارة المتجر</small>
        </div>
      </aside>
    </div>
  );
}

function AccountSheet({ open, onClose, catalog, onLogout }) {
  const { user, isAdmin } = useAuth();
  const navigate = useNavigate();
  const [pw, setPw] = useState({ current: '', next: '' });
  const [pwMsg, setPwMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  if (!open || !user) return null;

  const labels = catalog.filter(p => p.key !== 'users.manage');
  const owned = isAdmin ? labels : labels.filter(p => (user.permissions || []).includes(p.key));

  const savePassword = async () => {
    setPwMsg(null);
    setBusy(true);
    try {
      await changePassword(pw.current, pw.next);
      setPw({ current: '', next: '' });
      setPwMsg({ type: 'success', text: 'تم تغيير كلمة المرور' });
    } catch (e2) {
      setPwMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر تغيير كلمة المرور' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div className="sheet" onClick={e => e.stopPropagation()}>
        <div className="sheet-head">
          <h3>حسابي</h3>
          <button className="icon-btn ghost" onClick={onClose} aria-label="إغلاق"><CloseIcon /></button>
        </div>

        <div className="sheet-body">
          <div className="account-head">
            <span className="brand-logo"><UserIcon /></span>
            <div>
              <b>{user.name || user.username}</b>
              <small className="muted">{user.username} — {isAdmin ? 'أدمن' : 'مستخدم'}</small>
            </div>
          </div>

          {isAdmin && (
            <button
              className="btn secondary block"
              onClick={() => { onClose(); navigate('/users'); }}
            >
              <ShieldIcon /> إدارة المستخدمين والصلاحيات
            </button>
          )}
          {isAdmin && (
            <button
              className="btn secondary block"
              onClick={() => { onClose(); navigate('/audit'); }}
            >
              <ClipboardIcon /> سجل العمليات
            </button>
          )}

          <span className="field-label">صلاحياتك</span>
          <div className="perm-chips">
            {owned.length === 0 && <small className="hint">لا توجد صلاحيات — اطلب من الأدمن</small>}
            {owned.map(p => (
              <span className="pill" key={p.key}>{p.label}</span>
            ))}
          </div>

          <details className="pw-box">
            <summary>تغيير كلمة المرور</summary>
            {pwMsg && <div className={`msg ${pwMsg.type}`}>{pwMsg.text}</div>}
            <label className="field">
              <span>كلمة المرور الحالية</span>
              <input type="password" value={pw.current} onChange={e => setPw({ ...pw, current: e.target.value })} />
            </label>
            <label className="field">
              <span>كلمة المرور الجديدة</span>
              <input type="password" value={pw.next} onChange={e => setPw({ ...pw, next: e.target.value })} />
            </label>
            <button className="btn secondary block" disabled={busy || !pw.current || pw.next.length < 4} onClick={savePassword}>
              {busy ? 'جارٍ الحفظ…' : 'حفظ كلمة المرور'}
            </button>
          </details>

          <button className="btn danger block" onClick={onLogout}>
            <LogoutIcon /> تسجيل الخروج
          </button>
        </div>
      </div>
    </div>
  );
}

function Shell() {
  const { user, booting, can, isAdmin, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [rate, setRate] = useState(null);
  const [catalog, setCatalog] = useState([]);
  const [accountOpen, setAccountOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    getRate().then(r => setRate(r.usdToSyp)).catch(() => {});
    const t = setInterval(() => getRate().then(r => setRate(r.usdToSyp)).catch(() => {}), 5 * 60 * 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    getPermissionCatalog().then(setCatalog).catch(() => {});
  }, []);

  if (booting) {
    return (
      <div className="login-page">
        <div className="login-card">
          <div className="login-brand">
            <span className="brand-logo lg"><StoreIcon /></span>
            <h1>أبو وتين</h1>
            <p>جارٍ التحميل...</p>
          </div>
        </div>
      </div>
    );
  }

  if (!user) return <Login />;

  const tabs = PRIMARY_TABS.filter(t => can(t.perm));
  const drawerTabs = DRAWER_TABS.filter(t => can(t.perm));

  const doLogout = () => {
    setAccountOpen(false);
    logout();
    navigate('/');
  };

  return (
    <div className="app">
      <header className="appbar">
        <div className="appbar-lead">
          <button className="appbar-menu" onClick={() => setMenuOpen(true)} aria-label="القائمة">
            <MenuIcon />
          </button>
          <div className="brand">
            <span className="brand-logo"><StoreIcon /></span>
            <span className="brand-text">
              <h1>أبو وتين</h1>
              <small>إدارة المتجر</small>
            </span>
          </div>
        </div>
        <div className="appbar-actions">
          <div className={`rate-chip ${rate ? '' : 'muted'}`}>
            {rate ? `الدولار ${Number(rate).toLocaleString('ar-SY')} ل.س` : 'الدولار غير مضبوط'}
          </div>
          <button className="icon-btn account-btn" onClick={() => setAccountOpen(true)} aria-label="حسابي">
            <UserIcon />
          </button>
        </div>
      </header>

      <main className="app-main">
        <Routes>
          <Route path="/" element={<Guard perm="products.view"><Products rate={rate} /></Guard>} />
          <Route path="/sell" element={<Guard perm="sales.create"><Sell rate={rate} /></Guard>} />
          <Route path="/barcodes" element={<Guard perm="barcodes.view"><Barcodes /></Guard>} />
          <Route path="/expenses" element={<Guard perm="expenses.view"><Expenses rate={rate} /></Guard>} />
          <Route path="/profit" element={<Guard perm="cashbox.view"><Profit rate={rate} /></Guard>} />
          <Route path="/debts" element={<Guard perm="debts.view"><Debts /></Guard>} />
          <Route path="/inventory" element={<Guard perm="inventory.view"><InventoryPage /></Guard>} />
          <Route
            path="/units"
            element={isAdmin ? <Units /> : <NoAccess perm="users.manage" />}
          />
          <Route
            path="/users"
            element={isAdmin ? <Users /> : <NoAccess perm="users.manage" />}
          />
          <Route
            path="/audit"
            element={isAdmin ? <Audit /> : <NoAccess perm="users.manage" />}
          />
          <Route path="*" element={<Guard perm="products.view"><Products rate={rate} /></Guard>} />
        </Routes>
      </main>

      {tabs.length > 0 && (
        <nav className="tabbar" aria-label="التنقل">
          {tabs.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
              <span className="tab-ico"><Icon /></span>
              <span className="tab-label">{label}</span>
            </NavLink>
          ))}
        </nav>
      )}

      <DrawerMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        tabs={drawerTabs}
        isAdmin={isAdmin}
        user={user}
        onAccount={() => setAccountOpen(true)}
      />

      <AccountSheet open={accountOpen} onClose={() => setAccountOpen(false)} catalog={catalog} onLogout={doLogout} />
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Shell />
      </AuthProvider>
    </BrowserRouter>
  );
}
