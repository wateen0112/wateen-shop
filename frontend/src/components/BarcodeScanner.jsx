import React, { useEffect, useRef, useState } from 'react';
import { BrowserMultiFormatReader } from '@zxing/browser';

// مسح باركود مباشر من كاميرا الجهاز — بدون رفع ملفات
export default function BarcodeScanner({ onDetected, onClose }) {
  const videoRef = useRef(null);
  const controlsRef = useRef(null);
  const onDetectedRef = useRef(onDetected);
  const [error, setError] = useState(null);
  const [starting, setStarting] = useState(true);

  useEffect(() => {
    onDetectedRef.current = onDetected;
  }, [onDetected]);

  useEffect(() => {
    const reader = new BrowserMultiFormatReader();
    let cancelled = false;

    (async () => {
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('المتصفح لا يدعم الكاميرا. استخدم HTTPS أو localhost.');
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
        if (cancelled) {
          controls.stop();
          return;
        }
        controlsRef.current = controls;
        setStarting(false);
      } catch (e) {
        setStarting(false);
        if (e?.name === 'NotAllowedError') setError('تم رفض إذن الكاميرا. اسمح بالوصول للكاميرا للمتصفح.');
        else if (e?.name === 'NotFoundError') setError('لا توجد كاميرا متاحة على هذا الجهاز.');
        else setError('تعذّر تشغيل الكاميرا: ' + (e?.message || e));
      }
    })();

    return () => {
      cancelled = true;
      try { controlsRef.current?.stop(); } catch { /* ignore */ }
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
            {starting && <div className="scanner-hint">جارٍ تشغيل الكاميرا…</div>}
          </div>
        )}

        <p className="scanner-hint">وجّه الكاميرا نحو الباركود — يُقرأ تلقائياً بدون رفع صور.</p>
      </div>
    </div>
  );
}
