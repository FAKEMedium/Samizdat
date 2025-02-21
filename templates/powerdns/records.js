(function () {
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

  function truncateText(text, limit = 80) {
    return text.length > limit ? text.slice(0, limit) + '...' : text;
  }

  function populate(data) {
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
        <td>${rrset.ttl}</td>
        <td>
          <a href="/powerdns/${data.zone_id}/records/${rrset.name}/edit" class="btn btn-sm btn-secondary">Edit</a>
          <button data-recordid="${recordid}" class="btn btn-sm btn-danger btn-delete">Delete</button>
        </td>
      </tr>`;
      })
    });
    document.querySelector('#records tbody').innerHTML = snippet;
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Are you sure you want to delete this record?')) return;
        const recordId = btn.getAttribute('data-recordid');
        try {
          const response = await fetch(`/powerdns/${data.zone_id}/records/${recordId}`, {
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
