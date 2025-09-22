(async function () {
  async function sendData() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      populate(data);
    }
  }

  function populate(data) {
    const zones = data.zones || [];
    let snippet = '';
    zones.sort((a, b) => b.id - a.id).forEach(zone => {
      snippet += `
      <tr data-zoneid="${zone.id}">
        <td>${zone.name}</td>
        <td class="text-end">
          <a href="./${zone.id}/edit" class="btn btn-sm btn-secondary"><%== __('Edit') %> <%== icon 'pencil-fill', {} %></a>
          <a href="./${zone.id}/records" class="btn btn-sm btn-info"><%== __('Records') %> <%== icon 'stack', {} %></a>
          <button data-zoneid="${zone.id}" class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== __('Delete') %> <%== icon 'trash-fill', {} %></button>
        </td>
      </tr>
      `;
    });
    document.querySelector('#zones tbody').innerHTML = snippet;
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Are you sure you want to delete this zone?')) return;
        const zoneId = btn.getAttribute('data-zoneid');
        const result = await window.authenticatedFetch(`./${zoneId}`, {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('tr').remove();
        }
      });
    });
  }

  sendData();
})();