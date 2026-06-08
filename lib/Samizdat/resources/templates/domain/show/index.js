let currentDomainId = window.location.pathname.split('/').pop();
const basePath = window.location.pathname.replace(/\/\d+$/, '');

function renderDomain(data) {
  if (!data || !data.domain) {
    document.getElementById('domainInfo').innerHTML =
      '<p class="text-danger"><%== __('Failed to load domain') %></p>';
    return;
  }

  const d = data.domain;
  const isAdmin = data.admin;

  // Title
  document.getElementById('domainTitle').textContent = d.domainname;

  // Navigation
  if (data.neighbours) {
    const n = data.neighbours;
    document.getElementById('domainNav').innerHTML = `
      <a class="btn btn-outline-secondary" href="#" data-domainid="${n.minid}" title="<%== __('First') %>"><%== icon 'chevron-bar-left' %></a>
      <a class="btn btn-outline-secondary" href="#" data-domainid="${n.previd}" title="<%== __('Previous') %>"><%== icon 'chevron-left' %></a>
      <a class="btn btn-outline-secondary" href="#" data-domainid="${n.nextid}" title="<%== __('Next') %>"><%== icon 'chevron-right' %></a>
      <a class="btn btn-outline-secondary" href="#" data-domainid="${n.maxid}" title="<%== __('Last') %>"><%== icon 'chevron-bar-right' %></a>
    `;
  }

  // Domain info (from DB — instant)
  const renewalClass = d.dontrenew ? 'text-danger' : 'text-success';
  const renewalText = d.dontrenew ? '<%== __('No') %>' : '<%== __('Yes') %>';
  const dueWarning = d.due ? '<span class="badge bg-warning ms-2"><%== __('Due') %></span>' : '';

  document.getElementById('domainInfo').innerHTML = `
    <dl class="row mb-0" id="domainDl">
      <dt class="col-sm-4"><%== __('Domain') %></dt>
      <dd class="col-sm-8"><strong>${d.domainname}</strong></dd>
      <dt class="col-sm-4"><%== __('Customer') %></dt>
      <dd class="col-sm-8"><a href="<%== url_for('customer_index') %>/${d.customerid}">${d.customerid}</a></dd>
      <dt class="col-sm-4"><%== __('Expiry') %></dt>
      <dd class="col-sm-8" id="expiryVal">${d.curexpiry || 'N/A'}${dueWarning}</dd>
      <dt class="col-sm-4"><%== __('Renewal') %></dt>
      <dd class="col-sm-8"><span class="${renewalClass}">${renewalText}</span></dd>
    </dl>
  `;

  // Nameservers from DB initially
  const nsPanel = document.getElementById('nameserversPanel');
  const dbNs = [d.ns1, d.ns2, d.ns3, d.ns4].filter(Boolean);
  if (dbNs.length > 0) {
    nsPanel.innerHTML = '<ul class="list-unstyled mb-0">' +
      dbNs.map(ns => `<li><code>${ns}</code></li>`).join('') +
      '</ul>';
  } else {
    nsPanel.innerHTML = '<p class="text-muted mb-0"><div class="spinner-border spinner-border-sm"></div> <%== __('Loading from registry...') %></p>';
  }

  // Fetch live registry data asynchronously
  loadRegistryInfo(currentDomainId, d);

  // Show panels and enable buttons
  document.getElementById('domainPanels').style.display = '';
  document.getElementById('btnAuthcode').disabled = false;
  if (isAdmin) {
    document.getElementById('btnRenew').disabled = false;
  }
}

async function loadRegistryInfo(domainId, d) {
  try {
    const data = await window.authenticatedFetch(`${basePath}/${domainId}/registry`);
    const ri = data?.registryInfo;
    if (!ri) return;

    // Update nameservers with live data
    const nsPanel = document.getElementById('nameserversPanel');
    const nsList = ri.ns || [];
    if (nsList.length > 0) {
      nsPanel.innerHTML = '<ul class="list-unstyled mb-0">' +
        nsList.map(ns => `<li><code>${ns}</code></li>`).join('') +
        '</ul>';
    }

    // Update expiry with registry value
    if (ri.expiry) {
      const expiryEl = document.getElementById('expiryVal');
      if (expiryEl) expiryEl.innerHTML = ri.expiry + (d.due ? ' <span class="badge bg-warning"><%== __('Due') %></span>' : '');
    }

    // Add extra registry fields
    const dl = document.getElementById('domainDl');
    if (dl) {
      let extra = '';
      if (ri.status) extra += `<dt class="col-sm-4"><%== __('Status') %></dt><dd class="col-sm-8"><code>${ri.status}</code></dd>`;
      if (ri.registrant) extra += `<dt class="col-sm-4"><%== __('Registrant') %></dt><dd class="col-sm-8"><code>${ri.registrant}</code></dd>`;
      if (ri.created) extra += `<dt class="col-sm-4"><%== __('Created') %></dt><dd class="col-sm-8">${ri.created}</dd>`;
      if (ri.registrar) extra += `<dt class="col-sm-4"><%== __('Registrar') %></dt><dd class="col-sm-8">${ri.registrar}</dd>`;
      if (extra) dl.insertAdjacentHTML('beforeend', extra);
    }

    // DNSSEC
    if (ri.dsData && ri.dsData.length > 0) {
      document.getElementById('dnssecPanel').innerHTML =
        '<table class="table table-sm mb-0"><thead><tr><th>Key Tag</th><th>Algorithm</th><th>Digest Type</th><th>Digest</th></tr></thead><tbody>' +
        ri.dsData.map(ds => `<tr><td>${ds.keytag}</td><td>${ds.alg}</td><td>${ds.digestType}</td><td class="text-break"><code>${ds.digest}</code></td></tr>`).join('') +
        '</tbody></table>';
      document.getElementById('dnssecCard').style.display = '';
    }
  } catch (e) {
    console.warn('Registry info unavailable:', e);
  }
}

async function loadDomain(domainId) {
  currentDomainId = domainId;
  const url = `${basePath}/${domainId}`;
  history.pushState(null, '', url);
  const data = await window.authenticatedFetch(url);
  renderDomain(data);
}

// Navigation clicks via event delegation
document.getElementById('domainNav').addEventListener('click', (e) => {
  e.preventDefault();
  const btn = e.target.closest('a[data-domainid]');
  if (btn && !btn.classList.contains('disabled')) loadDomain(btn.dataset.domainid);
});

// Handle browser back/forward
window.addEventListener('popstate', () => {
  const id = window.location.pathname.split('/').pop();
  if (id !== currentDomainId) {
    currentDomainId = id;
    window.authenticatedFetch(`${basePath}/${id}`).then(renderDomain);
  }
});

// Initial load
loadDomain(currentDomainId);
