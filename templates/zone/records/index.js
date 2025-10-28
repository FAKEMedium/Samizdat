(function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  let currentZoneId = null;

  async function fetchRecords() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      currentZoneId = data.zone_id;
      populate(data);
    }
  }

  function truncateText(text, limit = 80) {
    return text.length > limit ? text.slice(0, limit) + '...' : text;
  }

  async function openRecordModal(recordId = 'new') {
    const url = `<%== url_for('zone_index') %>/${currentZoneId}/records/${recordId}`;
    const modalResponse = await fetch(url);
    const modalHTML = await modalResponse.text();
    modalDialog.innerHTML = modalHTML;
    universalModal.show();
  }

  function populate(data) {
    // Set new record button to open modal
    document.querySelector('#newrecord').addEventListener('click', async (e) => {
      e.preventDefault();
      await openRecordModal('new');
    });

    const rrsets = data.rrsets || [];
    let snippet = '';
    rrsets.sort((a, b) => b.name - a.name).forEach(rrset => {
      rrset.records.forEach(record => {
        record.name = rrset.name;
        if (record.name.endsWith(data.zone_id)) {
          record.name = record.name.slice(0, -data.zone_id.length);
        }
        if (record.name === "") {
          record.name = "@";
        }
        if (record.name.endsWith('.')) {
          record.name = record.name.slice(0, -1);
        }
        let recordid = rrset.type + '_' + rrset.name;
        snippet += `
      <tr data-recordid="${recordid}">
        <td>${record.name}</td>
        <td>${rrset.type}</td>
        <td>${truncateText(record.content, 100)}</td>
        <td class="text-end">${rrset.ttl}</td>
        <td class="text-end">
          <button data-recordname="${rrset.name}" class="btn btn-sm btn-secondary btn-edit" title="<%== __('Edit') %>"><%== icon 'pencil-fill', {} %></button>
          <button data-recordid="${recordid}" class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== icon 'trash-fill', {} %></button>
        </td>
      </tr>`;
      })
    });
    document.querySelector('#records tbody').innerHTML = snippet;

    // Edit button handlers
    document.querySelectorAll('.btn-edit').forEach(btn => {
      btn.addEventListener('click', async () => {
        const recordName = btn.getAttribute('data-recordname');
        await openRecordModal(recordName);
      });
    });

    // Delete button handlers
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('<%== __("Are you sure you want to delete this record?") %>')) return;
        const recordId = btn.getAttribute('data-recordid');
        const result = await window.authenticatedFetch(`<%== url_for('zone_index') %>/${data.zone_id}/records/${recordId}`, {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('tr').remove();
          window.showToast(result.toast || '<%== __("Record deleted") %>');
        }
      });
    });
  }

  fetchRecords();
})();
