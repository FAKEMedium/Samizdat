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
let customerPrices = { explicit: [], prices: {}, multiplier: 1, exclude: [], currency: defaultCurrency };
let explicitOrder = new Map();   // tld -> rank (for sort)
let excludedTlds = new Set();

// Pre-render each column's SVG via the `icon` helper so they're inlined at
// template-render time (same pattern as realtimeregister/domains/index.js).
const icCreate   = '<%== icon "plus-circle" %>';
const icRenew    = '<%== icon "arrow-clockwise" %>';
const icTransfer = '<%== icon "arrow-left-right" %>';
const icRestore  = '<%== icon "arrow-counterclockwise" %>';
const icLock     = '<%== icon "lock-fill" %>';

// `actions` lists the RTR action names that feed into each column.
// `cfgKey` is the matching key in samizdat.yml's manager.realtimeregister.tld[*].price.
// Privacy/Protect intentionally omitted: RTR bundles them as `PRIVACY_PROTECT`
// and we filter out TLDs that charge for it (see buildMatrix), so the column
// would be uninformative.
const COLUMNS = [
  { key: 'CREATE',        title: `<%== __('Create') %>`,        icon: icCreate,   actions: ['CREATE'],                                              cfgKey: 'create'   },
  { key: 'RENEW',         title: `<%== __('Renew') %>`,         icon: icRenew,    actions: ['RENEW'],                                               cfgKey: 'renew'    },
  { key: 'TRANSFER',      title: `<%== __('Transfer') %>`,      icon: icTransfer, actions: ['TRANSFER'],                                            cfgKey: 'transfer' },
  { key: 'RESTORE',       title: `<%== __('Restore') %>`,       icon: icRestore,  actions: ['RESTORE', 'TRANSFER_RESTORE'],                         cfgKey: 'restore'  },
  { key: 'REGISTRY_LOCK', title: `<%== __('Registry Lock') %>`, icon: icLock,     actions: ['REGISTRY_LOCK', 'REGISTRYLOCK', 'LOCK'],               cfgKey: 'lock'     },
];

// One action can feed multiple columns (left as one-to-many so future bundled
// actions can fan out without restructuring).
const ACTION_TO_COLS = {};
for (const col of COLUMNS) for (const a of col.actions) {
  (ACTION_TO_COLS[a] ||= []).push(col.key);
}

function formatPrice(cents, currency) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency }).format(cents / 100);
}

// Customer prices in samizdat.yml are whole units (no cents). Display them
// without fractional digits so `1.8 × 7.50` doesn't show "13.5".
function formatCustomer(units, currency) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency, maximumFractionDigits: 0 }).format(units);
}

// Customer price for a (tld, column) — returns whole units, or null if neither
// an explicit nor a multiplier-derived price applies. Explicit YAML prices are
// only honored when the displayed currency matches the configured default
// (otherwise we'd be applying a SEK figure to a EUR cell).
function customerPriceFor(tld, col, registryCents, currency) {
  const cfgPrices = customerPrices.prices[tld];
  if (cfgPrices && cfgPrices[col.cfgKey] !== undefined && currency === customerPrices.currency) {
    return Number(cfgPrices[col.cfgKey]);
  }
  if (registryCents === undefined) return null;
  const multiplier = customerPrices.multiplier || 1;
  return Math.ceil((registryCents / 100) * multiplier);
}

// Defensive fallback for registry-lock if RTR ever exposes it as a separate
// product instead of an action on `domain_<tld>`. Optional `_<tld>` tail makes
// it per-TLD; without one it's a flat add-on applied to every row.
const ADDON_PRODUCT_PATTERNS = [
  { rx: /^(?:registry[_-]?)?lock(?:[_-](.+))?$/i, col: 'REGISTRY_LOCK' },
];

// Map a price row to an array of { kind: 'tld'|'global', tld, col }, or null
// if irrelevant. Returns an array because a single row (e.g. PRIVACY_PROTECT)
// can fill multiple columns.
function classify(product, action) {
  const m = /^domain_(.+)$/.exec(product);
  if (m) {
    const cols = ACTION_TO_COLS[(action || '').toUpperCase()];
    if (!cols || !cols.length) return null;
    const tld = m[1].toLowerCase();
    // RTR ships compound products like `domain_3rd_level` and `domain_co_uk`
    // where the suffix isn't a single TLD — drop anything with underscores.
    if (tld.includes('_')) return null;
    return cols.map(col => ({ kind: 'tld', tld, col }));
  }
  for (const g of ADDON_PRODUCT_PATTERNS) {
    const am = g.rx.exec(product);
    if (am) {
      if (am[1] && am[1].toLowerCase().includes('_')) return null;
      return [am[1]
        ? { kind: 'tld', tld: am[1].toLowerCase(), col: g.col }
        : { kind: 'global', col: g.col }];
    }
  }
  return null;
}

