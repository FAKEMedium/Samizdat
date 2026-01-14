(async function () {
  const filterStatus = document.querySelector('#filterStatus');
  let currentPage = 1;

  async function fetchMails(page = 1) {
    const params = new URLSearchParams();
    params.set('page', page);
    if (filterStatus?.value) params.set('status', filterStatus.value);

    const data = await window.authenticatedFetch(`<%== url_for('Mailer.index') %>?${params}`);
    if (data) {
      currentPage = data.page;
      populate(data);
      updatePagination(data);
    }
  }

  function statusBadge(status) {
    const classes = {
      draft: 'bg-secondary',
      scheduled: 'bg-info',
      sending: 'bg-warning',
      completed: 'bg-success',
      cancelled: 'bg-danger'
    };
    return `<span class="badge ${classes[status] || 'bg-secondary'}">${status}</span>`;
  }

  function populate(formdata) {
    const mails = formdata.mails || [];
    let html = '';

    for (const m of mails) {
      const created = m.created ? new Date(m.created).toLocaleDateString() : '';
      html += `
        <tr data-id="${m.mailid}">
          <td><a href="<%== url_for('mailer_show', mailid => '_ID_') %>".replace('_ID_', m.mailid)>${m.name}</a></td>
          <td>${statusBadge(m.status)}</td>
          <td>${m.is_draft ? '<%== __("Yes") %>' : '<%== __("No") %>'}</td>
          <td>${created}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-info copy-btn" data-id="${m.mailid}" title="<%== __('Copy') %>">
              <%== icon 'copy', {} %>
            </button>
            <a href="<%== url_for('mailer_edit', mailid => '_ID_') %>".replace('_ID_', m.mailid) class="btn btn-sm btn-outline-secondary edit-btn" title="<%== __('Edit') %>">
              <%== icon 'pencil', {} %>
            </a>
          </td>
        </tr>`;
    }

    document.querySelector('#mails tbody').innerHTML = html || '<tr><td colspan="5" class="text-muted"><%== __("No mails") %></td></tr>';

    document.querySelectorAll('.edit-btn').forEach(btn => {
      btn.onclick = (e) => {
        e.preventDefault();
        window.openModalFromUrl(btn.href);
      };
    });

    document.querySelectorAll('.copy-btn').forEach(btn => {
      btn.onclick = async () => {
        const mailid = btn.dataset.id;
        const result = await window.authenticatedFetch(
          `<%== url_for('Mailer.copy', mailid => '_ID_') %>`.replace('_ID_', mailid),
          { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
        );
        if (result?.success) {
          window.showToast(result.toast, 'success');
          fetchMails(currentPage);
        }
      };
    });
  }

  function updatePagination(formdata) {
    const { page, pages } = formdata;
    if (pages <= 1) {
      document.querySelector('#pagination ul').innerHTML = '';
      return;
    }

    let html = `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
    </li>`;

    for (let i = 1; i <= pages; i++) {
      html += `<li class="page-item ${i === page ? 'active' : ''}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>`;
    }

    html += `<li class="page-item ${page >= pages ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
    </li>`;

    document.querySelector('#pagination ul').innerHTML = html;

    document.querySelectorAll('#pagination a[data-page]').forEach(a => {
      a.onclick = (e) => {
        e.preventDefault();
        const p = parseInt(a.dataset.page);
        if (p >= 1 && p <= pages) fetchMails(p);
      };
    });
  }

  filterStatus?.addEventListener('change', () => fetchMails(1));

  document.querySelector('#newMail')?.addEventListener('click', () => {
    window.openModalFromUrl('<%== url_for("Mailer.new") %>');
  });

  fetchMails(1);
})();
