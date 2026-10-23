import React, { useEffect, useState } from 'react';
import { addUnit, deleteUnit, getUnits, updateUnit } from '../api';
import { TrashIcon } from '../components/Icons';

const empty = { name: '', note: '' };

// إدارة وحدات القياس — للأدمن فقط (تُختار عند إضافة الأصناف)
export default function Units() {
  const [units, setUnits] = useState([]);
  const [form, setForm] = useState(empty);
  const [msg, setMsg] = useState(null);
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(null); // { id, name, note }

  const load = () => getUnits().then(setUnits).catch(() => setUnits([]));
  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await addUnit(form);
      setForm(empty);
      setMsg({ type: 'success', text: 'تمت إضافة الوحدة — صارت متاحة لكل الأصناف' });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّرت الإضافة' });
    } finally {
      setBusy(false);
    }
  };

  const saveEdit = async () => {
    if (!editing) return;
    try {
      await updateUnit(editing.id, { name: editing.name, note: editing.note });
      setEditing(null);
      setMsg({ type: 'success', text: 'تم تعديل الوحدة وتحديث الأصناف التي تستخدمها' });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر التعديل' });
    }
  };

  const remove = async (unit) => {
    try {
      await deleteUnit(unit._id);
      setMsg({ type: 'success', text: `تم حذف الوحدة «${unit.name}»` });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر الحذف' });
    }
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>وحدات القياس</h2>
            <p className="muted">أضف الوحدات التي ستظهر عند إدخال الأصناف (شراء / بيع)</p>
          </div>
        </div>

        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

        <form className="form" onSubmit={submit}>
          <div className="form-grid">
            <label className="field">
              <span>اسم الوحدة</span>
              <input
                placeholder="مثال: كرتون"
                value={form.name}
                onChange={e => setForm({ ...form, name: e.target.value })}
                required
              />
            </label>
            <label className="field">
              <span>ملاحظة (اختياري)</span>
              <input
                placeholder="مثال: 24 علبة"
                value={form.note}
                onChange={e => setForm({ ...form, note: e.target.value })}
              />
            </label>
          </div>
          <button className="btn primary block" disabled={busy || !form.name.trim()}>
            {busy ? 'جارٍ الحفظ…' : 'إضافة وحدة'}
          </button>
        </form>
      </section>

      <section className="list-section">
        <div className="section-head">
          <h2>الوحدات المتاحة <span className="count">{units.length}</span></h2>
        </div>

        {units.length === 0 && <div className="empty-state card">لا توجد وحدات — أضف أول وحدة من الأعلى</div>}

        <div className="unit-list">
          {units.map(u => (
            editing?.id === u._id ? (
              <div className="unit-row editing" key={u._id}>
                <div className="form-grid">
                  <label className="field">
                    <span>الاسم</span>
                    <input value={editing.name} onChange={e => setEditing({ ...editing, name: e.target.value })} />
                  </label>
                  <label className="field">
                    <span>ملاحظة</span>
                    <input value={editing.note} onChange={e => setEditing({ ...editing, note: e.target.value })} />
                  </label>
                </div>
                <div className="unit-actions">
                  <button className="btn primary sm" onClick={saveEdit} disabled={!editing.name.trim()}>حفظ</button>
                  <button className="btn secondary sm" onClick={() => setEditing(null)}>إلغاء</button>
                </div>
              </div>
            ) : (
              <div className="unit-row" key={u._id}>
                <div className="unit-main">
                  <b>{u.name}</b>
                  <small className="muted">
                    {u.note ? `${u.note} · ` : ''}
                    {u.products > 0 ? `مستخدمة في ${u.products} صنف` : 'غير مستخدمة'}
                  </small>
                </div>
                <div className="unit-actions">
                  <button
                    className="btn secondary sm"
                    onClick={() => setEditing({ id: u._id, name: u.name, note: u.note || '' })}
                  >
                    تعديل
                  </button>
                  <button className="btn danger sm" onClick={() => remove(u)} aria-label={`حذف ${u.name}`}>
                    <TrashIcon />
                  </button>
                </div>
              </div>
            )
          ))}
        </div>
      </section>
    </div>
  );
}
