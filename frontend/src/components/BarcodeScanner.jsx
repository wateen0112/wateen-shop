import React, { useEffect, useRef, useState } from 'react';
import { BrowserMultiFormatReader } from '@zxing/browser';

export default function BarcodeScanner({ onDetected, onClose }) {
  const videoRef = useRef(null);
  const controlsRef = useRef(null);
  const trackRef = useRef(null);
  const onDetectedRef = useRef(onDetected);
  const [error, setError] = useState(null);
  const [starting, setStarting] = useState(true);
  const [zoom, setZoom] = useState(1);
  const [zoomRange, setZoomRange] = useState({ min: 1, max: 1, step: 0.1 });
  const [hasZoom, setHasZoom] = useState(false);
  const [torch, setTorch] = useState(false);
  const [hasTorch, setHasTorch] = useState(false);
  const [focusSupported, setFocusSupported] = useState(false);

  useEffect(() => { onDetectedRef.current = onDetected; }, [onDetected]);

  const applyZoom = async (value) => {
    const track = trackRef.current;
    if (!track) return;
    try {
      await track.applyConstraints({ advanced: [{ zoom: Number(value) }] });
      setZoom(Number(value));
    } catch {}
  };

  const toggleTorch = async () => {
    const track = trackRef.current;
    if (!track) return;
    try {
      await track.applyConstraints({ advanced: [{ torch: !torch }] });
      setTorch(!torch);
    } catch {}
  };

  const focus = async () => {
    const track = trackRef.current;
    if (!track) return;
    try {
      await track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] }).catch(() => {});
      await track.applyConstraints({ advanced: [{ focusMode: 'manual', focusDistance: 0 }] }).catch(() => {});
      await track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] }).catch(() => {});
    } catch {}
  };

  useEffect(() => {
    const reader = new BrowserMultiFormatReader();
    let cancelled = false;
    (async () => {
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('جهازك لا يدعم الوصول للكاميرا. يرجى استخدام HTTPS أو localhost.');
        setStarting(false);
        return;
      }
      try {
        const controls = await reader.decodeFromVideoDevice(undefined, videoRef.current, (result) => {
          if (cancelled || !result) return;
          cancelled = true;
          navigator.vibrate?.(60);
          controlsRef.current?.stop();
          onDetectedRef.current(result.getText());
        });
        if (cancelled) { controls.stop(); return; }
        controlsRef.current = controls;
        setStarting(false);
        const stream = videoRef.current?.srcObject;
        const track = stream?.getVideoTracks?.()[0];
        if (track) {
          trackRef.current = track;
          const caps = track.getCapabilities?.() || {};
          if (caps.zoom) {
            setHasZoom(true);
            setZoomRange({ min: caps.zoom.min || 1, max: caps.zoom.max || 1, step: caps.zoom.step || 0.1 });
            const settings = track.getSettings?.() || {};
            setZoom(settings.zoom || caps.zoom.min || 1);
          }
          if (caps.torch) setHasTorch(true);
          if (caps.focusMode || caps.focusDistance) setFocusSupported(true);
        }
      } catch (e) {
        setStarting(false);
        if (e?.name === 'NotAllowedError') setError('تم رفض إذن الكاميرا. يرجى السماح بالوصول للكاميرا من إعدادات المتصفح.');
        else if (e?.name === 'NotFoundError') setError('لا توجد كاميرا متاحة على هذا الجهاز.');
        else setError('حدث خطأ أثناء تشغيل الكاميرا: ' + (e?.message || e));
      }
    })();
    return () => {
      cancelled = true;
      try { controlsRef.current?.stop(); } catch {}
      const stream = videoRef.current?.srcObject;
      stream?.getTracks?.().forEach(t => t.stop());
    };
  }, []);

  return (
    <div className="scanner-overlay" role="dialog" aria-modal="true">
      <div className="scanner-box">
        <div className="scanner-head">
          <h3>مسح الباركود بالكاميرا</h3>
          <button type="button" className="btn secondary" onClick={onClose}>إغلاق</button>
        </div>
        {error ? (
          <div className="msg error">{error}</div>
        ) : (
          <div className="scanner-video-wrap">
            <video ref={videoRef} className="scanner-video" muted playsInline />
            <div className="scanner-frame" />
            {starting && <div className="scanner-hint">جاري تشغيل الكاميرا...</div>}
          </div>
        )}
        {!error && (
          <div className="scanner-controls">
            {hasZoom && (
              <label className="scanner-control">
                <span>تكبير</span>
                <input type="range" min={zoomRange.min} max={zoomRange.max} step={zoomRange.step} value={zoom} onChange={e => applyZoom(e.target.value)} />
                <small>{zoom.toFixed(1)}x</small>
              </label>
            )}
            <div className="scanner-control-row">
              {hasTorch && <button type="button" className="btn secondary sm" onClick={toggleTorch}>{torch ? 'إيقاف الفلاش' : 'تشغيل الفلاش'}</button>}
              {focusSupported && <button type="button" className="btn secondary sm" onClick={focus}>تركيز تلقائي</button>}
            </div>
          </div>
        )}
        <p className="scanner-hint">وجّه الكاميرا نحو الباركود ليتم التعرف عليه تلقائياً.</p>
      </div>
    </div>
  );
}
