// RealtimeRegister pricelist
const pricelistContent = document.getElementById('pricelistContent');
const currencySelect = document.getElementById('currencySelect');
const filterInput = document.getElementById('pricelistFilter');
const apiUrl = '<%== url_for('RTR.pricelist.index') %>';
const defaultCurrency = '<%== $default_currency %>';

const PAGE_SIZE = 25;
let currentMatrix = [];   // full matrix for the loaded currency
let filteredMatrix = [];  // currentMatrix narrowed by filterInput
let currentPage = 1;

// Pre-render each column's SVG via the `icon` helper so they're inlined at
// template-render time (same pattern as realtimeregister/domains/index.js).
const icCreate   = '<%== icon "plus-circle" %>';
const icRenew    = '<%== icon "arrow-clockwise" %>';
const icTransfer = '<%== icon "arrow-left-right" %>';
const icRestore  = '<%== icon "arrow-counterclockwise" %>';
const icPrivacy  = '<%== icon "eye-slash" %>';
const icProtect  = '<%== icon "shield-check" %>';
const icLock     = '<%== icon "lock-fill" %>';

// `actions` lists the RTR action names that map into each column (first match wins).
const COLUMNS = [
  { key: 'CREATE',        title: `<%== __('Create') %>`,        icon: icCreate,   actions: ['CREATE'] },
  { key: 'RENEW',         title: `<%== __('Renew') %>`,         icon: icRenew,    actions: ['RENEW'] },
  { key: 'TRANSFER',      title: `<%== __('Transfer') %>`,      icon: icTransfer, actions: ['TRANSFER'] },
  { key: 'RESTORE',       title: `<%== __('Restore') %>`,       icon: icRestore,  actions: ['RESTORE'] },
  { key: 'PRIVACY',       title: `<%== __('Privacy') %>`,       icon: icPrivacy,  actions: ['PRIVACY', 'WHOIS_PRIVACY', 'WHOISPRIVACY'] },
  { key: 'PROTECT',       title: `<%== __('Protect') %>`,       icon: icProtect,  actions: ['PROTECT', 'DOMAIN_PROTECT', 'DOMAINPROTECT'] },
  { key: 'REGISTRY_LOCK', title: `<%== __('Registry Lock') %>`, icon: icLock,     actions: ['REGISTRY_LOCK', 'REGISTRYLOCK', 'LOCK'] },
];

const ACTION_TO_COL = {};
for (const col of COLUMNS) for (const a of col.actions) ACTION_TO_COL[a] = col.key;

function formatPrice(cents, currency) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency }).format(cents / 100);
}

// Map a price row to { tld, col }, or null if it doesn't fit the matrix.
// All columns are actions on the same domain_<tld> product.
function classify(product, action) {
  const m = /^domain_(.+)$/.exec(product);
  if (!m) return null;
  const col = ACTION_TO_COL[(action || '').toUpperCase()];
  if (!col) return null;
  return { tld: m[1].toLowerCase(), col };
}

function buildMatrix(prices) {
  const byTld = new Map();
  for (const p of prices) {
    if (/_sld$/.test(p.product)) continue;
    const c = classify(p.product, p.action);
    if (!c) continue;
    if (!byTld.has(c.tld)) byTld.set(c.tld, { tld: c.tld, currency: p.currency, cells: {} });
    const row = byTld.get(c.tld);
    // If the registry lists multiple matches for one cell, keep the lowest.
    if (row.cells[c.col] === undefined || p.price < row.cells[c.col]) {
      row.cells[c.col] = p.price;
    }
  }
  return [...byTld.values()].sort((a, b) => a.tld < b.tld ? -1 : 1);
}

// Recompute filteredMatrix from the current filter input and reset to page 1.
function applyFilter() {
  // Prefix match against the TLD so `.se` doesn't hit `.case`. Leading `.` optional.
  const q = (filterInput?.value || '').trim().toLowerCase().replace(/^\./, '');
  filteredMatrix = q ? currentMatrix.filter(r => r.tld.startsWith(q)) : currentMatrix;
  currentPage = 1;
  renderTable();
}

