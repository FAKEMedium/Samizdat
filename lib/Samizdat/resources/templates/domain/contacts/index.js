(async function () {
  const basePath = window.location.pathname.replace(/\/$/, '');
  const searchInput = document.querySelector('#search');
  let currentPage = 1;

  // Read URL params
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('search')) {
    searchInput.value = urlParams.get('search');
  }

  async function fetchContacts(page = 1) {
    const params = new URLSearchParams();
    params.set('page', page);
    params.set('per_page', 50);

    const search = searchInput?.value || '';
    if (search) params.set('search', search);

    const url = `${basePath}?${params.toString()}`;
    const data = await window.authenticatedFetch(url);
    if (data) {
      currentPage = data.page;
      populate(data);
      updatePagination(data);
    }
  }

  function populate(formdata) {
    const contacts = formdata.contacts || [];
    let snippet = '';

    for (const contact of contacts) {
      const sourceBadge = contact.source === 'epp'
        ? '<span class="badge bg-info">EPP</span>'
        : '<span class="badge bg-success">RR</span>';

      snippet += `
        <tr data-handle="${contact.handle}">
          <td><a href="<%== url_for('domain_contacts') %>/${contact.handle}">${contact.handle}</a> ${sourceBadge}</td>
          <td>${contact.name || ''}</td>
          <td>${contact.organization || ''}</td>
          <td>${contact.email || ''}</td>
          <td class="text-end text-nowrap">
            <button class="btn btn-sm btn-secondary btn-edit" title="<%== __('Edit') %>"><%== icon 'pencil-fill', {} %></button>
            <button class="btn btn-sm btn-danger btn-delete" title="<%== __('Delete') %>"><%== icon 'trash-fill', {} %></button>
          </td>
        </tr>`;
    }
    document.querySelector('#contacts tbody').innerHTML = snippet;

    // Update pagination info
    const start = (formdata.page - 1) * formdata.per_page + 1;
    const end = Math.min(formdata.page * formdata.per_page, formdata.total);
    document.querySelector('#pagination-info').textContent =
      formdata.total > 0 ? `${start}-${end} <%== __('of') %> ${formdata.total}` : '';

    // Attach event handlers
    document.querySelectorAll('.btn-edit').forEach(btn => {
      btn.onclick = () => {
        const handle = btn.closest('tr').dataset.handle;
        window.location.href = `<%== url_for('domain_contacts') %>/${handle}`;
      };
    });

    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.onclick = async () => {
        const handle = btn.closest('tr').dataset.handle;
        if (!confirm('<%== __("Are you sure you want to delete this contact?") %>')) return;

        const result = await window.authenticatedFetch(`<%== url_for('domain_contacts') %>/${handle}`, {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('tr').remove();
          window.showToast?.('<%== __("Contact deleted") %>');
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

    let html = '';

    html += `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
    </li>`;

    const maxVisible = 7;
    let startPage = Math.max(1, page - Math.floor(maxVisible / 2));
    let endPage = Math.min(pages, startPage + maxVisible - 1);
    if (endPage - startPage < maxVisible - 1) {
      startPage = Math.max(1, endPage - maxVisible + 1);
    }

    if (startPage > 1) {
      html += `<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>`;
      if (startPage > 2) {
        html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
      }
    }

    for (let i = startPage; i <= endPage; i++) {
      html += `<li class="page-item ${i === page ? 'active' : ''}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>`;
    }

    if (endPage < pages) {
      if (endPage < pages - 1) {
        html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
      }
      html += `<li class="page-item"><a class="page-link" href="#" data-page="${pages}">${pages}</a></li>`;
    }

    html += `<li class="page-item ${page >= pages ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
    </li>`;

    document.querySelector('#pagination ul').innerHTML = html;

    document.querySelectorAll('#pagination a[data-page]').forEach(a => {
      a.onclick = (e) => {
        e.preventDefault();
        const p = parseInt(a.dataset.page);
        if (p >= 1 && p <= pages) {
          fetchContacts(p);
        }
      };
    });
  }

  // Search form handler
  document.querySelector('#dataform')?.addEventListener('submit', (e) => {
    e.preventDefault();
    fetchContacts(1);
  });

  // Live search (debounced)
  let searchTimeout = null;
  searchInput?.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    if (searchInput.value.length >= 3 || searchInput.value.length === 0) {
      searchTimeout = setTimeout(() => fetchContacts(1), 300);
    }
  });

  // New contact button - opens modal with all registries available
  document.querySelector('#newContact')?.addEventListener('click', async () => {
    const modalDialog = document.querySelector('#universalmodal #modalDialog');
    if (modalDialog) modalDialog.classList.add('modal-xl');
    await window.openModalFromUrl('<%== url_for('domain_contact_new') %>');
  });

  // Initial load
  fetchContacts(1);
})();
