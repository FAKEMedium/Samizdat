(async function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');

  // Use current path for fetching (works for both /zones and /customers/:id/zones)
  const basePath = window.location.pathname.replace(/\/$/, '');
  // Customer ID will be set from JSON response
  let customerId = null;

  async function sendData(searchterm = null) {
    let url = basePath;
    const params = new URLSearchParams();

    if (searchterm) {
      params.set('searchterm', searchterm);
    }

    if (params.toString()) {
      url += '?' + params.toString();
    }

    const data = await window.authenticatedFetch(url);
    if (data) {
      populate(data);
    }
  }

  // Search form handler - use AJAX instead of page reload
  document.querySelector('#dataform')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const searchterm = document.querySelector('#searchterm').value;
    await sendData(searchterm);
  });

  // Live search as user types (debounced, starts after 3 chars)
  let searchTimeout = null;
  document.querySelector('#searchterm')?.addEventListener('input', (e) => {
    const value = e.target.value;
    clearTimeout(searchTimeout);

    if (value.length > 3) {
      searchTimeout = setTimeout(async () => {
        await sendData(value);
      }, 300);
    } else if (value.length === 0) {
      // Clear search - show all zones
      sendData();
    }
  });

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
      snippet += `
      <tr data-zoneid="${zoneId}">
        <td colspan="2" class="d-md-none py-2">
          <div class="fw-bold mb-1">${displayName}</div>
          <div class="btn-group btn-group-sm flex-wrap gap-1">${buttons}</div>
        </td>
        <td class="d-none d-md-table-cell">${displayName}</td>
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
        const result = await window.authenticatedFetch(`<%== url_for('zone_index') %>/${zoneId}`, {
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