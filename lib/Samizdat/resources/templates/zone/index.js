(async function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');

  // Use current path for fetching (works for both /zones and /customers/:id/zones)
  const basePath = window.location.pathname.replace(/\/$/, '');
  // Customer ID will be set from JSON response
  let customerId = null;
  // Store all zones for client-side filtering
  let allZones = [];

  // Filter elements
  const zoneTypeFilter = document.querySelector('#zoneType');
  const accountFilter = document.querySelector('#accountFilter');
  const searchtermInput = document.querySelector('#searchterm');

  // Read searchterm from URL if present (for links from manager widget)
  const urlParams = new URLSearchParams(window.location.search);
  const urlSearchterm = urlParams.get('searchterm');
  if (urlSearchterm && searchtermInput) {
    searchtermInput.value = urlSearchterm;
  }

  async function sendData() {
    const data = await window.authenticatedFetch(basePath);
    if (data) {
      allZones = data.zones || [];
      customerId = data.customerid || null;
      populateAccountFilter();
      applyFilters();
    }
  }

  function applyFilters() {
    const searchterm = searchtermInput?.value.toLowerCase() || '';
    const zoneType = zoneTypeFilter?.value || 'forward';
    const account = accountFilter?.value || '';

    let filtered = allZones.filter(zone => {
      // Zone type filter (handle with/without trailing dot)
      const name = (zone.name || '').replace(/\.$/, '');
      if (zoneType === 'forward') {
        if (name.endsWith('.in-addr.arpa') || name.endsWith('.ip6.arpa')) return false;
      } else if (zoneType === 'in-addr.arpa') {
        if (!name.endsWith('.in-addr.arpa')) return false;
      } else if (zoneType === 'ip6.arpa') {
        if (!name.endsWith('.ip6.arpa')) return false;
      }

      // Account filter
      if (account === '__none__') {
        if (zone.account) return false;
      } else if (account && zone.account !== account) {
        return false;
      }

      // Search term filter
      if (searchterm && !name.toLowerCase().includes(searchterm)) return false;

      return true;
    });

    populate({ zones: filtered, customerid: customerId });
  }

  function populateAccountFilter() {
    const zoneType = zoneTypeFilter?.value || 'forward';

    // Filter zones by current zone type first
    const filteredByType = allZones.filter(zone => {
      const name = (zone.name || '').replace(/\.$/, '');
      if (zoneType === 'forward') {
        return !name.endsWith('.in-addr.arpa') && !name.endsWith('.ip6.arpa');
      } else if (zoneType === 'in-addr.arpa') {
        return name.endsWith('.in-addr.arpa');
      } else if (zoneType === 'ip6.arpa') {
        return name.endsWith('.ip6.arpa');
      }
      return true;
    });

    // Count zones per account from filtered list
    const accountCounts = {};
    let unaccountedCount = 0;
    filteredByType.forEach(z => {
      if (z.account) {
        accountCounts[z.account] = (accountCounts[z.account] || 0) + 1;
      } else {
        unaccountedCount++;
      }
    });
    const accounts = Object.keys(accountCounts).sort();
    const currentValue = accountFilter?.value || '';
    accountFilter.innerHTML = `<option value=""><%== __('All accounts') %> (${filteredByType.length})</option>`;
    // Add unaccounted option
    if (unaccountedCount > 0) {
      const opt = document.createElement('option');
      opt.value = '__none__';
      opt.textContent = `<%== __('No account') %> (${unaccountedCount})`;
      if (currentValue === '__none__') opt.selected = true;
      accountFilter.appendChild(opt);
    }
    accounts.forEach(acc => {
      const opt = document.createElement('option');
      opt.value = acc;
      opt.textContent = `${acc} (${accountCounts[acc]})`;
      if (acc === currentValue) opt.selected = true;
      accountFilter.appendChild(opt);
    });
  }

  // Search form handler - use AJAX instead of page reload
  document.querySelector('#dataform')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    applyFilters();
  });

  // Live search as user types (debounced, starts after 3 chars)
  let searchTimeout = null;
  searchtermInput?.addEventListener('input', (e) => {
    const value = e.target.value;
    clearTimeout(searchTimeout);

    if (value.length > 3 || value.length === 0) {
      searchTimeout = setTimeout(() => applyFilters(), 300);
    }
  });

  // Filter change handlers
  zoneTypeFilter?.addEventListener('change', () => {
    populateAccountFilter();  // Update account counts for new zone type
    applyFilters();
  });
  accountFilter?.addEventListener('change', () => applyFilters());

  async function openModal(url, wide = false) {
    const modalResponse = await fetch(url);
    const modalHTML = await modalResponse.text();
    modalDialog.dataset.sourceUrl = url;
    modalDialog.dataset.customerId = customerId || '';
    modalDialog.innerHTML = modalHTML;

    // Set modal width
    modalDialog.classList.toggle('modal-xl', wide);

    // Extract and execute modal script using blob URL (CSP-compatible)
    const modalscript = modalDialog.querySelector('#modalscript');
    if (modalscript) {
      const blob = new Blob([modalscript.innerHTML], { type: 'application/javascript' });
      const url = URL.createObjectURL(blob);
      const script = document.createElement('script');
      script.id = 'modaljs';
      script.src = url;
      script.onload = () => URL.revokeObjectURL(url);
      modalDialog.appendChild(script);
      modalscript.remove();
    }

    universalModal.show();
  }

  async function openZoneModal(zoneId = 'new') {
    const url = zoneId === 'new'
      ? '<%== url_for('zone_new') %>'
      : `<%== url_for('zone_index') %>/${zoneId}/edit`;
    await openModal(url);
  }

  // Set up new zone button handler
  document.querySelector('#newZone')?.addEventListener('click', async () => {
    await openZoneModal('new');
  });

  // Set up import zone button handler
  document.querySelector('#importZone')?.addEventListener('click', async () => {
    await openModal('<%== url_for('zone_import_form') %>', true);
  });

  function populate(data) {
    // Store customerId from response (set when accessed under /customers/:id/zones)
    customerId = data.customerid || null;
    const zones = data.zones || [];
    let snippet = '';
    zones.sort((a, b) => b.id - a.id).forEach(zone => {
      // Show Unicode name if different from punycode name
      const displayName = zone.unicode_name && zone.unicode_name !== zone.name
        ? `${zone.unicode_name} <small class="text-muted">(${zone.name})</small>`
        : zone.name;
      // PowerDNS uses zone name as identifier, not numeric id
      const zoneId = zone.name;
      const cryptoClass = zone.cryptokey_count > 0 ? 'btn-success' : 'btn-outline-secondary';
      const buttons = `
        <button class="btn btn-sm btn-info btn-records"><%== __('Records') %> <span class="badge text-bg-dark">${zone.record_count || 0}</span></button>
        <button class="btn btn-sm btn-secondary btn-edit"><%== icon 'pencil-fill', {} %></button>
        <button class="btn btn-sm ${cryptoClass} btn-cryptokeys" title="DNSSEC"><%== icon 'shield-lock', {} %> <span class="badge text-bg-dark">${zone.cryptokey_count || 0}</span></button>
        <button class="btn btn-sm btn-outline-secondary btn-export" title="<%== __('Export zone file') %>"><%== icon 'download', {} %></button>
        <button class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== icon 'trash-fill', {} %></button>`;
      const account = zone.account || '';
      snippet += `
      <tr data-zoneid="${zoneId}">
        <td>
          <div class="d-md-none py-2">
            <div class="fw-bold mb-1">${displayName}</div>
            ${account ? `<div class="text-muted small mb-1">${account}</div>` : ''}
            <div class="btn-group btn-group-sm flex-wrap gap-1">${buttons}</div>
          </div>
          <span class="d-none d-md-inline">${displayName}</span>
        </td>
        <td class="d-none d-md-table-cell">${account}</td>
        <td class="d-none d-md-table-cell text-end text-nowrap">${buttons}</td>
      </tr>
      `;
    });
    document.querySelector('#zones tbody').innerHTML = snippet;

    // Event delegation on tbody
    const tbody = document.querySelector('#zones tbody');
    tbody.addEventListener('click', async (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;

      const tr = btn.closest('tr');
      const zoneId = tr.dataset.zoneid;

      if (btn.classList.contains('btn-records')) {
        window.location.href = `<%== url_for('zone_index') %>/${zoneId}/records`;
      } else if (btn.classList.contains('btn-edit')) {
        await openZoneModal(zoneId);
      } else if (btn.classList.contains('btn-cryptokeys')) {
        await openModal(`<%== url_for('zone_index') %>/${zoneId}/cryptokeys`);
      } else if (btn.classList.contains('btn-export')) {
        window.location.href = `<%== url_for('zone_index') %>/${zoneId}/export`;
      } else if (btn.classList.contains('btn-delete')) {
        if (!confirm('<%== __("Are you sure you want to delete this zone?") %>')) return;
        const result = await window.authenticatedFetch(`<%== url_for('Zone.delete', zone_id => '_ZID_') %>`.replace('_ZID_', zoneId), {
          method: 'DELETE'
        });
        if (result && result.success) {
          tr.remove();
          window.showToast(result.toast || '<%== __("Zone deleted") %>');
        }
      }
    });
  }

  sendData();
})();