import React, { useEffect, useRef, useState } from 'react';
import JsBarcode from 'jsbarcode';
import { barcodeFormat } from '../lib/barcode';

// معاينة الباركود مباشرة أثناء الكتابة أو المسح
export default function BarcodePreview({ value, height = 64 }) {
  const svgRef = useRef(null);
  const [invalid, setInvalid] = useState(false);
  const code = String(value || '').trim();

  useEffect(() => {
    const svg = svgRef.current;
    if (!svg) return;
    svg.innerHTML = '';
    if (!code) { setInvalid(false); return; }
    try {
      JsBarcode(svg, code, {
        format: barcodeFormat(code),
        width: 2,
        height,
        displayValue: true,
        fontSize: 15,
        font: 'monospace',
        textMargin: 6,
        margin: 8,
        lineColor: '#0f172a',
        background: '#ffffff',
      });
      setInvalid(false);
    } catch {
      setInvalid(true);
    }
  }, [code, height]);

  if (!code) {
    return (
      <div className="barcode-preview empty">
        <span className="barcode-placeholder">سيظهر شكل الباركود هنا</span>
        <small>امسح بالكاميرا أو اكتب الرقم</small>
      </div>
    );
  }

  return (
    <div className="barcode-preview">
      <svg ref={svgRef} className="barcode-svg" style={{ display: invalid ? 'none' : 'block' }} />
      {invalid && <span className="barcode-placeholder error">تعذّر عرض هذا الباركود</span>}
      <small className="barcode-caption">{code}</small>
    </div>
  );
}
