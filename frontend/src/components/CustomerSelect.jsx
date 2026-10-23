import React, { useEffect, useState } from 'react';
import { addCustomer, getCustomers } from '../api';
import { useAuth } from '../context/AuthContext';

// اختيار شخص للدين — أو إنشاء شخص جديد مباشرة
export default function CustomerSelect({ value, onChange, hint }) {
  const { can } = useAuth();
  const [customers, setCustomers] = useState([]);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ name: '', phone: '', initialBalance: '' });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  const load = () => getCustomers().then(setCustomers).catch(() => {});
  useEffect(() => { load(); }, []);

  const create = async () => {
    if (!form.name.trim()) return;
    setBusy(true);
    setErr(null);
    try {
      const c = await addCustomer({
        name: form.name.trim(),
        phone: form.phone.trim(),
        initialBalance: Number(form.initialBalance) || 0,
      });
      await load();
      onChange(c._id);
      setCreating(false);
      setForm({ name: '', phone: '', initialBalance: '' });
    } catch (e2) {
      setErr(e2.response?.data?.error || 'تعذّر إنشاء الشخص');
    } finally {
      setBusy(false);
    }
  };

  const selected = customers.find(c => c._id === value);

  return (
    <div className="customer-pick">
      {creating ? (
        <div className="customer-create">
          <label className="field">
            <span>اسم الشخص</span>
            <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="مثال: أبو محمد" />
          </label>
          <div className="form-grid">
            <label className="field">
              <span>الهاتف</span>
              <input value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} inputMode="tel" placeholder="اختياري" />
            </label>
            <label className="field">
              <span>رصيد مسبق للدين</span>
              <input type="number" step="any" inputMode="decimal" value={form.initialBalance} onChange={e => setForm({ ...form, initialBalance: e.target.value })} placeholder="0" />
            </label>
          </div>
          {err && <div className="msg error">{err}</div>}
          <div className="row-2">
            <button type="button" className="btn secondary" onClick={() => setCreating(false)}>إلغاء</button>
            <button type="button" className="btn primary" disabled={busy || !form.name.trim()} onClick={create}>
              {busy ? 'جارٍ الحفظ…' : 'حفظ الشخص'}
            </button>
          </div>
        </div>
      ) : (
        <>
          <select value={value || ''} onChange={e => onChange(e.target.value || null)}>
            <option value="">بدون شخص (نقدي)</option>
            {customers.map(c => (
              <option key={c._id} value={c._id}>
                {c.name}{c.balance ? ` — عليه ${Number(c.balance).toLocaleString('ar-SY')}` : ''}
              </option>
            ))}
          </select>
          <button type="button" className="btn secondary sm" onClick={() => setCreating(true)} disabled={!can('debts.edit')}>
            ＋ شخص جديد
          </button>
          {hint && <small className="hint">{hint}</small>}
          {selected && selected.balance > 0 && (
            <small className="hint warn">عليه حالياً {Number(selected.balance).toLocaleString('ar-SY')} ل.س</small>
          )}
        </>
      )}
    </div>
  );
}
