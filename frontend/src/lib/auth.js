const TOKEN_KEY = 'wateen_token';
const USER_KEY = 'wateen_user';

export const getToken = () => localStorage.getItem(TOKEN_KEY);

export const getStoredUser = () => {
  try {
    return JSON.parse(localStorage.getItem(USER_KEY) || 'null');
  } catch {
    return null;
  }
};

export const setSession = (token, user) => {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
};

export const clearSession = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
};

// هل يملك المستخدم صلاحية معينة؟ (الأدمن يملك كل الصلاحيات)
export const hasPermission = (user, key) => {
  if (!user) return false;
  if (user.role === 'admin') return true;
  return (user.permissions || []).includes(key);
};
