import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { registerSW } from 'virtual:pwa-register';

const updateSW = registerSW({
  onNeedRefresh() {
    const toast = document.createElement('div');
    toast.textContent = 'يوجد تحديث جديد';
    Object.assign(toast.style, {
      position: 'fixed', bottom: '80px', right: '16px', background: '#0f7b3e', color: '#fff',
      padding: '10px 16px', borderRadius: '8px', zIndex: 9999, display: 'flex', gap: '12px', alignItems: 'center', fontFamily: 'inherit', direction: 'rtl'
    });
    const btn = document.createElement('button');
    btn.textContent = 'إعادة تشغيل';
    Object.assign(btn.style, { background: '#fff', color: '#0f7b3e', border: 'none', borderRadius: '6px', padding: '6px 10px', cursor: 'pointer' });
    btn.onclick = () => updateSW(true);
    toast.appendChild(btn);
    document.body.appendChild(toast);
  },
  onOfflineReady() {
    console.log('App ready to work offline');
  }
});

createRoot(document.getElementById('root')).render(<App />);
