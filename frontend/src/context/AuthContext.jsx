import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { getMe, login as apiLogin, logoutSession } from '../api';
import { clearSession, getStoredUser, getToken, hasPermission, setSession } from '../lib/auth';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(getStoredUser);
  const [booting, setBooting] = useState(!!getToken());

  // التحقق من صلاحية الجلسة عند الإقلاع
  useEffect(() => {
    if (!getToken()) {
      setBooting(false);
      return;
    }
    getMe()
      .then(u => {
        setSession(getToken(), u);
        setUser(u);
      })
      .catch(() => {
        clearSession();
        setUser(null);
      })
      .finally(() => setBooting(false));
  }, []);

  // حدث انتهاء الجلسة من axios
  useEffect(() => {
    const onUnauthorized = () => setUser(null);
    window.addEventListener('wateen:unauthorized', onUnauthorized);
    return () => window.removeEventListener('wateen:unauthorized', onUnauthorized);
  }, []);

  const login = useCallback(async (username, password) => {
    const data = await apiLogin(username, password);
    setSession(data.token, data.user);
    setUser(data.user);
    return data.user;
  }, []);

  const logout = useCallback(() => {
    // نسجّل الخروج في سجل العمليات قبل مسح الجلسة (لا نعطّل الخروج إذا فشل)
    logoutSession().catch(() => {});
    clearSession();
    setUser(null);
  }, []);

  const refresh = useCallback(async () => {
    const u = await getMe();
    setSession(getToken(), u);
    setUser(u);
    return u;
  }, []);

  const can = useCallback(key => hasPermission(user, key), [user]);

  const value = useMemo(
    () => ({ user, booting, login, logout, refresh, can, isAdmin: user?.role === 'admin' }),
    [user, booting, login, logout, refresh, can]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
