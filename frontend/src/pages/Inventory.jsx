import React, { useEffect, useState } from 'react';
import { getInventories, getInventorySheet, saveInventory } from '../api';
import { useAuth } from '../context/AuthContext';

export default function InventoryPage() {
  const { can } = useAuth();
  const [sheet, setSheet] = useState([]);
  const [actual, setActual] = useState({});
  const [hist, setHist] = useState([]);
  const [showHist, setShowHist] = useState(false);
  const [saving, setSaving] = useState(false);

  const load = () => getInventorySheet().then(setSheet);
  useEffect(() => { load(); getInventories().then(setHist); }, []);

  const filled = sheet.filter(p => actual[p._id] !== undefined && actual[p._id] !== '');

  const submit = async () => {
    const items = filled.map(p => ({ productId: p._id, actualQty: Number(actual[p._id]) }));
    if (!items.length) return alert('أدخل الكميات الفعلية أولاً');
    if (!confirm(`سيتم تعديل كميات ${items.length} صنفاً إلى العدّ الفعلي. متابعة؟`)) return;
    setSaving(true);
    try {
      await saveInventory(items);
      setActual({});
      load();
      getInventories().then(setHist);
      alert('تم حفظ الجرد');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>جرد جديد</h2>
            <p className="muted">أدخل الكمية الفعلية لكل صنف</p>
          </div>
          <span className="count">{filled.length}/{sheet.length}</span>
        </div>

        {sheet.length === 0 ? (
          <div className="empty-state">لا توجد أصناف للجرد</div>
        ) : (
          <ul className="stock-list">
            {sheet.map(p => {
              const diff = actual[p._id] !== undefined && actual[p._id] !== '' ? Number(actual[p._id]) - p.quantity : null;
              return (
                <li className="stock-item" key={p._id}>
                  <div className="stock-info">
                    <b>{p.name}</b>
                    <small>مسجّلة: {p.quantity} {p.unit}</small>
                  </div>
                  <div className="stock-input">
                    <input
                      type="number"
                      inputMode="numeric"
                      placeholder="—"
                      disabled={!can('inventory.edit')}
                      value={actual[p._id] ?? ''}
                      onChange={e => setActual({ ...actual, [p._id]: e.target.value })}
                    />
                    {diff !== null && <span className={`diff ${diff === 0 ? 'ok' : ''}`}>{diff > 0 ? '+' : ''}{diff}</span>}
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        {can('inventory.edit') && (
          <button className="btn primary block" disabled={saving || !filled.length} onClick={submit} style={{ marginTop: 14 }}>
            {saving ? 'جارٍ الحفظ…' : 'حفظ الجرد وتحديث الكميات'}
          </button>
        )}
        <button className="btn secondary block" onClick={() => setShowHist(!showHist)} style={{ marginTop: 8 }}>
          {showHist ? 'إخفاء' : 'عرض'} سجل الجردات السابقة
        </button>
      </section>

      {showHist && hist.map(inv => (
        <section className="card" key={inv._id}>
          <div className="card-head">
            <div>
              <h2>{new Date(inv.date).toLocaleDateString('ar-SY')}</h2>
              <p className="muted">{new Date(inv.date).toLocaleTimeString('ar-SY')}</p>
            </div>
            <span className="count">{inv.items.length}</span>
          </div>
          <ul className="record-list">
            {inv.items.map((it, i) => {
              const d = it.actualQty - it.recordedQty;
              return (
                <li className="record-item" key={i}>
                  <div className="record-main">
                    <b>{it.name}</b>
                    <small>مسجّلة {it.recordedQty} · فعلية {it.actualQty}</small>
                  </div>
                  <span className={`diff ${d === 0 ? 'ok' : ''}`}>{d > 0 ? '+' : ''}{d}</span>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}
