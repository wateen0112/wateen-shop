import axios from 'axios';
import { clearSession, getToken } from './lib/auth';

const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' });

// إرفاق توكن الجلسة مع كل طلب
api.interceptors.request.use(config => {
  const token = getToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// انتهاء الجلسة → تنظيف وتحويل لصفحة الدخول
api.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) {
      clearSession();
      window.dispatchEvent(new Event('wateen:unauthorized'));
    }
    return Promise.reject(err);
  }
);

export const login = (username, password) => api.post('/auth/login', { username, password }).then(r => r.data);
export const getMe = () => api.get('/auth/me').then(r => r.data);
export const getPermissionCatalog = () => api.get('/auth/permissions').then(r => r.data);
export const changePassword = (currentPassword, newPassword) =>
  api.post('/auth/change-password', { currentPassword, newPassword }).then(r => r.data);
export const logoutSession = () => api.post('/auth/logout').then(r => r.data);

export const getAuditLog = (params) => api.get('/audit', { params }).then(r => r.data);
export const getAuditMeta = () => api.get('/audit/meta').then(r => r.data);
export const getAuditEntry = (id) => api.get(`/audit/${id}`).then(r => r.data);
export const exportAuditCsv = (params) =>
  api.get('/audit/export.csv', { params, responseType: 'blob' }).then(r => r.data);

export const getUsers = () => api.get('/users').then(r => r.data);
export const addUser = (data) => api.post('/users', data).then(r => r.data);
export const updateUser = (id, data) => api.put(`/users/${id}`, data).then(r => r.data);
export const deleteUser = (id) => api.delete(`/users/${id}`).then(r => r.data);

export const getProducts = (search) => api.get('/products', { params: { search } }).then(r => r.data);
export const addProduct = (data) => api.post('/products', data).then(r => r.data);
export const updateProduct = (id, data) => api.put(`/products/${id}`, data).then(r => r.data);
export const deleteProduct = (id) => api.delete(`/products/${id}`).then(r => r.data);
export const addSalePrice = (id, price, note) => api.post(`/products/${id}/sale-price`, { price, note }).then(r => r.data);
export const getNoBarcode = () => api.get('/products/no-barcode').then(r => r.data);
export const generateBarcodes = (ids, all = false) => api.post('/products/generate-barcodes', { ids, all }).then(r => r.data);
export const generateMissingBarcodes = () => generateBarcodes([], true);

export const getUnits = () => api.get('/units').then(r => r.data);
export const addUnit = (data) => api.post('/units', data).then(r => r.data);
export const updateUnit = (id, data) => api.put(`/units/${id}`, data).then(r => r.data);
export const deleteUnit = (id) => api.delete(`/units/${id}`).then(r => r.data);

// target: نص (باركود أو اسم صنف) أو كائن { barcode } / { name } / { productId }
export const makeSale = (target, quantity, extra = {}) => {
  const body = typeof target === 'string'
    ? { barcode: target, name: target }
    : { ...target };
  return api.post('/sales', { ...body, quantity, ...extra }).then(r => r.data);
};
export const getProfit = () => api.get('/sales/profit').then(r => r.data);

export const getCustomers = () => api.get('/customers').then(r => r.data);
export const getCustomer = (id) => api.get(`/customers/${id}`).then(r => r.data);
export const addCustomer = (data) => api.post('/customers', data).then(r => r.data);
export const updateCustomer = (id, data) => api.put(`/customers/${id}`, data).then(r => r.data);
export const deleteCustomer = (id) => api.delete(`/customers/${id}`).then(r => r.data);
export const addDebt = (customerId, data) => api.post(`/customers/${customerId}/debt`, data).then(r => r.data);
export const deleteDebt = (customerId, debtId) => api.delete(`/customers/${customerId}/debt/${debtId}`).then(r => r.data);

export const getCashbox = () => api.get('/cashbox').then(r => r.data);
export const setCashboxInitial = (initialBalance) => api.put('/cashbox', { initialBalance }).then(r => r.data);

export const getExpenses = () => api.get('/expenses').then(r => r.data);
export const addExpense = (data) => api.post('/expenses', data).then(r => r.data);
export const deleteExpense = (id) => api.delete(`/expenses/${id}`).then(r => r.data);
export const getExpensesTotal = () => api.get('/expenses/total').then(r => r.data);

export const getInventorySheet = () => api.get('/inventory/sheet').then(r => r.data);
export const saveInventory = (items, note) => api.post('/inventory', { items, note }).then(r => r.data);
export const getInventories = () => api.get('/inventory').then(r => r.data);

export const getRate = () => api.get('/rate').then(r => r.data);