function buildMatrix(prices) {
  const byTld = new Map();
  const globalAddons = {}; // col -> lowest-priced row across all matches
  const ppCharged = new Set(); // TLDs where the registry charges for privacy/protect

  for (const p of prices) {
    if (/_sld$/.test(p.product)) continue;

    // Skip TLDs whose registry charges for privacy/protect — we only offer
    // domains where privacy is included at no extra cost.
    if (p.action === 'PRIVACY_PROTECT' && p.price > 0) {
      const dm = /^domain_(.+)$/.exec(p.product);
      if (dm) ppCharged.add(dm[1].toLowerCase());
    }

    const classifications = classify(p.product, p.action);
    if (!classifications) continue;

    for (const c of classifications) {
      if (c.kind === 'global') {
        const prev = globalAddons[c.col];
        if (!prev || p.price < prev.price) globalAddons[c.col] = p;
        continue;
      }

      if (excludedTlds.has(c.tld)) continue;
      if (!byTld.has(c.tld)) byTld.set(c.tld, { tld: c.tld, currency: p.currency, cells: {} });
      const row = byTld.get(c.tld);
      // If the registry lists multiple matches for one cell, keep the lowest.
      if (row.cells[c.col] === undefined || p.price < row.cells[c.col]) {
        row.cells[c.col] = p.price;
      }
    }
  }

  // Drop TLDs where the registry charges for privacy/protect.
  for (const tld of ppCharged) byTld.delete(tld);
  if (ppCharged.size) console.log(`dropped ${ppCharged.size} TLDs with paid privacy/protect`);

  // Apply flat add-on prices (registry lock without TLD suffix) to every
  // row that doesn't already have a per-TLD price for that column.
  for (const row of byTld.values()) {
    for (const [col, p] of Object.entries(globalAddons)) {
      if (row.cells[col] === undefined) row.cells[col] = p.price;
    }
  }
  if (Object.keys(globalAddons).length) {
    console.log('global addon prices applied:', Object.fromEntries(
      Object.entries(globalAddons).map(([col, p]) => [col, `${p.product} | ${p.action} | ${p.price}`])
    ));
  }

  // Explicitly-configured TLDs first (in config order), then alphabetical.
  return [...byTld.values()].sort((a, b) => {
    const ra = explicitOrder.has(a.tld) ? explicitOrder.get(a.tld) : Infinity;
    const rb = explicitOrder.has(b.tld) ? explicitOrder.get(b.tld) : Infinity;
    if (ra !== rb) return ra - rb;
    return a.tld < b.tld ? -1 : 1;
  });
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
      if (v === undefined) {
        html += `<td class="text-end"><span class="text-muted">—</span></td>`;
        continue;
      }
      const cust = customerPriceFor(row.tld, col, v, row.currency);
      const rrHtml = `<small class="text-muted d-block">${formatPrice(v, row.currency)}</small>`;
      const custHtml = (cust !== null) ? `<strong>${formatCustomer(cust, row.currency)}</strong>` : '';
      html += `<td class="text-end">${rrHtml}${custHtml}</td>`;
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

    if (data.customer_prices) {
      customerPrices = data.customer_prices;
      explicitOrder = new Map((customerPrices.explicit || []).map((t, i) => [t.toLowerCase(), i]));
      excludedTlds = new Set((customerPrices.exclude || []).map(t => t.toLowerCase()));
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
    const unmatched = [...products].filter(p => !classify(p, 'CREATE') && !/^domain_/.test(p)).sort();
    console.group('RTR pricelist debug');
    console.log('raw response:', data.pricelist);
    console.log('rows total:', prices.length);
    console.log('sample row:', prices[0]);
    console.log('unique actions:', [...actions].sort());
    console.log('unique product prefixes:', [...new Set([...products].map(p => p.split('_')[0]))].sort());
    console.log('product|action pairs (first 30):', [...pairs].slice(0, 30));
    console.log('non-domain products that did NOT match any classifier:', unmatched);
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
