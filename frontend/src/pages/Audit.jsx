import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { exportAuditCsv, getAuditLog, getAuditMeta } from '../api';
import { CheckIcon, CloseIcon, SearchIcon, ShieldIcon } from '../components/Icons';

const EMPTY_FILTERS = { q: '', action: '', entity: '', userId: '', from: '', to: '' };

const dateFmt = new Intl.DateTimeFormat('ar-SY', {
  day: '2-digit', month: '2-digit', year: 'numeric',
  hour: '2-digit', minute: '2-digit',
});

function actionTone(action) {
  if (action === 'login.failed' || action.endsWith('.delete')) return 'danger';
  if (action.endsWith('.create') || action.endsWith('.price_add') || action.endsWith('.barcode_generate')) return 'ok';
  if (action === 'login' || action === 'logout') return '';
  return 'warn';
}

function whenLabel(value) {
  if (!value) return '—';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? '—' : dateFmt.format(d);
}

export default function Audit() {
  const [meta, setMeta] = useState({ actions: [], entities: [], users: [] });
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [err, setErr] = useState('');
  const [selected, setSelected] = useState(null);
  const timer = useRef(null);

  useEffect(() => {
    getAuditMeta().then(setMeta).catch(() => {});
  }, []);

  const params = useMemo(() => {
    const out = {};
    if (filters.q.trim()) out.q = filters.q.trim();
    if (filters.action) out.action = filters.action;
    if (filters.entity) out.entity = filters.entity;
    if (filters.userId) out.userId = filters.userId;
    if (filters.from) out.from = filters.from;
    if (filters.to) out.to = filters.to;
    return out;
  }, [filters]);

  const load = useCallback(async () => {
    setLoading(true);
    setErr('');
    try {
      const data = await getAuditLog({ ...params, page: 1, limit: 30 });
      setItems(data.items || []);
      setTotal(data.total || 0);
      setPage(data.page || 1);
      setPages(data.pages || 1);
    } catch (e) {
      setErr(e.response?.data?.error || 'تعذّر تحميل سجل العمليات');
    } finally {
      setLoading(false);
    }
  }, [params]);

  useEffect(() => {
    clearTimeout(timer.current);
    timer.current = setTimeout(load, 250);
    return () => clearTimeout(timer.current);
  }, [load]);

  const loadMore = async () => {
    if (loadingMore || page >= pages) return;
    setLoadingMore(true);
    try {
      const data = await getAuditLog({ ...params, page: page + 1, limit: 30 });
      setItems(prev => [...prev, ...(data.items || [])]);
      setPage(data.page || page + 1);
      setPages(data.pages || pages);
      setTotal(data.total || total);
    } catch (e) {
      setErr(e.response?.data?.error || 'تعذّر تحميل المزيد');
    } finally {
      setLoadingMore(false);
    }
  };

  const change = (key, value) => setFilters(prev => ({ ...prev, [key]: value }));
  const hasFilters = Object.values(filters).some(Boolean);

  const exportCsv = async () => {
    try {
      const blob = await exportAuditCsv(params);
      const url = URL.createObjectURL(blob instanceof Blob ? blob : new Blob([blob]));
      const a = document.createElement('a');
      a.href = url;
      a.download = 'audit-log.csv';
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setErr(e.response?.data?.error || 'تعذّر تصدير السجل');
    }
  };

  return (
    <div className="page">
      <section className="card">
        <div className="card-head">
          <div>
            <h2>سجل العمليات</h2>
            <p className="muted">من نفّذ كل عملية، وماذا تغيّر، ومتى</p>
          </div>
          <span className="brand-logo"><ShieldIcon /></span>
        </div>

        {err && <div className="msg error">{err}</div>}

        <div className="search-bar">
          <span className="search-ico"><SearchIcon /></span>
          <input
            value={filters.q}
            onChange={e => change('q', e.target.value)}
            placeholder="ابحث باسم المستخدم أو نص العملية…"
          />
        </div>

        <div className="form-grid">
          <label className="field">
            <span>نوع العملية</span>
            <select value={filters.action} onChange={e => change('action', e.target.value)}>
              <option value="">كل العمليات</option>
              {meta.actions.map(a => (
                <option key={a.key} value={a.key}>{a.label} ({a.count})</option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>القسم</span>
            <select value={filters.entity} onChange={e => change('entity', e.target.value)}>
              <option value="">كل الأقسام</option>
              {meta.entities.map(x => (
                <option key={x.key} value={x.key}>{x.label} ({x.count})</option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>المستخدم</span>
            <select value={filters.userId} onChange={e => change('userId', e.target.value)}>
              <option value="">كل المستخدمين</option>
              {meta.users.map(u => (
                <option key={u._id} value={u._id}>
                  {u.name ? `${u.name} (${u.username})` : u.username}
                </option>
              ))}
            </select>
          </label>
          <div className="row-2">
            <label className="field">
              <span>من تاريخ</span>
              <input type="date" value={filters.from} onChange={e => change('from', e.target.value)} />
            </label>
            <label className="field">
              <span>إلى تاريخ</span>
              <input type="date" value={filters.to} onChange={e => change('to', e.target.value)} />
            </label>
          </div>
        </div>

        <div className="row-2" style={{ marginTop: 10 }}>
          <button className="btn secondary block sm" onClick={exportCsv}>
            تصدير CSV
          </button>
          <button
            className="btn secondary block sm"
            disabled={!hasFilters}
            onClick={() => setFilters(EMPTY_FILTERS)}
          >
            <CloseIcon /> مسح الفلاتر
          </button>
        </div>
      </section>

      <div className="section-head">
        <h2>العمليات <span className="count">{total}</span></h2>
        <small className="hint">الأحدث أولاً</small>
      </div>

      {loading && items.length === 0 && (
        <div className="card"><p className="muted">جارٍ التحميل…</p></div>
      )}

      {!loading && items.length === 0 && (
        <div className="empty-state card">
          <ShieldIcon />
          <h3>لا توجد عمليات مطابقة</h3>
          <p className="muted">جرّب توسيع الفلاتر أو مسحها</p>
        </div>
      )}

      <div className="user-list">
        {items.map(entry => (
          <article className="user-card" key={entry._id} onClick={() => setSelected(entry)}>
            <div className="user-top">
              <div className="user-info">
                <h3 style={{ fontWeight: 700, lineHeight: 1.6 }}>{entry.summary}</h3>
                <small className="muted">
                  {entry.name || entry.username} ({entry.username}) — {entry.role === 'admin' ? 'أدمن' : 'مستخدم'}
                </small>
              </div>
              <small className="muted" style={{ whiteSpace: 'nowrap' }}>{whenLabel(entry.createdAt)}</small>
            </div>
            <div className="product-tags">
              <span className={`pill ${actionTone(entry.action)}`}>{entry.actionLabel}</span>
              <span className="pill">{entry.entityLabel}</span>
              {entry.label && entry.label !== entry.username && <span className="pill">{entry.label}</span>}
            </div>
          </article>
        ))}
      </div>

      {page < pages && (
        <button className="btn secondary block" disabled={loadingMore} onClick={loadMore}>
          {loadingMore ? 'جارٍ التحميل…' : 'عرض المزيد'}
        </button>
      )}

      {items.length > 0 && (
        <small className="hint center">تم عرض {items.length} من {total} عملية</small>
      )}

      {selected && (
        <div className="sheet-overlay" onClick={() => setSelected(null)}>
          <div className="sheet" onClick={e => e.stopPropagation()}>
            <div className="sheet-head">
              <div>
                <h3>{selected.actionLabel}</h3>
                <p className="sheet-sub">{whenLabel(selected.createdAt)}</p>
              </div>
              <button className="icon-btn ghost" onClick={() => setSelected(null)} aria-label="إغلاق">
                <CloseIcon />
              </button>
            </div>
            <div className="sheet-body">
              <div className="msg success" style={{ marginBottom: 0 }}>{selected.summary}</div>
              <div className="perm-chips">
                <span className={`pill ${actionTone(selected.action)}`}>{selected.actionLabel}</span>
                <span className="pill">{selected.entityLabel}</span>
                <span className="pill">{selected.name || selected.username} ({selected.username})</span>
              </div>
              {selected.label && <small className="hint">العنصر: {selected.label}</small>}
              {selected.entityId && <small className="hint" style={{ direction: 'ltr' }}>ID: {selected.entityId}</small>}
              {selected.ip && <small className="hint" style={{ direction: 'ltr' }}>IP: {selected.ip}</small>}
              {selected.details && (
                <>
                  <span className="field-label">التفاصيل</span>
                  <pre style={{
                    margin: 0, padding: 12, borderRadius: 14, background: '#f8fafc',
                    fontSize: '0.72rem', lineHeight: 1.6, direction: 'ltr', textAlign: 'left',
                    overflowX: 'auto', whiteSpace: 'pre-wrap', wordBreak: 'break-word',
                  }}>
                    {JSON.stringify(selected.details, null, 2)}
                  </pre>
                </>
              )}
              <button className="btn secondary block" onClick={() => setSelected(null)}>
                <CheckIcon /> تم
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
