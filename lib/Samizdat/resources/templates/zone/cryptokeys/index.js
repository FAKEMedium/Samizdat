(function() {
  const modalDialog = document.querySelector('#modalDialog');
  const sourceUrl = modalDialog?.dataset.sourceUrl || '';
  const match = sourceUrl.match(/\/zones\/([^/]+)\/cryptokeys/);
  const zoneId = match ? match[1] : null;

  async function loadKeys() {
    const data = await window.authenticatedFetch(sourceUrl);
    if (data && data.cryptokeys) {
      populateKeys(data.cryptokeys, data.zone_id);
    }
  }

  function populateKeys(keys, zoneName) {
    const container = document.querySelector('#cryptokeys');
    if (!keys.length) {
      container.innerHTML = '<p class="text-muted text-center"><%== __("No DNSSEC keys configured") %></p>';
      return;
    }

    let html = '';
    keys.forEach(key => {
      const activeClass = key.active ? 'border-success' : 'border-secondary';
      const activeBadge = key.active
        ? '<span class="badge text-bg-success"><%== __("Active") %></span>'
        : '<span class="badge text-bg-secondary"><%== __("Inactive") %></span>';
      const typeBadge = `<span class="badge text-bg-${key.keytype === 'ksk' || key.keytype === 'csk' ? 'primary' : 'info'}">${key.keytype?.toUpperCase() || 'N/A'}</span>`;

      // Parse DS records for registrar
      let dsHtml = '';
      if (key.ds && key.ds.length) {
        dsHtml = '<div class="mt-2"><strong><%== __("DS Records") %> <small class="text-muted">(<%== __("for registrar") %>)</small>:</strong>';
        dsHtml += '<div class="font-monospace small bg-light p-2 mt-1 rounded">';
        key.ds.forEach(ds => {
          dsHtml += `<div class="text-break">${zoneName} IN DS ${ds}</div>`;
        });
        dsHtml += '</div></div>';
      }

      // DNSKEY record
      let dnskeyHtml = '';
      if (key.dnskey) {
        dnskeyHtml = `<div class="mt-2"><strong>DNSKEY:</strong>
          <div class="font-monospace small bg-light p-2 mt-1 rounded text-break">${zoneName} IN DNSKEY ${key.dnskey}</div>
        </div>`;
      }

      // Key tag and flags for quick reference
      let keyInfoHtml = '<div class="small text-muted mt-1">';
      if (key.flags !== undefined) keyInfoHtml += `Flags: ${key.flags} | `;
      if (key.keytype) keyInfoHtml += `Key Tag: ${key.id} | `;
      keyInfoHtml += `Algorithm: ${key.algorithm || 'N/A'}`;
      if (key.bits) keyInfoHtml += ` | Bits: ${key.bits}`;
      keyInfoHtml += '</div>';

      html += `
        <div class="card mb-2 ${activeClass}" data-keyid="${key.id}">
          <div class="card-header d-flex justify-content-between align-items-center py-2">
            <div>
              ${typeBadge} ${activeBadge}
              <span class="ms-2">Key ID: ${key.id}</span>
            </div>
            <button data-keyid="${key.id}" class="btn btn-sm btn-outline-danger btn-delete" title="<%== __('Delete') %>"><%== icon 'trash-fill', {} %></button>
          </div>
          <div class="card-body py-2">
            ${keyInfoHtml}
            ${dsHtml}
            ${dnskeyHtml}
          </div>
        </div>
      `;
    });
    container.innerHTML = html;

    // Attach delete handlers
    document.querySelectorAll('#cryptokeys .btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('<%== __("Are you sure you want to delete this key?") %>')) return;
        const keyId = btn.getAttribute('data-keyid');
        const result = await window.authenticatedFetch(`<%== url_for('Zone.cryptokeys.delete', zone_id => '_ZID_', key_id => '_KID_') %>`.replace('_ZID_', zoneId).replace('_KID_', keyId), {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('.card').remove();
          window.showToast(result.toast || '<%== __("Key deleted") %>');
          // Check if container is now empty
          if (!document.querySelectorAll('#cryptokeys .card').length) {
            loadKeys();
          }
        } else {
          window.showToast(result?.toast || '<%== __("Failed to delete key") %>', 'danger');
        }
      });
    });
  }

  // Form submit handler
  document.getElementById('cryptokeyForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const data = {
      keytype: document.getElementById('keytype').value,
      algorithm: document.getElementById('algorithm').value,
      active: true
    };

    const result = await window.authenticatedFetch(`<%== url_for('Zone.cryptokeys.index', zone_id => '_ZID_') %>`.replace('_ZID_', zoneId), {
      method: 'POST',
      body: JSON.stringify(data),
      headers: { 'Content-Type': 'application/json' }
    });

    if (result && result.success) {
      window.showToast(result.toast || '<%== __("Key created") %>');
      loadKeys();
    } else {
      window.showToast(result?.toast || '<%== __("Failed to create key") %>', 'danger');
    }
  });

  loadKeys();
})();
