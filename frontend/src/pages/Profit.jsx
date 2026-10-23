import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { getCashbox, setCashboxInitial } from '../api';
import { useAuth } from '../context/AuthContext';

const fmt = (n) => (n == null ? '—' : Number(n).toLocaleString('ar-SY'));

// الصندوق: رصيد ابتدائي + المبيعات النقدية − المصروفات، مع الديون القائمة
export default function Profit() {
  const { can } = useAuth();
  const [box, setBox] = useState(null);
  const [initial, setInitial] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);

  const load = () => getCashbox().then(b => { setBox(b); setInitial(String(b.initialBalance ?? 0)); }).catch(() => {});
  useEffect(() => { load(); }, []);

  const saveInitial = async () => {
    setBusy(true);
    try {
      const b = await setCashboxInitial(Number(initial) || 0);
      setBox(b);
      setMsg({ type: 'success', text: 'تم حفظ الرصيد الابتدائي' });
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر الحفظ' });
    } finally {
      setBusy(false);
    }
  };

  const negative = box && box.current < 0;

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>الصندوق</h2>
            <p className="muted">رصيد ابتدائي + نقدية المبيعات − المصروفات</p>
          </div>
        </div>

        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

        <div className="kpi-stack">
          <div className={`kpi-card net ${negative ? 'negative' : ''}`}>
            <small>رصيد الصندوق الحالي</small>
            <b>{fmt(box?.current)} <em>ل.س</em></b>
            <small className="kpi-foot">رصيد ابتدائي {fmt(box?.initialBalance)} + مبيعات {fmt(box?.salesCash)} − مصروفات {fmt(box?.expensesTotal)}</small>
          </div>
        </div>

        {can('cashbox.edit') && (
          <div className="initial-box">
            <label className="field">
              <span>الرصيد الابتدائي للصندوق</span>
              <input
                type="number"
                step="any"
                inputMode="decimal"
                value={initial}
                onChange={e => setInitial(e.target.value)}
                placeholder="0"
              />
            </label>
            <button className="btn secondary block" disabled={busy} onClick={saveInitial}>
              {busy ? 'جارٍ الحفظ…' : 'حفظ الرصيد الابتدائي'}
            </button>
            <small className="hint">المبلغ الموجود في الصندوق قبل بدء الحساب — يُضاف لكل المبيعات النقدية.</small>
          </div>
        )}
      </section>

      <section className="card">
        <div className="card-head">
          <div>
            <h2>حركة الصندوق</h2>
            <p className="muted">محسوبة بسعر الدولار الحالي</p>
          </div>
        </div>

        <div className="kpi-stack">
          <div className="kpi-card">
            <span className="kpi-ico success">↗</span>
            <div>
              <small>مبيعات نقدية</small>
              <b>{fmt(box?.salesCash)} <em>ل.س</em></b>
              {box ? <small className="kpi-foot">{box.salesCount} عملية بيع</small> : null}
            </div>
          </div>

          <div className="kpi-card">
            <span className="kpi-ico danger">↘</span>
            <div>
              <small>المصروفات</small>
              <b>{fmt(box?.expensesTotal)} <em>ل.س</em></b>
            </div>
          </div>

          <div className="kpi-card">
            <span className="kpi-ico">≡</span>
            <div>
              <small>مبيعات على الحساب (ديون)</small>
              <b>{fmt(box?.salesCredit)} <em>ل.س</em></b>
            </div>
          </div>

          <div className={`kpi-card net ${box && box.netProfit < 0 ? 'negative' : ''}`}>
            <small>الربح الصافي</small>
            <b>{fmt(box?.netProfit)} <em>ل.س</em></b>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-head">
          <div>
            <h2>الديون القائمة</h2>
            <p className="muted">مستحق على الزبائن</p>
          </div>
          <span className="count">{fmt(box?.debtsTotal)} ل.س</span>
        </div>
        <Link className="btn secondary block" to="/debts">إدارة الديون</Link>
      </section>
    </div>
  );
}
