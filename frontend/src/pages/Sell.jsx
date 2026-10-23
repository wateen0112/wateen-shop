import React, { useEffect, useRef, useState } from 'react';
import { getProducts, makeSale } from '../api';
import { useAuth } from '../context/AuthContext';
import BarcodeScanner from '../components/BarcodeScanner';
import CustomerSelect from '../components/CustomerSelect';
import { CameraIcon } from '../components/Icons';

const number = (v) => Number(v || 0);

// صفحة البيع: مسح الباركود بالكاميرا (أو كتابته) أو البحث بالاسم + Enter = بيع فوري
export default function Sell({ rate }) {
  const { can } = useAuth();
  const [query, setQuery] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [log, setLog] = useState([]);
  const [msg, setMsg] = useState(null);
  const [scanning, setScanning] = useState(false);
  const [autoSell, setAutoSell] = useState(true);
  const [onCredit, setOnCredit] = useState(false);
  const [customerId, setCustomerId] = useState(null);
  const [suggestions, setSuggestions] = useState([]);
  const [searching, setSearching] = useState(false);
  const [pickOpen, setPickOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);
  const inputRef = useRef();
  const canSearch = can('products.view');

  useEffect(() => {
    const term = query.trim();
    if (!canSearch || term.length < 1) {
      setSuggestions([]);
      setSearching(false);
      return;
    }
    let alive = true;
    setSearching(true);
    const timer = setTimeout(async () => {
      try {
        const list = await getProducts(term);
        if (!alive) return;
        setSuggestions(Array.isArray(list) ? list.slice(0, 8) : []);
        setHighlight(0);
      } catch {
        if (alive) setSuggestions([]);
      } finally {
        if (alive) setSearching(false);
      }
    }, 220);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [query, canSearch]);

  const sell = async (target) => {
    if (!target) return;
    try {
      const sale = await makeSale(target, Number(quantity), onCredit ? { onCredit: true, customerId } : {});
      setLog(l => [{ ...sale, at: new Date().toLocaleTimeString('ar-SY') }, ...l]);
      setMsg({
        type: 'success',
        text: onCredit
          ? `تم البيع على الحساب — أُضيف ${Number(sale.totalSYP).toLocaleString('ar-SY')} ل.س إلى دين الشخص`
          : `تم البيع — الربح: ${Number(sale.totalProfitSYP).toLocaleString('ar-SY')} ل.س`,
      });
      setQuery('');
      setSuggestions([]);
      setPickOpen(false);
      setQuantity(1);
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر إتمام البيع' });
    }
    inputRef.current?.focus();
  };

  const sellProduct = (product) => {
    if (!product || number(product.quantity) < Number(quantity)) {
      setMsg({ type: 'error', text: product ? `الكمية غير كافية (المتاح: ${number(product.quantity)})` : 'الصنف غير متوفر' });
      return;
    }
    sell({ productId: product._id });
  };

  const submit = (e) => {
    e.preventDefault();
    const term = query.trim();
    if (!term) return;
    const picked = pickOpen && suggestions[highlight];
    if (picked) {
      sellProduct(picked);
      return;
    }
    sell(term);
  };

  const onKeyDown = (e) => {
    if (!pickOpen || suggestions.length === 0) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setHighlight(i => (i + 1) % suggestions.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setHighlight(i => (i - 1 + suggestions.length) % suggestions.length);
    } else if (e.key === 'Escape') {
      setPickOpen(false);
    }
  };

  const handleScan = (code) => {
    setScanning(false);
    setQuery(code);
    if (autoSell) sell(code);
    else requestAnimationFrame(() => inputRef.current?.focus());
  };

  const toggleCredit = (checked) => {
    setOnCredit(checked);
    if (!checked) setCustomerId(null);
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>بيع سريع</h2>
            <p className="muted">امسح الباركود أو ابحث باسم الصنف لتسجيل البيع</p>
          </div>
        </div>

        {!rate && <div className="msg error">سعر الدولار غير مضبوط — الربح للمشتريات الدولارية غير دقيق.</div>}
        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

        <button type="button" className="scan-hero" onClick={() => setScanning(true)}>
          <span className="scan-hero-ico"><CameraIcon /></span>
          <span>
            <b>مسح باركود بالكاميرا</b>
            <small>يُقرأ مباشرة بدون رفع صور</small>
          </span>
        </button>

        <form className="form" onSubmit={submit}>
          <label className="field">
            <span>الباركود أو اسم الصنف</span>
            <input
              ref={inputRef}
              className="big-input"
              placeholder="امسح الباركود أو اكتب اسم الصنف"
              value={query}
              onChange={e => {
                setQuery(e.target.value);
                setPickOpen(true);
              }}
              onFocus={() => setPickOpen(true)}
              onKeyDown={onKeyDown}
              autoFocus
              autoComplete="off"
            />
          </label>

          {pickOpen && query.trim() && canSearch && (
            <div className="suggest">
              {searching && suggestions.length === 0 && <div className="suggest-empty">جارٍ البحث…</div>}
              {!searching && suggestions.length === 0 && <div className="suggest-empty">لا يوجد صنف مطابق</div>}
              {suggestions.map((p, i) => (
                <button
                  type="button"
                  key={p._id}
                  className={`suggest-item${i === highlight ? ' active' : ''}`}
                  onMouseEnter={() => setHighlight(i)}
                  onClick={() => sellProduct(p)}
                >
                  <span className="suggest-main">
                    <b>{p.name}</b>
                    <small>{p.barcode || 'بدون باركود'} · {p.unit}</small>
                  </span>
                  <span className="suggest-side">
                    <b>{number(p.currentSalePrice).toLocaleString('ar-SY')} ل.س</b>
                    <small className={number(p.quantity) > 0 ? '' : 'out'}>{number(p.quantity) > 0 ? `متاح ${number(p.quantity)}` : 'غير متوفر'}</small>
                  </span>
                </button>
              ))}
            </div>
          )}

          <label className="field">
            <span>الكمية</span>
            <div className="stepper">
              <button type="button" className="step-btn" onClick={() => setQuantity(q => Math.max(1, Number(q) - 1))}>−</button>
              <input type="number" min="1" inputMode="numeric" value={quantity} onChange={e => setQuantity(e.target.value)} />
              <button type="button" className="step-btn" onClick={() => setQuantity(q => Number(q) + 1)}>+</button>
            </div>
          </label>

          <label className="switch-row">
            <input type="checkbox" checked={autoSell} onChange={e => setAutoSell(e.target.checked)} />
            <span>بيع تلقائي بعد المسح</span>
          </label>

          {can('debts.view') && (
            <label className="switch-row">
              <input type="checkbox" checked={onCredit} onChange={e => toggleCredit(e.target.checked)} />
              <span>بيع على الحساب (دين لشخص)</span>
            </label>
          )}

          {onCredit && can('debts.view') && (
            <div className="field">
              <span>صاحب الدين</span>
              <CustomerSelect
                value={customerId}
                onChange={setCustomerId}
                hint="اختر شخصاً أو أنشئ شخصاً جديداً — يُضاف مبلغ البيع إلى دينه"
              />
            </div>
          )}

          <button className="btn primary block">تأكيد البيع</button>
        </form>
      </section>

      <section className="card">
        <div className="section-head">
          <h2>مبيعات هذه الجلسة <span className="count">{log.length}</span></h2>
        </div>
        {log.length === 0 ? (
          <div className="empty-state">لم تُسجّل أي عملية بيع بعد</div>
        ) : (
          <ul className="sale-list">
            {log.map((s, i) => (
              <li key={i} className="sale-item">
                <div className="sale-main">
                  <b>{Number(s.salePrice).toLocaleString('ar-SY')} ل.س</b>
                  <small>{s.at} · كمية {s.quantity}{s.onCredit ? ' · على الحساب' : ''}</small>
                </div>
                <span className={`profit-chip ${s.onCredit ? 'credit' : ''}`}>
                  {s.onCredit ? 'دين' : `+${Number(s.totalProfitSYP).toLocaleString('ar-SY')}`}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      {scanning && <BarcodeScanner onDetected={handleScan} onClose={() => setScanning(false)} />}
    </div>
  );
}