function renderTable() {
  const total = filteredMatrix.length;
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  if (currentPage > pages) currentPage = pages;
  if (currentPage < 1) currentPage = 1;
  const start = (currentPage - 1) * PAGE_SIZE;
  const slice = filteredMatrix.slice(start, start + PAGE_SIZE);

  if (!total) {
    pricelistContent.innerHTML = '<p class="text-muted"><%== __('No price data available') %></p>';
    return;
  }

  let html = '<div class="table-responsive"><table class="table table-sm table-striped align-middle mb-2">';
  html += `<thead><tr><th><%== __('TLD') %></th>`;
  for (const col of COLUMNS) {
    html += `<th class="text-end" title="${col.title}">${col.icon}<span class="visually-hidden"> ${col.title}</span></th>`;
  }
  html += '</tr></thead><tbody>';
  for (const row of slice) {
    html += `<tr><td>.${row.tld}</td>`;
    for (const col of COLUMNS) {
      const v = row.cells[col.key];
      html += `<td class="text-end">${v !== undefined ? formatPrice(v, row.currency) : '<span class="text-muted">—</span>'}</td>`;
    }
    html += '</tr>';
  }
  html += '</tbody></table></div>';

  if (pages > 1) {
    // Standard Bootstrap windowed pagination: first / prev / current±pad with ellipses / last / next.
    const pad = 2;
    const items = [];
    items.push({ kind: 'arrow', label: '&laquo;', target: currentPage - 1, disabled: currentPage === 1, ariaLabel: 'Previous' });

    const lo = Math.max(2, currentPage - pad);
    const hi = Math.min(pages - 1, currentPage + pad);
    items.push({ kind: 'page', n: 1 });
    if (lo > 2) items.push({ kind: 'gap' });
    for (let p = lo; p <= hi; p++) items.push({ kind: 'page', n: p });
    if (hi < pages - 1) items.push({ kind: 'gap' });
    if (pages > 1) items.push({ kind: 'page', n: pages });

    items.push({ kind: 'arrow', label: '&raquo;', target: currentPage + 1, disabled: currentPage === pages, ariaLabel: 'Next' });

    html += '<nav aria-label="<%== __('Price list pagination') %>"><ul class="pagination pagination-sm justify-content-center mb-0">';
    for (const it of items) {
      if (it.kind === 'gap') {
        html += '<li class="page-item disabled"><span class="page-link">…</span></li>';
      } else if (it.kind === 'arrow') {
        html += `<li class="page-item ${it.disabled ? 'disabled' : ''}"><a class="page-link" href="#" data-page="${it.target}" aria-label="${it.ariaLabel}">${it.label}</a></li>`;
      } else {
        html += `<li class="page-item ${it.n === currentPage ? 'active' : ''}"><a class="page-link" href="#" data-page="${it.n}">${it.n}</a></li>`;
      }
    }
    html += '</ul></nav>';
  }

  pricelistContent.innerHTML = html;

  pricelistContent.querySelectorAll('a.page-link').forEach(a => {
    a.addEventListener('click', e => {
      e.preventDefault();
      const p = parseInt(a.dataset.page, 10);
      if (!isNaN(p)) {
        currentPage = p;
        renderTable();
      }
    });
  });
}

async function loadPricelist(currency) {
  pricelistContent.innerHTML = '<div class="spinner-border" role="status"><span class="visually-hidden"><%== __('Loading...') %></span></div>';

  try {
    const url = currency ? `${apiUrl}?currency=${currency}` : apiUrl;
    const data = await window.authenticatedFetch(url);

    if (!data || !data.pricelist) {
      pricelistContent.innerHTML = '<p class="text-danger"><%== __('Failed to load price list') %></p>';
      return;
    }

    // ---- debug: inspect what RTR actually returned ----
    window.__rtrPricelist = data.pricelist;
    const prices = data.pricelist.prices || [];
    const products = new Set(), actions = new Set(), pairs = new Set();
    for (const p of prices) {
      products.add(p.product);
      actions.add(p.action);
      pairs.add(`${p.product} | ${p.action}`);
    }
    console.group('RTR pricelist debug');
    console.log('raw response:', data.pricelist);
    console.log('rows total:', prices.length);
    console.log('sample row:', prices[0]);
    console.log('unique actions:', [...actions].sort());
    console.log('unique product prefixes:', [...new Set([...products].map(p => p.split('_')[0]))].sort());
    console.log('product|action pairs (first 30):', [...pairs].slice(0, 30));
    console.groupEnd();
    // ---------------------------------------------------

    currentMatrix = buildMatrix(prices);
    console.log('built matrix rows:', currentMatrix.length, 'first row:', currentMatrix[0]);
    applyFilter();
  } catch (error) {
    console.error('Error loading pricelist:', error);
    pricelistContent.innerHTML = '<p class="text-danger"><%== __('Error loading price list') %></p>';
  }
}

if (currencySelect) {
  currencySelect.addEventListener('change', () => loadPricelist(currencySelect.value));
}

if (filterInput) {
  filterInput.addEventListener('input', applyFilter);
}

loadPricelist(currencySelect ? currencySelect.value : defaultCurrency);
