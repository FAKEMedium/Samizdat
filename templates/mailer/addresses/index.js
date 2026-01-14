(async function () {
  const filterSource = document.querySelector('#filterSource');

  async function fetchAddresses() {
    const params = new URLSearchParams();
    if (filterSource?.value) params.set('source', filterSource.value);

    const data = await window.authenticatedFetch(`<%== url_for('Mailer.addresses') %>?${params}`);
    if (data) {
      populate(data.addresses || []);
    }
  }

  function populate(addresses) {
    document.querySelector('#addressCount').textContent = `${addresses.length} <%== __('addresses') %>`;

    let html = '';
    for (const a of addresses) {
      html += `
        <tr data-id="${a.addressid}">
          <td>${a.email}</td>
          <td>${a.first_name || ''}</td>
          <td>${a.last_name || ''}</td>
          <td><span class="badge bg-secondary">${a.source}</span></td>
          <td>${a.languageid === 1 ? 'EN' : a.languageid === 2 ? 'SV' : a.languageid}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-danger delete-btn" data-id="${a.addressid}" title="<%== __('Delete') %>">
              <%== icon 'trash', {} %>
            </button>
          </td>
        </tr>`;
    }

    document.querySelector('#addresses tbody').innerHTML = html || '<tr><td colspan="6" class="text-muted"><%== __("No addresses") %></td></tr>';

    document.querySelectorAll('.delete-btn').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('<%== __("Delete this address?") %>')) return;

        const result = await window.authenticatedFetch(
          `<%== url_for('Mailer.address.delete', addressid => '_ID_') %>`.replace('_ID_', btn.dataset.id),
          { method: 'DELETE' }
        );
        if (result?.success) {
          window.showToast(result.toast, 'success');
          fetchAddresses();
        }
      };
    });
  }

  filterSource?.addEventListener('change', fetchAddresses);

  fetchAddresses();
})();
