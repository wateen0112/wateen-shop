import React, { useEffect, useState } from 'react';
import { addExpense, deleteExpense, getExpenses } from '../api';
import { useAuth } from '../context/AuthContext';
import { TrashIcon } from '../components/Icons';

export default function Expenses() {
  const { can } = useAuth();
  const [expenses, setExpenses] = useState([]);
  const [form, setForm] = useState({ title: '', amount: '', currency: 'SYP', note: '' });
  const [saving, setSaving] = useState(false);

  const load = () => getExpenses().then(setExpenses);
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await addExpense(form);
      setForm({ title: '', amount: '', currency: 'SYP', note: '' });
      load();
    } finally {
      setSaving(false);
    }
  };

  const fmt = (n) => Number(n).toLocaleString('ar-SY');

  return (
    <div className="page">
      {can('expenses.edit') && (
      <section className="card">
        <div className="card-head">
          <div>
            <h2>تسجيل مصروف</h2>
            <p className="muted">أضف مصروفاً جديداً</p>
          </div>
        </div>
        <form className="form" onSubmit={submit}>
          <label className="field">
            <span>البيان</span>
            <input placeholder="مثال: إيجار المحل" value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} required />
          </label>
          <div className="form-grid">
            <label className="field">
              <span>المبلغ</span>
              <input type="number" step="any" inputMode="decimal" placeholder="0" value={form.amount} onChange={e => setForm({ ...form, amount: e.target.value })} required />
            </label>
            <label className="field">
              <span>العملة</span>
              <select value={form.currency} onChange={e => setForm({ ...form, currency: e.target.value })}>
                <option value="SYP">ليرة سورية</option>
                <option value="USD">دولار</option>
              </select>
            </label>
          </div>
          <label className="field">
            <span>ملاحظة</span>
            <input placeholder="اختياري" value={form.note} onChange={e => setForm({ ...form, note: e.target.value })} />
          </label>
          <button className="btn primary block" disabled={saving}>{saving ? 'جارٍ الحفظ…' : 'تسجيل المصروف'}</button>
        </form>
      </section>
      )}

      <section className="list-section">
        <div className="section-head">
          <h2>سجل المصروفات <span className="count">{expenses.length}</span></h2>
        </div>
        {expenses.length === 0 ? (
          <div className="empty-state">لا توجد مصروفات مسجّلة</div>
        ) : (
          <ul className="record-list">
            {expenses.map(e => (
              <li className="record-item" key={e._id}>
                <div className="record-main">
                  <b>{e.title}</b>
                  <small>{new Date(e.date).toLocaleDateString('ar-SY')}{e.note ? ` · ${e.note}` : ''}</small>
                </div>
                <div className="record-side">
                  <span className="amount">{fmt(e.amount)} {e.currency}</span>
                  {can('expenses.edit') && (
                    <button className="icon-btn danger-ghost" onClick={() => deleteExpense(e._id).then(load)} aria-label="حذف">
                      <TrashIcon />
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
