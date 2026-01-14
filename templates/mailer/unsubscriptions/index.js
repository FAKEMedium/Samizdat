(async function () {
  async function fetchUnsubscriptions() {
    const data = await window.authenticatedFetch('<%== url_for("Mailer.unsubscriptions") %>');
    if (data) {
      populate(data.unsubscriptions || []);
    }
  }

  function populate(unsubscriptions) {
    document.querySelector('#unsubCount').textContent = `${unsubscriptions.length} <%== __('unsubscribed') %>`;

    let html = '';
    for (const u of unsubscriptions) {
      const created = u.created ? new Date(u.created).toLocaleDateString() : '';
      html += `
        <tr data-id="${u.unsubscriptionid}">
          <td>${u.email}</td>
          <td>${u.reason || '<span class="text-muted">-</span>'}</td>
          <td>${created}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-danger delete-btn" data-id="${u.unsubscriptionid}" title="<%== __('Remove') %>">
              <%== icon 'trash', {} %>
            </button>
          </td>
        </tr>`;
    }

    document.querySelector('#unsubscriptions tbody').innerHTML = html || '<tr><td colspan="4" class="text-muted"><%== __("No unsubscriptions") %></td></tr>';

    document.querySelectorAll('.delete-btn').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('<%== __("Remove this unsubscription? The email will be eligible for mailings again.") %>')) return;

        const result = await window.authenticatedFetch(
          `<%== url_for('Mailer.unsubscription.delete', unsubscriptionid => '_ID_') %>`.replace('_ID_', btn.dataset.id),
          { method: 'DELETE' }
        );
        if (result?.success) {
          window.showToast(result.toast, 'success');
          fetchUnsubscriptions();
        }
      };
    });
  }

  fetchUnsubscriptions();
})();
