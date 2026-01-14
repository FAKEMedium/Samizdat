(async function () {
  const filterType = document.querySelector('#filterType');

  async function fetchBounces() {
    const params = new URLSearchParams();
    if (filterType?.value) params.set('type', filterType.value);

    const data = await window.authenticatedFetch(`<%== url_for('Mailer.bounces') %>?${params}`);
    if (data) {
      populate(data.bounces || []);
    }
  }

  function typeBadge(type) {
    const classes = {
      hard: 'bg-danger',
      soft: 'bg-warning',
      complaint: 'bg-dark',
      delayed: 'bg-info'
    };
    return `<span class="badge ${classes[type] || 'bg-secondary'}">${type}</span>`;
  }

  function populate(bounces) {
    document.querySelector('#bounceCount').textContent = `${bounces.length} <%== __('bounces') %>`;

    let html = '';
    for (const b of bounces) {
      const received = b.received ? new Date(b.received).toLocaleString() : '';
      html += `
        <tr data-id="${b.bounceid}">
          <td>${b.email}</td>
          <td>${typeBadge(b.bounce_type)}</td>
          <td><code>${b.bounce_code || '-'}</code></td>
          <td>${received}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-secondary view-btn" data-id="${b.bounceid}" title="<%== __('View details') %>">
              <%== icon 'eye', {} %>
            </button>
            <button class="btn btn-sm btn-outline-danger delete-btn" data-id="${b.bounceid}" title="<%== __('Delete') %>">
              <%== icon 'trash', {} %>
            </button>
          </td>
        </tr>`;
    }

    document.querySelector('#bounces tbody').innerHTML = html || '<tr><td colspan="5" class="text-muted"><%== __("No bounces") %></td></tr>';

    document.querySelectorAll('.view-btn').forEach(btn => {
      btn.onclick = async () => {
        const data = await window.authenticatedFetch(
          `<%== url_for('Mailer.bounce', bounceid => '_ID_') %>`.replace('_ID_', btn.dataset.id)
        );
        if (data?.bounce) {
          alert(data.bounce.diagnostic || data.bounce.raw_message || '<%== __("No details available") %>');
        }
      };
    });

    document.querySelectorAll('.delete-btn').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('<%== __("Delete this bounce record?") %>')) return;

        const result = await window.authenticatedFetch(
          `<%== url_for('Mailer.bounce.delete', bounceid => '_ID_') %>`.replace('_ID_', btn.dataset.id),
          { method: 'DELETE' }
        );
        if (result?.success) {
          window.showToast(result.toast, 'success');
          fetchBounces();
        }
      };
    });
  }

  filterType?.addEventListener('change', fetchBounces);

  fetchBounces();
})();
