import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { addUser, deleteUser, getPermissionCatalog, getUsers, updateUser } from '../api';
import { useAuth } from '../context/AuthContext';
import { CheckIcon, CloseIcon, ShieldIcon, TrashIcon } from '../components/Icons';

const emptyForm = { username: '', password: '', name: '', role: 'user', permissions: [] };

// الصلاحيات الافتراضية لمستخدم جديد (نفس ما يطبّقه الـ backend)
const DEFAULT_PERMISSIONS = [
  'products.view', 'barcodes.view', 'sales.create',
  'debts.view', 'expenses.view', 'cashbox.view',
];

export default function Users() {
  const { user: me, refresh } = useAuth();
  const [users, setUsers] = useState([]);
  const [catalog, setCatalog] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [edit, setEdit] = useState(null);
  const [msg, setMsg] = useState(null);
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const load = () => getUsers().then(setUsers).catch(e => setErr(e.response?.data?.error || 'تعذّر تحميل المستخدمين'));
  useEffect(() => {
    load();
    getPermissionCatalog().then(setCatalog).catch(() => {});
  }, []);

  const groups = useMemo(() => {
    const g = {};
    catalog.forEach(p => {
      g[p.group] = g[p.group] || [];
      g[p.group].push(p);
    });
    return g;
  }, [catalog]);

  const submit = async (e) => {
    e.preventDefault();
    setErr('');
    setMsg(null);
    setBusy(true);
    try {
      await addUser(form);
      setForm(emptyForm);
      setMsg({ type: 'success', text: `تم إنشاء المستخدم ${form.username}` });
      load();
    } catch (e2) {
      setErr(e2.response?.data?.error || 'تعذّر إنشاء المستخدم');
    } finally {
      setBusy(false);
    }
  };

  const saveEdit = async () => {
    setErr('');
    setBusy(true);
    try {
      await updateUser(edit._id, {
        name: edit.name,
        role: edit.role,
        active: edit.active,
        permissions: edit.role === 'admin' ? undefined : edit.permissions,
        password: edit.password || undefined,
      });
      setMsg({ type: 'success', text: 'تم حفظ التعديلات' });
      setEdit(null);
      load();
      if (me && edit._id === me._id) refresh();
    } catch (e2) {
      setErr(e2.response?.data?.error || 'تعذّر حفظ التعديلات');
    } finally {
      setBusy(false);
    }
  };

  const remove = async (u) => {
    if (!window.confirm(`حذف المستخدم ${u.username}؟`)) return;
    try {
      await deleteUser(u._id);
      setMsg({ type: 'success', text: 'تم حذف المستخدم' });
      load();
    } catch (e2) {
      setErr(e2.response?.data?.error || 'تعذّر الحذف');
    }
  };

  const togglePerm = (list, key) =>
    list.includes(key) ? list.filter(k => k !== key) : [...list, key];

  const permLabel = (u) => {
    if (u.role === 'admin') return 'كل الصلاحيات';
    return `${u.permissions.length} صلاحية`;
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>مستخدم جديد</h2>
            <p className="muted">أنشئ حساباً وحدّد صلاحياته</p>
          </div>
          <Link className="btn secondary sm" to="/audit">سجل العمليات</Link>
          <span className="brand-logo"><ShieldIcon /></span>
        </div>

        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}
        {err && <div className="msg error">{err}</div>}

        <form className="form" onSubmit={submit}>
          <div className="form-grid">
            <label className="field">
              <span>اسم المستخدم</span>
              <input
                autoCapitalize="none"
                placeholder="sara"
                value={form.username}
                onChange={e => setForm({ ...form, username: e.target.value })}
                required
              />
            </label>
            <label className="field">
              <span>كلمة المرور</span>
              <input
                type="text"
                placeholder="4 أحرف على الأقل"
                value={form.password}
                onChange={e => setForm({ ...form, password: e.target.value })}
                required
                minLength={4}
              />
            </label>
            <label className="field">
              <span>الاسم الكامل</span>
              <input placeholder="سارة أحمد" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} />
            </label>
            <label className="field">
              <span>الدور</span>
              <select
                value={form.role}
                onChange={e => setForm(f => ({
                  ...f,
                  role: e.target.value,
                  permissions: e.target.value === 'admin' ? [] : (f.role === 'admin' ? DEFAULT_PERMISSIONS : f.permissions),
                }))}
              >
                <option value="user">مستخدم</option>
                <option value="admin">أدمن</option>
              </select>
            </label>
          </div>

          {form.role === 'user' && (
            <div className="perm-block">
              <span className="field-label">الصلاحيات</span>
              {Object.entries(groups).map(([group, items]) => (
                <div className="perm-group" key={group}>
                  <b>{group}</b>
                  {items.map(p => (
                    <label className="perm-row" key={p.key}>
                      <input
                        type="checkbox"
                        checked={form.permissions.includes(p.key)}
                        onChange={() => setForm(f => ({ ...f, permissions: togglePerm(f.permissions, p.key) }))}
                      />
                      <span>{p.label}</span>
                    </label>
                  ))}
                </div>
              ))}
            </div>
          )}

          <button className="btn primary block" disabled={busy}>إضافة المستخدم</button>
        </form>
      </section>

      <section className="list-section">
        <div className="section-head">
          <h2>المستخدمون <span className="count">{users.length}</span></h2>
        </div>

        <div className="user-list">
          {users.length === 0 && <div className="empty-state">لا يوجد مستخدمون</div>}
          {users.map(u => (
            <article className={`user-card ${u.active ? '' : 'disabled'}`} key={u._id}>
              <div className="user-top">
                <div className="user-info">
                  <h3>{u.name || u.username}</h3>
                  <div className="product-tags">
                    <span className="pill">{u.username}</span>
                    <span className={`pill ${u.role === 'admin' ? 'ok' : ''}`}>{u.role === 'admin' ? 'أدمن' : 'مستخدم'}</span>
                    <span className="pill">{permLabel(u)}</span>
                    {!u.active && <span className="pill warn">معطّل</span>}
                  </div>
                </div>
                <button className="btn secondary sm" onClick={() => setEdit({ ...u, permissions: [...u.permissions], password: '' })}>
                  تعديل
                </button>
              </div>

              {u._id !== me?._id && (
                <button className="btn danger sm block" onClick={() => remove(u)}>
                  <TrashIcon /> حذف المستخدم
                </button>
              )}
            </article>
          ))}
        </div>
      </section>

      {edit && (
        <div className="sheet-overlay" onClick={() => setEdit(null)}>
          <div className="sheet" onClick={e => e.stopPropagation()}>
            <div className="sheet-head">
              <h3>تعديل {edit.name || edit.username}</h3>
              <button className="icon-btn ghost" onClick={() => setEdit(null)} aria-label="إغلاق"><CloseIcon /></button>
            </div>

            <div className="sheet-body">
              {err && <div className="msg error">{err}</div>}

              <label className="field">
                <span>الاسم الكامل</span>
                <input value={edit.name || ''} onChange={e => setEdit({ ...edit, name: e.target.value })} />
              </label>

              <label className="field">
                <span>الدور</span>
                <select
                  value={edit.role}
                  onChange={e => setEdit(ed => ({
                    ...ed,
                    role: e.target.value,
                    permissions: e.target.value === 'admin'
                      ? []
                      : (ed.role === 'admin' ? DEFAULT_PERMISSIONS : ed.permissions),
                  }))}
                >
                  <option value="user">مستخدم</option>
                  <option value="admin">أدمن</option>
                </select>
              </label>

              <label className="perm-row">
                <input type="checkbox" checked={!!edit.active} onChange={e => setEdit({ ...edit, active: e.target.checked })} />
                <span>الحساب مفعّل</span>
              </label>

              <label className="field">
                <span>كلمة مرور جديدة (اختياري)</span>
                <input type="text" placeholder="اتركها فارغة للإبقاء عليها" value={edit.password} onChange={e => setEdit({ ...edit, password: e.target.value })} />
              </label>

              {edit.role === 'user' && (
                <div className="perm-block">
                  <span className="field-label">الصلاحيات</span>
                  {Object.entries(groups).map(([group, items]) => (
                    <div className="perm-group" key={group}>
                      <b>{group}</b>
                      {items.map(p => (
                        <label className="perm-row" key={p.key}>
                          <input
                            type="checkbox"
                            checked={edit.permissions.includes(p.key)}
                            onChange={() => setEdit(e => ({ ...e, permissions: togglePerm(e.permissions, p.key) }))}
                          />
                          <span>{p.label}</span>
                        </label>
                      ))}
                    </div>
                  ))}
                </div>
              )}

              <button className="btn primary block" onClick={saveEdit} disabled={busy}>
                <CheckIcon /> حفظ التعديلات
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
