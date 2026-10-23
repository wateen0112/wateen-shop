import React, { useEffect, useState } from 'react';
import { addCustomer, addDebt, deleteCustomer, deleteDebt, getCustomer, getCustomers } from '../api';
import { useAuth } from '../context/AuthContext';
import { CloseIcon, SearchIcon, TrashIcon, UsersIcon } from '../components/Icons';

const fmt = (n) => Number(n || 0).toLocaleString('ar-SY');
const dateFmt = (d) => new Date(d).toLocaleDateString('ar-SY', { year: 'numeric', month: 'short', day: 'numeric' });

// صفحة الديون: أشخاص عليهم ديون للمتجر — كشف حساب، إضافة دين، وتسديد
export default function Debts() {
  const { can } = useAuth();
  const [customers, setCustomers] = useState([]);
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: '', phone: '', note: '', initialBalance: '' });
  const [busy, setBusy] = useState(false);
  const [openId, setOpenId] = useState(null);
  const [detail, setDetail] = useState(null);
  const [move, setMove] = useState({ type: 'debit', amount: '', note: '' });

  const load = () => getCustomers().then(setCustomers).catch(() => {});
  useEffect(() => { load(); }, []);

  const total = customers.reduce((s, c) => s + (c.balance || 0), 0);
  const filtered = customers.filter(c =>
    !search.trim() || c.name.includes(search.trim()) || (c.phone || '').includes(search.trim())
  );

  const create = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return;
    setBusy(true);
    try {
      await addCustomer({
        name: form.name.trim(),
        phone: form.phone.trim(),
        note: form.note.trim(),
        initialBalance: Number(form.initialBalance) || 0,
      });
      setForm({ name: '', phone: '', note: '', initialBalance: '' });
      setShowForm(false);
      setMsg({ type: 'success', text: 'تمت إضافة الشخص' });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّرت الإضافة' });
    } finally {
      setBusy(false);
    }
  };

  const openPerson = async (id) => {
    setOpenId(id);
    setMove({ type: 'debit', amount: '', note: '' });
    setDetail(null);
    getCustomer(id).then(setDetail).catch(() => setDetail({ movements: [] }));
  };

  const saveMove = async () => {
    const amount = Number(move.amount);
    if (!amount || amount <= 0) return;
    setBusy(true);
    try {
      await addDebt(openId, { type: move.type, amount, note: move.note.trim() });
      setMove({ type: move.type, amount: '', note: '' });
      const fresh = await getCustomer(openId);
      setDetail(fresh);
      load();
      setMsg({
        type: 'success',
        text: move.type === 'debit' ? 'تمت إضافة الدين' : 'تم تسجيل التسديد',
      });
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر الحفظ' });
    } finally {
      setBusy(false);
    }
  };

  const removePerson = async () => {
    if (!window.confirm('حذف هذا الشخص وكل حركات دينه؟')) return;
    await deleteCustomer(openId);
    setOpenId(null);
    setDetail(null);
    load();
  };

  const removeMove = async (debtId) => {
    await deleteDebt(openId, debtId);
    const fresh = await getCustomer(openId);
    setDetail(fresh);
    load();
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>الديون</h2>
            <p className="muted">أشخاص عليهم ديون للمتجر</p>
          </div>
          <span className="kpi-ico danger"><UsersIcon /></span>
        </div>

        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

        <div className="debt-total">
          <small>إجمالي الديون القائمة</small>
          <b className={total > 0 ? 'owes' : ''}>{fmt(total)} <em>ل.س</em></b>
        </div>

        {can('debts.edit') && (
          <button type="button" className="btn primary block" onClick={() => setShowForm(s => !s)}>
            {showForm ? 'إخفاء' : '＋ شخص جديد'}
          </button>
        )}

        {showForm && (
          <form className="form" onSubmit={create} style={{ marginTop: 12 }}>
            <label className="field">
              <span>اسم الشخص</span>
              <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="مثال: أبو محمد" required />
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
            <label className="field">
              <span>ملاحظة</span>
              <input value={form.note} onChange={e => setForm({ ...form, note: e.target.value })} placeholder="اختياري" />
            </label>
            <button className="btn primary block" disabled={busy}>
              {busy ? 'جارٍ الحفظ…' : 'حفظ الشخص'}
            </button>
          </form>
        )}
      </section>

      <section className="list-section">
        <div className="search-bar">
          <SearchIcon className="search-ico" />
          <input placeholder="ابحث بالاسم أو الهاتف" value={search} onChange={e => setSearch(e.target.value)} />
        </div>

        {filtered.length === 0 ? (
          <div className="empty-state">لا يوجد أشخاص.</div>
        ) : (
          <div className="debt-list">
            {filtered.map(c => (
              <button key={c._id} type="button" className="debt-item" onClick={() => openPerson(c._id)}>
                <div className="debt-main">
                  <b>{c.name}</b>
                  <small>{c.phone || 'بدون هاتف'}{c.balance > 0 ? ` • عليه ${fmt(c.balance)} ل.س` : ''}</small>
                </div>
                <span className={`debt-balance ${c.balance > 0 ? 'owes' : 'clear'}`}>
                  {c.balance > 0 ? fmt(c.balance) : 'مسدَّد'}
                </span>
              </button>
            ))}
          </div>
        )}
      </section>

      {openId && (
        <div className="sheet-overlay" onClick={() => setOpenId(null)}>
          <div className="sheet" onClick={e => e.stopPropagation()}>
            <div className="sheet-head">
              <div>
                <h3>{detail?.name || '…'}</h3>
                <small className="muted">{detail?.phone || 'بدون هاتف'}</small>
              </div>
              <button type="button" className="icon-btn ghost" onClick={() => setOpenId(null)} aria-label="إغلاق">
                <CloseIcon />
              </button>
            </div>

            <div className="debt-total">
              <small>الرصيد الحالي</small>
              <b className={detail?.balance > 0 ? 'owes' : 'clear'}>
                {fmt(detail?.balance)} <em>ل.س</em>
              </b>
            </div>

            {detail?.initialBalance > 0 && (
              <small className="hint">يشمل رصيداً مسبقاً قدره {fmt(detail.initialBalance)} ل.س</small>
            )}

            {can('debts.edit') && (
              <div className="seg">
                <button type="button" className={move.type === 'debit' ? 'active' : ''} onClick={() => setMove({ ...move, type: 'debit' })}>
                  دين جديد
                </button>
                <button type="button" className={move.type === 'credit' ? 'active' : ''} onClick={() => setMove({ ...move, type: 'credit' })}>
                  تسديد
                </button>
              </div>
            )}

            {can('debts.edit') && (
              <>
                <div className="form-grid">
                  <label className="field">
                    <span>المبلغ</span>
                    <input type="number" step="any" inputMode="decimal" value={move.amount} onChange={e => setMove({ ...move, amount: e.target.value })} placeholder="0" />
                  </label>
                  <label className="field">
                    <span>ملاحظة</span>
                    <input value={move.note} onChange={e => setMove({ ...move, note: e.target.value })} placeholder="اختياري" />
                  </label>
                </div>

                <button className="btn primary block" disabled={busy || !Number(move.amount)} onClick={saveMove}>
                  {move.type === 'debit' ? 'إضافة إلى الدين' : 'تسجيل التسديد'}
                </button>
              </>
            )}

            <h4 className="sheet-sub">كشف الحساب</h4>
            {!detail?.movements?.length ? (
              <div className="empty-state">لا توجد حركات.</div>
            ) : (
              <ul className="record-list">
                {detail.movements.map(m => (
                  <li key={m._id} className="record-item">
                    <div className="record-main">
                      <b>{m.type === 'debit' ? 'دين' : 'تسديد'} • {fmt(m.amount)} ل.س</b>
                      <small>{dateFmt(m.date)}{m.note ? ` • ${m.note}` : ''}</small>
                    </div>
                    <div className="record-side">
                      <span className={`amount ${m.type === 'debit' ? 'owes' : 'clear'}`}>
                        {m.type === 'debit' ? '+' : '−'}{fmt(m.amount)}
                      </span>
                      {can('debts.edit') && (
                        <button type="button" className="icon-btn danger-ghost" onClick={() => removeMove(m._id)} aria-label="حذف الحركة">
                          <TrashIcon />
                        </button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}

            {can('debts.edit') && (
              <button type="button" className="btn danger sm block" onClick={removePerson} style={{ marginTop: 12 }}>
                <TrashIcon /> حذف الشخص
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
