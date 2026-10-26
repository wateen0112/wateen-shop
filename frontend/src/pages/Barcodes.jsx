import React, { useEffect, useState } from 'react';
import JsBarcode from 'jsbarcode';
import { jsPDF } from 'jspdf';
import { generateBarcodes, generateMissingBarcodes, getNoBarcode, getProducts } from '../api';
import { useAuth } from '../context/AuthContext';
import { PrintIcon, WandIcon } from '../components/Icons';
import { barcodeFormat, isValidBarcode } from '../lib/barcode';

// شبكة باركودات PDF: اختر منتجات (بدون باركود تولّد لها، أو أي منتج لإعادة طباعته) واطبع شبكة
export default function Barcodes() {
  const { can } = useAuth();
  const [noBarcode, setNoBarcode] = useState([]);
  const [products, setProducts] = useState([]);
  const [selected, setSelected] = useState(new Set());
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);

  const refresh = async () => {
    setNoBarcode(await getNoBarcode());
    setProducts(await getProducts());
  };

  useEffect(() => {
    refresh();
  }, []);

  const toggle = (id) => {
    const s = new Set(selected);
    s.has(id) ? s.delete(id) : s.add(id);
    setSelected(s);
  };

  // توليد تلقائي لكل الأصناف التي بلا باركود صالح
  const generateAll = async () => {
    setBusy(true);
    try {
      const res = await generateMissingBarcodes();
      const created = res.filter(r => r.generated);
      setMsg({
        type: 'success',
        text: created.length ? `تم توليد ${created.length} باركود صالح` : 'كل الأصناف لديها باركود صالح',
      });
      setSelected(new Set());
      await refresh();
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || 'تعذّر التوليد' });
    } finally {
      setBusy(false);
    }
  };

  const makePdf = async (list, generate) => {
    let items = list.filter(x => selected.has(x._id));
    if (generate && items.length) {
      const gen = await generateBarcodes(items.map(x => x._id));
      items = gen.map(g => ({ ...g, _id: g.id }));
    }
    if (!items.length) return;

    setBusy(true);
    try {
      const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
      const cols = 3;
      const rows = 8;
      const cw = 65;
      const ch = 33;
      let x = 5;
      let y = 5;
      let count = 0;

      for (const item of items) {
        // Create a canvas for this label
        const labelCanvas = document.createElement('canvas');
        labelCanvas.width = 600;
        labelCanvas.height = 300;
        const ctx = labelCanvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, 600, 300);
        
        // Draw barcode
        const barcodeCanvas = document.createElement('canvas');
        try {
          JsBarcode(barcodeCanvas, item.barcode, {
            format: barcodeFormat(item.barcode),
            width: 3,
            height: 80,
            displayValue: true,
            fontSize: 28,
            margin: 10,
            textMargin: 8,
            font: 'Arial, sans-serif',
          });
        } catch {
          JsBarcode(barcodeCanvas, item.barcode, {
            width: 3,
            height: 80,
            displayValue: true,
            fontSize: 28,
            margin: 10,
            textMargin: 8,
            font: 'Arial, sans-serif',
          });
        }
        
        // Draw barcode centered
        ctx.drawImage(barcodeCanvas, 50, 60, 500, 140);
        
        // Draw item name centered at top
        ctx.fillStyle = '#000000';
        ctx.font = 'bold 32px Arial, "Tahoma", sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        const name = String(item.name || '').replace(/\s+/g, ' ').trim();
        const shortName = name.length > 45 ? name.slice(0, 42) + '...' : name;
        ctx.fillText(shortName, 300, 15);
        
        const imgData = labelCanvas.toDataURL('image/png');
        pdf.addImage(imgData, 'PNG', x, y, cw, ch);
        x += cw;
        if (++count % cols === 0) {
          x = 5;
          y += ch;
        }
        if (count % (cols * rows) === 0 && count < items.length) {
          pdf.addPage();
          x = 5;
          y = 5;
        }
      }
      pdf.save('barcodes.pdf');
      setNoBarcode(await getNoBarcode());
      setSelected(new Set());
      setMsg({ type: 'success', text: `تم إنشاء ملف PDF لـ ${items.length} باركود` });
    } catch (e2) {
      setMsg({ type: 'error', text: e2.response?.data?.error || e2.message || 'تعذّر إنشاء PDF' });
    } finally {
      setBusy(false);
    }
  };

  const Section = ({ title, subtitle, list, generate, bulk }) => (
    <section className="card">
      <div className="card-head">
        <div>
          <h2>{title}</h2>
          <p className="muted">{subtitle}</p>
        </div>
        <span className="count">{list.length}</span>
      </div>

      {list.length === 0 ? (
        <div className="empty-state">لا يوجد أصناف.</div>
      ) : (
        <ul className="select-list">
          {list.map(p => (
            <li key={p._id}>
              <label className={`select-item ${selected.has(p._id) ? 'checked' : ''}`}>
                <input type="checkbox" checked={selected.has(p._id)} onChange={() => toggle(p._id)} />
                <span className="checkmark" />
                <span className="select-text">
                  <b>{p.name}</b>
                  <small>{p.barcode ? p.barcode : 'سيُولّد باركود جديد'}</small>
                </span>
              </label>
            </li>
          ))}
        </ul>
      )}

      {bulk && can('barcodes.manage') && (
        <button className="btn secondary block" disabled={busy} onClick={generateAll} style={{ marginTop: 12 }}>
          <WandIcon /> {busy ? 'جارٍ التوليد…' : 'توليد تلقائي لكل الأصناف بلا باركود صالح'}
        </button>
      )}

      <button
        className="btn primary block"
        disabled={busy || !selected.size || (generate && !can('barcodes.manage'))}
        onClick={() => makePdf(list, generate)}
        style={{ marginTop: 12 }}
      >
        <PrintIcon /> {busy ? 'جارٍ التوليد…' : `توليد وطباعة PDF (${selected.size})`}
      </button>
    </section>
  );

  return (
    <div className="page">
      {msg && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      <Section
        title="أصناف بدون باركود صالح"
        subtitle="تُولَّد لها باركودات EAN-13 داخلية صالحة للقراءة"
        list={noBarcode}
        generate
        bulk
      />
      <Section
        title="إعادة طباعة باركودات"
        subtitle="اختر الأصناف الموجودة لإعادة طباعتها"
        list={products.filter(p => isValidBarcode(p.barcode))}
        generate={false}
      />
    </div>
  );
}
