(async function () {
  async function sendData() {
    try {
      const response = await fetch(window.location.href, {headers: {'Accept': 'application/json'}});
      const data = await response.json();
      if (data.error) {
        alert(data.error);
      } else {
        populate(data);
      }
    } catch (e) {
      console.error(e);
    }
  }

  function populate(data) {
    const zones = data.zones || [];
    let snippet = '';
    zones.sort((a, b) => b.id - a.id).forEach(zone => {
      snippet += `
      <tr data-zoneid="${zone.id}">
        <td>${zone.name}</td>
        <td>
          <a href="./zones/${zone.id}/edit" class="btn btn-sm btn-secondary"><%== __('Edit') %> <%== icon 'pencil-fill', {} %></a>
          <a href="./zones/${zone.id}/records" class="btn btn-sm btn-info"><%== __('Records') %> <%== icon 'stack', {} %></a>
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
        try {
          const response = await fetch(`./zones/${zoneId}`, {
            method: 'DELETE',
            headers: {'Accept': 'application/json'}
          });
          const result = await response.json();
          if (result.success) {
            btn.closest('tr').remove();
          } else {
            alert(result.error || 'Failed to delete zone');
          }
        } catch (error) {
          console.error(error);
        }
      });
    });
  }

  sendData();
})();