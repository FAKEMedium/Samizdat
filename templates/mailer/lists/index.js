(async function () {
  let currentListId = null;

  async function fetchLists() {
    const data = await window.authenticatedFetch('<%== url_for("Mailer.lists") %>');
    if (data) {
      populate(data.lists || []);
    }
  }

  function populate(lists) {
    let html = '';
    for (const l of lists) {
      html += `
        <tr data-id="${l.listid}">
          <td><a href="#" class="list-link" data-id="${l.listid}">${l.name}</a></td>
          <td>${l.description || '<span class="text-muted">-</span>'}</td>
          <td><span class="badge bg-secondary address-count" data-id="${l.listid}">...</span></td>
          <td>${l.is_public ? '<%== __("Yes") %>' : '<%== __("No") %>'}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-primary import-btn" data-id="${l.listid}" title="<%== __('Import') %>">
              <%== icon 'upload', {} %>
            </button>
            <button class="btn btn-sm btn-outline-secondary edit-btn" data-id="${l.listid}" title="<%== __('Edit') %>">
              <%== icon 'pencil', {} %>
            </button>
            <button class="btn btn-sm btn-outline-danger delete-btn" data-id="${l.listid}" title="<%== __('Delete') %>">
              <%== icon 'trash', {} %>
            </button>
          </td>
        </tr>`;
    }

    document.querySelector('#lists tbody').innerHTML = html || '<tr><td colspan="5" class="text-muted"><%== __("No lists") %></td></tr>';

    // Fetch address counts
    lists.forEach(l => fetchAddressCount(l.listid));

    // Event handlers
    document.querySelectorAll('.import-btn').forEach(btn => {
      btn.onclick = () => {
        currentListId = parseInt(btn.dataset.id);
        new bootstrap.Modal(document.querySelector('#importModal')).show();
      };
    });

    document.querySelectorAll('.delete-btn').forEach(btn => {
      btn.onclick = async () => {
        if (!confirm('<%== __("Delete this list?") %>')) return;
        const result = await window.authenticatedFetch(
          `<%== url_for('Mailer.list.delete', listid => '_ID_') %>`.replace('_ID_', btn.dataset.id),
          { method: 'DELETE' }
        );
        if (result?.success) {
          window.showToast(result.toast, 'success');
          fetchLists();
        }
      };
    });
  }

  async function fetchAddressCount(listid) {
    const data = await window.authenticatedFetch(
      `<%== url_for('Mailer.list.addresses', listid => '_ID_') %>`.replace('_ID_', listid)
    );
    if (data?.addresses) {
      const badge = document.querySelector(`.address-count[data-id="${listid}"]`);
      if (badge) badge.textContent = data.addresses.length;
    }
  }

  document.querySelector('#newList')?.addEventListener('click', async () => {
    const name = prompt('<%== __("List name:") %>');
    if (!name) return;

    const result = await window.authenticatedFetch('<%== url_for("Mailer.list.create") %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name })
    });

    if (result?.success) {
      window.showToast(result.toast, 'success');
      fetchLists();
    }
  });

  document.querySelector('#doImport')?.addEventListener('click', async () => {
    const activeTab = document.querySelector('.tab-pane.active').id;
    let format, data, columns;

    if (activeTab === 'importText') {
      format = 'text';
      data = document.querySelector('#importTextData').value;
    } else {
      format = 'csv';
      data = document.querySelector('#importCsvData').value;
      columns = {
        email: parseInt(document.querySelector('#colEmail').value) || 0
      };
      const colName = document.querySelector('#colName').value;
      const colFirst = document.querySelector('#colFirstName').value;
      const colLast = document.querySelector('#colLastName').value;
      if (colName !== '') columns.name = parseInt(colName);
      if (colFirst !== '') columns.first_name = parseInt(colFirst);
      if (colLast !== '') columns.last_name = parseInt(colLast);
    }

    const source = document.querySelector('#importSource').value;

    const result = await window.authenticatedFetch('<%== url_for("Mailer.list.import") %>', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        listid: currentListId,
        format,
        data,
        columns,
        source
      })
    });

    if (result?.success) {
      bootstrap.Modal.getInstance(document.querySelector('#importModal'))?.hide();

      if (result.needs_review > 0) {
        showReviewModal(result);
      } else {
        window.showToast(`<%== __("Imported") %> ${result.created} <%== __("new") %>, ${result.linked} <%== __("existing") %>`, 'success');
      }

      fetchLists();
    }
  });

  function showReviewModal(result) {
    const summary = document.querySelector('#reviewSummary');
    summary.innerHTML = `
      <strong><%== __("Import complete") %>:</strong>
      ${result.created} <%== __("created") %>,
      ${result.linked} <%== __("linked") %>,
      <span class="text-warning">${result.needs_review} <%== __("need review") %></span>
    `;

    let html = '';
    for (const r of result.results) {
      const statusClass = r.needs_review ? 'text-warning' : (r.is_new ? 'text-success' : 'text-muted');
      const statusText = r.needs_review ? '<%== __("Review") %>' : (r.is_new ? '<%== __("New") %>' : '<%== __("Linked") %>');
      html += `
        <tr class="${r.needs_review ? 'table-warning' : ''}">
          <td>${r.email}</td>
          <td>${r.name || ''}</td>
          <td>${r.first_name || ''}</td>
          <td>${r.last_name || ''}</td>
          <td><span class="${statusClass}">${statusText}</span></td>
        </tr>`;
    }

    document.querySelector('#reviewTable tbody').innerHTML = html;
    new bootstrap.Modal(document.querySelector('#reviewModal')).show();
  }

  fetchLists();
})();
