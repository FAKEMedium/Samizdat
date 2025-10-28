(async function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');

  async function sendData() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      populate(data);
    }
  }

  async function openZoneModal(zoneId = 'new') {
    const url = zoneId === 'new'
      ? '<%== url_for('zone_new') %>'
      : `<%== url_for('zone_index') %>/${zoneId}/edit`;
    const modalResponse = await fetch(url);
    const modalHTML = await modalResponse.text();
    modalDialog.innerHTML = modalHTML;
    universalModal.show();
  }

  // Set up new zone button handler
  document.querySelector('#newZone')?.addEventListener('click', async () => {
    await openZoneModal('new');
  });

  function populate(data) {
    const zones = data.zones || [];
    let snippet = '';
    zones.sort((a, b) => b.id - a.id).forEach(zone => {
      snippet += `
      <tr data-zoneid="${zone.id}">
        <td>${zone.name}</td>
        <td class="text-end">
          <button data-zoneid="${zone.id}" class="btn btn-sm btn-secondary btn-edit"><%== __('Edit') %> <%== icon 'pencil-fill', {} %></button>
          <a href="<%== url_for('zone_index') %>/${zone.id}/records" class="btn btn-sm btn-info"><%== __('Records') %> <%== icon 'stack', {} %></a>
          <button data-zoneid="${zone.id}" class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== __('Delete') %> <%== icon 'trash-fill', {} %></button>
        </td>
      </tr>
      `;
    });
    document.querySelector('#zones tbody').innerHTML = snippet;

    // Edit button handlers
    document.querySelectorAll('.btn-edit').forEach(btn => {
      btn.addEventListener('click', async () => {
        const zoneId = btn.getAttribute('data-zoneid');
        await openZoneModal(zoneId);
      });
    });

    // Delete button handlers
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('<%== __("Are you sure you want to delete this zone?") %>')) return;
        const zoneId = btn.getAttribute('data-zoneid');
        const result = await window.authenticatedFetch(`<%== url_for('zone_index') %>/${zoneId}`, {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('tr').remove();
          window.showToast(result.toast || '<%== __("Zone deleted") %>');
        }
      });
    });
  }

  sendData();
})();