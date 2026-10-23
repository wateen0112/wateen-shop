import React, { useEffect, useState } from 'react';
import { addProduct, addSalePrice, deleteProduct, generateBarcodes, getProducts, getUnits, updateProduct } from '../api';
import { useAuth } from '../context/AuthContext';
import BarcodeScanner from '../components/BarcodeScanner';
import BarcodePreview from '../components/BarcodePreview';
import { CameraIcon, CloseIcon, SearchIcon, TrashIcon, WandIcon } from '../components/Icons';
import { isValidBarcode } from '../lib/barcode';

const empty = {
  name: '', barcode: '', purchaseUnit: '', saleUnit: '', conversion: 1,
  quantity: 0, purchasePrice: '', purchaseCurrency: 'SYP', salePrice: '',
};

export default function Products({ rate }) {
  const { can } = useAuth();
  const [products, setProducts] = useState([]);
  const [units, setUnits] = useState([]);
  const [form, setForm] = useState(empty);
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState(null);
  const [created, setCreated] = useState(null); // باركود مُولّد تلقائياً عند الإضافة
  const [editQty, setEditQty] = useState({});
  const [scanTarget, setScanTarget] = useState(null); // 'form' | 'search'

  const load = () => getProducts(search).then(setProducts);
  useEffect(() => { load(); }, [search]);
  useEffect(() => {
    getUnits().then(list => {
      setUnits(list);
      const names = list.map(u => u.name);
      const pick = (want) => names.includes(want) ? want : (names.includes('قطعة') ? 'قطعة' : names[0] || '');
      setForm(f => ({
        ...f,
        purchaseUnit: f.purchaseUnit || pick('كرتون'),
        saleUnit: f.saleUnit || pick('قطعة'),
      }));
    }).catch(() => setUnits([]));
  }, []);

  const handleScan = (code) => {
    if (scanTarget === 'form') setForm(f => ({ ...f, barcode: code }));
    else setSearch(code);
    setScanTarget(null);
  };

  const submit = async (e) => {
    e.preventDefault();
    try {
      const res = await addProduct(form);
      setForm(f => ({ ...empty, purchaseUnit: f.purchaseUnit, saleUnit: f.saleUnit, purchaseCurrency: f.purchaseCurrency }));
      setCreated(res.barcodeGenerated ? { name: form.name, barcode: res.barcode } : null);
      setMsg({
        type: 'success',
        text: res.barcodeGenerated ? 'تمت إضافة الصنف مع باركود مُولّد تلقائياً' : 'تمت إضافة الصنف',
      });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّرت الإضافة' });
    }
  };

  const fixBarcode = async (p) => {
    try {
      const res = await generateBarcodes([p._id]);
      setMsg({ type: 'success', text: `تم توليد باركود ${res?.[0]?.barcode || ''} للصنف ${p.name}` });
      load();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر توليد الباركود' });
    }
  };

  const changeQty = async (p) => {
    await updateProduct(p._id, { quantity: Number(editQty[p._id] ?? p.quantity) });
    setEditQty(q => ({ ...q, [p._id]: '' }));
    load();
  };

  const changeConversion = async (p) => {
    const v = Number(editQty['cv' + p._id]);
    if (!(v > 0)) {
      setMsg({ type: 'error', text: 'معامل التحويل يجب أن يكون أكبر من صفر' });
      return;
    }
    await updateProduct(p._id, { conversion: v });
    setEditQty(q => ({ ...q, ['cv' + p._id]: '' }));
    load();
  };

  const newSalePrice = async (p) => {
    const v = editQty['sp' + p._id];
    if (!v) return;
    await addSalePrice(p._id, Number(v));
    setEditQty(q => ({ ...q, ['sp' + p._id]: '' }));
    load();
  };

  const fmt = (n) => Number(n).toLocaleString('ar-SY');
  const fmt2 = (n) => Number(n).toLocaleString('ar-SY', { maximumFractionDigits: 2 });

  // تكلفة وحدة البيع الواحدة من بيانات الفورم
  const formConversion = Number(form.conversion) > 0 ? Number(form.conversion) : 0;
  const formPrice = Number(form.purchasePrice);
  const formUnitCost = formConversion && Number.isFinite(formPrice) ? formPrice / formConversion : null;

  return (
    <div className="page">
      {can('products.edit') && (
      <section className="card">
        <div className="card-head">
          <div>
            <h2>صنف جديد</h2>
            <p className="muted">أضف البيانات وامسح الباركود</p>
          </div>
        </div>

        {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

        {created && (
          <div className="generated-card">
            <div className="generated-head">
              <b><WandIcon /> تم توليد باركود تلقائي</b>
              <button type="button" className="icon-btn ghost" onClick={() => setCreated(null)} aria-label="إغلاق">
                <CloseIcon />
              </button>
            </div>
            <BarcodePreview value={created.barcode} height={54} />
            <small className="hint">الصنف: {created.name} — يمكنك طباعته من صفحة «الباركود»</small>
          </div>
        )}

        <form className="form" onSubmit={submit}>
          <label className="field">
            <span>اسم الصنف</span>
            <input placeholder="مثال: شاي العروسة" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} required />
          </label>

          <div className="field">
            <span>الباركود</span>
            <div className="input-with-action">
              <input
                placeholder="امسح بالكاميرا أو اكتب الرقم"
                value={form.barcode}
                onChange={e => setForm({ ...form, barcode: e.target.value })}
              />
              <button type="button" className="icon-btn" onClick={() => setScanTarget('form')} aria-label="مسح الباركود بالكاميرا">
                <CameraIcon />
              </button>
            </div>
            {form.barcode.trim() && !isValidBarcode(form.barcode) ? (
              <small className="hint warn">هذا الرقم ليس باركوداً صالحاً — سيُستبدل بباركود تلقائي عند الحفظ</small>
            ) : (
              <small className="hint">اتركه فارغاً وسيُولّد باركود EAN-13 صالح تلقائياً</small>
            )}
          </div>

          <BarcodePreview value={form.barcode} />

          <div className="form-grid">
            <label className="field">
              <span>وحدة الشراء</span>
              <select value={form.purchaseUnit} onChange={e => setForm({ ...form, purchaseUnit: e.target.value })} required>
                {units.length === 0 && <option value="">— لا توجد وحدات —</option>}
                {units.map(u => <option key={u._id} value={u.name}>{u.name}</option>)}
              </select>
            </label>
            <label className="field">
              <span>وحدة البيع</span>
              <select value={form.saleUnit} onChange={e => setForm({ ...form, saleUnit: e.target.value })} required>
                {units.length === 0 && <option value="">— لا توجد وحدات —</option>}
                {units.map(u => <option key={u._id} value={u.name}>{u.name}</option>)}
              </select>
            </label>
            <label className="field">
              <span>معامل التحويل</span>
              <input
                type="number" step="any" min="0.0001" inputMode="decimal"
                placeholder="1"
                value={form.conversion}
                onChange={e => setForm({ ...form, conversion: e.target.value })}
                required
              />
              <small className="hint">كم {form.saleUnit || 'وحدة بيع'} في {form.purchaseUnit || 'وحدة شراء'} واحدة</small>
            </label>
            <label className="field">
              <span>الكمية ({form.saleUnit || 'وحدة البيع'})</span>
              <input type="number" inputMode="numeric" value={form.quantity} onChange={e => setForm({ ...form, quantity: e.target.value })} />
            </label>
            <label className="field">
              <span>سعر شراء {form.purchaseUnit || 'الوحدة'}</span>
              <input type="number" step="any" inputMode="decimal" placeholder="0" value={form.purchasePrice} onChange={e => setForm({ ...form, purchasePrice: e.target.value })} required />
            </label>
            <label className="field">
              <span>عملة الشراء</span>
              <select value={form.purchaseCurrency} onChange={e => setForm({ ...form, purchaseCurrency: e.target.value })}>
                <option value="SYP">ليرة سورية</option>
                <option value="USD">دولار</option>
              </select>
            </label>
            <label className="field span-2">
              <span>سعر البيع ({form.saleUnit || 'وحدة البيع'}) — ل.س</span>
              <input type="number" step="any" inputMode="decimal" placeholder="اتركه فارغاً إن لم تحدده بعد" value={form.salePrice} onChange={e => setForm({ ...form, salePrice: e.target.value })} />
            </label>
          </div>

          {formUnitCost !== null && (
            <div className="cost-preview">
              <span>تكلفة {form.saleUnit || 'وحدة البيع'} الواحدة</span>
              <b>
                {fmt2(formUnitCost)} {form.purchaseCurrency}
                {form.purchaseCurrency === 'USD' && rate ? ` ≈ ${fmt(formUnitCost * rate)} ل.س` : ''}
              </b>
            </div>
          )}

          <button className="btn primary block">إضافة الصنف</button>
        </form>
      </section>
      )}

      <section className="list-section">
        <div className="section-head">
          <h2>الأصناف <span className="count">{products.length}</span></h2>
        </div>

        <div className="search-bar">
          <SearchIcon className="search-ico" />
          <input placeholder="ابحث بالاسم أو الباركود" value={search} onChange={e => setSearch(e.target.value)} />
          <button type="button" className="icon-btn ghost" onClick={() => setScanTarget('search')} aria-label="مسح للبحث">
            <CameraIcon />
          </button>
        </div>

        <div className="product-list">
          {products.length === 0 && <div className="empty-state">لا توجد أصناف مطابقة</div>}
          {products.map(p => {
            const factor = Number(p.conversion) > 0 ? Number(p.conversion) : 1;
            const unitCost = p.unitCost != null ? Number(p.unitCost) : Number(p.purchasePrice) / factor;
            const saleUnit = p.saleUnit || p.unit || 'قطعة';
            const buyUnit = p.purchaseUnit || saleUnit;
            return (
            <article className="product-card" key={p._id}>
              <div className="product-top">
                <div className="product-info">
                  <h3>{p.name}</h3>
                  <div className="product-tags">
                    {isValidBarcode(p.barcode) ? (
                      <span className="barcode-text">{p.barcode}</span>
                    ) : (
                      <span className="pill warn">{p.barcode ? 'باركود غير صالح' : 'بدون باركود'}</span>
                    )}
                    <span className="pill">{saleUnit}</span>
                    {factor !== 1 && <span className="pill warn">{buyUnit} = {fmt2(factor)} {saleUnit}</span>}
                  </div>
                </div>
                <div className="qty-badge">
                  <span>{p.quantity}</span>
                  <small>{saleUnit}</small>
                </div>
              </div>

              <div className="product-prices">
                <div>
                  <small>شراء {buyUnit}</small>
                  <b>{fmt(p.purchasePrice)} {p.purchaseCurrency}</b>
                </div>
                <div>
                  <small>تكلفة {saleUnit}</small>
                  <b>{fmt2(unitCost)} {p.purchaseCurrency}</b>
                </div>
                <div>
                  <small>سعر البيع</small>
                  <b>{p.currentSalePrice ? `${fmt(p.currentSalePrice)} ل.س` : '—'}</b>
                </div>
                <div>
                  <small>معامل التحويل</small>
                  <b>{fmt2(factor)}</b>
                </div>
                {p.purchaseCurrency === 'USD' && rate ? (
                  <div className="full">
                    <small>تكلفة {saleUnit} بالليرة</small>
                    <b>{fmt2(unitCost * rate)} ل.س</b>
                  </div>
                ) : null}
              </div>

              {can('products.edit') && (
                <div className="actions-grid">
                  <div className="mini-field">
                    <input type="number" inputMode="numeric" placeholder={`الكمية (${saleUnit})`} value={editQty[p._id] ?? ''} onChange={e => setEditQty({ ...editQty, [p._id]: e.target.value })} />
                    <button className="btn secondary sm" onClick={() => changeQty(p)}>حفظ</button>
                  </div>
                  <div className="mini-field">
                    <input type="number" step="any" inputMode="decimal" placeholder="سعر بيع جديد" value={editQty['sp' + p._id] ?? ''} onChange={e => setEditQty({ ...editQty, ['sp' + p._id]: e.target.value })} />
                    <button className="btn secondary sm" onClick={() => newSalePrice(p)}>إضافة</button>
                  </div>
                  <div className="mini-field">
                    <input type="number" step="any" min="0.0001" inputMode="decimal" placeholder="معامل التحويل" value={editQty['cv' + p._id] ?? ''} onChange={e => setEditQty({ ...editQty, ['cv' + p._id]: e.target.value })} />
                    <button className="btn secondary sm" onClick={() => changeConversion(p)}>حفظ</button>
                  </div>
                </div>
              )}

              {!isValidBarcode(p.barcode) && can('barcodes.manage') && (
                <button className="btn secondary sm block" onClick={() => fixBarcode(p)}>
                  <WandIcon /> توليد باركود لهذا الصنف
                </button>
              )}

              {can('products.edit') && (
                <button className="btn danger sm block" onClick={() => deleteProduct(p._id).then(load)}>
                  <TrashIcon /> حذف الصنف
                </button>
              )}
            </article>
            );
          })}
        </div>
      </section>

      {scanTarget && <BarcodeScanner onDetected={handleScan} onClose={() => setScanTarget(null)} />}
    </div>
  );
}
