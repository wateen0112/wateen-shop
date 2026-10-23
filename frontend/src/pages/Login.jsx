import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { StoreIcon } from '../components/Icons';

export default function Login() {
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setErr('');
    setBusy(true);
    try {
      await login(username.trim(), password);
    } catch (e2) {
      setErr(e2.response?.data?.error || 'تعذّر تسجيل الدخول');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="login-brand">
          <span className="brand-logo lg"><StoreIcon /></span>
          <h1>أبو وتين</h1>
          <p>سجّل الدخول للمتابعة</p>
        </div>

        {err && <div className="msg error">{err}</div>}

        <label className="field">
          <span>اسم المستخدم</span>
          <input
            autoCapitalize="none"
            autoCorrect="off"
            autoComplete="username"
            placeholder="admin"
            value={username}
            onChange={e => setUsername(e.target.value)}
            required
          />
        </label>

        <label className="field">
          <span>كلمة المرور</span>
          <input
            type="password"
            autoComplete="current-password"
            placeholder="••••••"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
        </label>

        <button className="btn primary block" disabled={busy}>
          {busy ? 'جارٍ الدخول...' : 'تسجيل الدخول'}
        </button>

        <small className="hint center">اطلب من الأدمن إنشاء حساب لك وتحديد صلاحياتك</small>
      </form>
    </div>
  );
}
