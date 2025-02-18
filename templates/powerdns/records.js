(function () {
  const zoneId = "<%= stash('zone_id') %>";

  async function fetchRecords() {
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
    const records = data.records || [];
    let snippet = '';
    records.sort((a, b) => b.id - a.id).forEach(record => {
      snippet += `
      <tr data-recordid="${record.id}">
        <td>${record.id}</td>
        <td>${record.name}</td>
        <td>${record.type}</td>
        <td>${record.content}</td>
        <td>${record.ttl}</td>
        <td>${record.priority}</td>
        <td>
          <a href="/powerdns/zone/${zoneId}/record/${record.id}/edit" class="btn btn-sm btn-secondary">Edit</a>
          <button data-recordid="${record.id}" class="btn btn-sm btn-danger btn-delete">Delete</button>
        </td>
      </tr>
      `;
    });
    document.querySelector('#records tbody').innerHTML = snippet;
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Are you sure you want to delete this record?')) return;
        const recordId = btn.getAttribute('data-recordid');
        try {
          const response = await fetch(`/powerdns/zone/${zoneId}/record/${recordId}`, {
            method: 'DELETE',
            headers: {'Accept': 'application/json'}
          });
          const result = await response.json();
          if (result.success) {
            btn.closest('tr').remove();
          } else {
            alert(result.error || 'Failed to delete record');
          }
        } catch (error) {
          console.error(error);
        }
      });
    });
  }

  fetchRecords();
})();
