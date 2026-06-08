(function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  let currentZoneId = null;
  let allRrsets = [];  // Store all rrsets for filtering

  let handlersSetup = false;

  async function fetchRecords() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      currentZoneId = data.zone_id;
      allRrsets = data.rrsets || [];
      renderRecords(allRrsets, data.zone_id);
      if (!handlersSetup) {
        setupEventHandlers(data.zone_id);
        handlersSetup = true;
      }
      // Set headline with zone name
      const zoneName = data.zone_id.replace(/\.$/, ''); // Remove trailing dot
      document.getElementById('headline').textContent = `<%== __('Zone Records') %>, ${zoneName}`;
    }
  }

  function truncateText(text, limit = 80) {
    return text.length > limit ? text.slice(0, limit) + '...' : text;
  }

  function stripZoneName(name, zoneId) {
    if (!name || !zoneId) return name;
    const zoneWithDot = zoneId.endsWith('.') ? zoneId : zoneId + '.';
    if (name.endsWith(zoneWithDot)) {
      name = name.slice(0, -zoneWithDot.length);
    } else if (name.endsWith(zoneId)) {
      name = name.slice(0, -zoneId.length);
    }
    if (name.endsWith('.')) name = name.slice(0, -1);
    if (name === '') name = '@';
    return name;
  }

  // Global function to refresh records after save
  // Refetch all records to handle multi-record types (MX, NS, etc.) correctly
  window.updateRecordRow = function(recordData) {
    fetchRecords();
  };

  async function openRecordModal(recordId = 'new') {
    const url = `<%== url_for('zone_index') %>/${currentZoneId}/records/${recordId}`;
    const modalResponse = await fetch(url);
    const modalHTML = await modalResponse.text();
    modalDialog.dataset.sourceUrl = url;
    modalDialog.innerHTML = modalHTML;

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

  function filterRecords(searchterm) {
    if (!searchterm) return allRrsets;
    const term = searchterm.toLowerCase();
    return allRrsets.filter(rrset =>
      rrset.name.toLowerCase().includes(term) ||
      rrset.type.toLowerCase().includes(term) ||
      rrset.records.some(r => r.content.toLowerCase().includes(term))
    );
  }

  function renderRecords(rrsets, zoneId) {
    let snippet = '';
    rrsets.sort((a, b) => a.name.localeCompare(b.name)).forEach(rrset => {
      rrset.records.forEach(record => {
        const displayName = stripZoneName(rrset.name, zoneId);
        // Use type_name as unique identifier for rrsets
        let recordid = rrset.type + '_' + rrset.name;
        // Escape content for data attribute
        const escapedContent = record.content.replace(/"/g, '&quot;');
        snippet += `
      <tr data-recordid="${recordid}" data-type="${rrset.type}" data-name="${rrset.name}" data-content="${escapedContent}">
        <td>
          <button class="btn btn-sm btn-secondary btn-edit" title="<%== __('Edit') %>"><%== icon 'pencil-fill', {} %></button>
          <button class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== icon 'trash-fill', {} %></button>
        </td>
        <td>${displayName}</td>
        <td>${rrset.type}</td>
        <td>${truncateText(record.content, 100)}</td>
        <td class="text-end">${rrset.ttl}</td>
      </tr>`;
      })
    });
    document.querySelector('#records tbody').innerHTML = snippet || '<tr><td colspan="5" class="text-muted text-center"><%== __("No records found") %></td></tr>';
  }

  function setupEventHandlers(zoneId) {
    // New record button
    document.querySelector('#newrecord').addEventListener('click', async (e) => {
      e.preventDefault();
      await openRecordModal('new');
    });

    // Search form submit
    document.querySelector('#dataform').addEventListener('submit', (e) => {
      e.preventDefault();
      const searchterm = document.querySelector('#searchterm').value;
      const filtered = filterRecords(searchterm);
      renderRecords(filtered, zoneId);
    });

    // Live search as user types (debounced, starts after 2 chars)
    let searchTimeout = null;
    document.querySelector('#searchterm').addEventListener('input', (e) => {
      const value = e.target.value;
      clearTimeout(searchTimeout);
      if (value.length > 2) {
        searchTimeout = setTimeout(() => {
          const filtered = filterRecords(value);
          renderRecords(filtered, zoneId);
        }, 200);
      } else if (value.length === 0) {
        renderRecords(allRrsets, zoneId);
      }
    });

    // Event delegation for edit and delete buttons
    document.querySelector('#records tbody').addEventListener('click', async (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;

      const tr = btn.closest('tr');
      const recordType = tr.dataset.type;
      const recordName = tr.dataset.name;
      const recordId = tr.dataset.recordid;

      if (btn.classList.contains('btn-edit')) {
        // Pass type, name, and content as query params for unique identification
        const recordContent = encodeURIComponent(tr.dataset.content);
        await openRecordModal(`${recordName}?type=${recordType}&content=${recordContent}`);
      } else if (btn.classList.contains('btn-delete')) {
        if (!confirm('<%== __("Are you sure you want to delete this record?") %>')) return;
        // Send content in body for single record deletion from multi-record rrsets (MX, NS, etc.)
        const recordContent = tr.dataset.content;
        const result = await window.authenticatedFetch(`<%== url_for('Zone.records.delete', zone_id => '_ZID_', record_id => '_RID_') %>`.replace('_ZID_', zoneId).replace('_RID_', recordId), {
          method: 'DELETE',
          body: JSON.stringify({ content: recordContent }),
          headers: { 'Content-Type': 'application/json' }
        });
        if (result && result.success) {
          tr.remove();
          window.showToast(result.toast || '<%== __("Record deleted") %>');
          // Also remove from allRrsets - for multi-record types, only remove specific content
          allRrsets = allRrsets.map(r => {
            if (r.type + '_' + r.name === recordId) {
              r.records = r.records.filter(rec => rec.content !== recordContent);
              if (r.records.length === 0) return null;
            }
            return r;
          }).filter(Boolean);
        }
      }
    });
  }

  fetchRecords();
})();
