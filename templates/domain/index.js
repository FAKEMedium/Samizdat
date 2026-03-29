(async function () {
  const basePath = window.location.pathname.replace(/\/$/, '');

  // Filter elements
  const filterStatus = document.querySelector('#filterStatus');
  const customerFilter = document.querySelector('#customerFilter');
  const searchtermInput = document.querySelector('#searchterm');

  // Sort state from cookie, default: domainname ascending
  function getSortCookie() {
    const match = document.cookie.match(/(?:^|;\s*)domain_sort=([^;]*)/);
    return match ? decodeURIComponent(match[1]) : 'domainname';
  }
  function setSortCookie(value) {
    const d = new Date();
    d.setTime(d.getTime() + 365 * 24 * 60 * 60 * 1000);
    document.cookie = `domain_sort=${value};expires=${d.toUTCString()};path=/;secure;SameSite=None;`;
  }
  let currentSort = getSortCookie();

  // State
  let currentPage = 1;

  // Read URL params
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('searchterm')) {
    searchtermInput.value = urlParams.get('searchterm');
  }
  if (urlParams.get('filter')) {
    filterStatus.value = urlParams.get('filter');
  }

  async function fetchDomains(page = 1) {
    const params = new URLSearchParams();
    params.set('page', page);
    params.set('per_page', 50);

    const searchterm = searchtermInput?.value || '';
    if (searchterm) params.set('searchterm', searchterm);

    const filter = filterStatus?.value || '';
    if (filter) params.set('filter', filter);

    const customerid = customerFilter?.value || '';
    if (customerid) params.set('customerid', customerid);

    const url = `${basePath}?${params.toString()}`;
    const data = await window.authenticatedFetch(url);
    if (data) {
      currentPage = data.page;
      populate(data);
      updatePagination(data);
      // Populate customer filter dropdown (only on first load)
      if (data.customers && data.customers.length > 0) {
        populateCustomerFilter(data.customers);
      }
    }
  }

  function populateCustomerFilter(customers) {
    const currentValue = customerFilter?.value || '';
    const totalDomains = customers.reduce((sum, c) => sum + c.count, 0);
    customerFilter.innerHTML = `<option value=""><%== __('All customers') %> (${totalDomains})</option>`;
    customers.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = `${c.id} (${c.count})`;
      if (String(c.id) === currentValue) opt.selected = true;
      customerFilter.appendChild(opt);
    });
  }

  function populate(formdata) {
    let domains = formdata.domains || [];
    let searchterm = formdata.searchterm || '';
    let snippet = '';

    domains = domains.sortBy(currentSort);
    updateSortIndicators();
    for (const domain of domains) {
      let name = domain.domainname || '';
      if (searchterm) {
        name = name.replace(new RegExp(searchterm, 'gi'), '<b>$&</b>');
      }
      let dueClass = domain.due ? 'table-warning' : '';
      let dontrenewClass = domain.dontrenew ? 'text-muted' : '';

      snippet += `
        <tr data-domainid="${domain.domainid}" data-domainname="${domain.domainname}" class="${dueClass}">
          <td><input type="checkbox" class="domain-select" value="${domain.domainid}"></td>
          <td class="${dontrenewClass}"><a href="<%== url_for('customer_index') %>/${domain.customerid}/domains/${domain.domainid}">${name}</a></td>
          <td><a href="<%== url_for('customer_index') %>/${domain.customerid}">${domain.customerid}</a></td>
          <td>${domain.curexpiry || ''}</td>
        </tr>`;
    }
    document.querySelector('#domains tbody').innerHTML = snippet;
    initCheckboxHandlers();

    // Update pagination info
    const start = (formdata.page - 1) * formdata.per_page + 1;
    const end = Math.min(formdata.page * formdata.per_page, formdata.total);
    document.querySelector('#pagination-info').textContent =
      formdata.total > 0 ? `${start}-${end} <%== __('of') %> ${formdata.total}` : '';
  }

  function updatePagination(formdata) {
    const { page, pages, total } = formdata;
    if (pages <= 1) {
      document.querySelector('#pagination ul').innerHTML = '';
      return;
    }

    let html = '';

    // Previous button
    html += `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
    </li>`;

    // Page numbers (show max 7 pages with ellipsis)
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

    // Next button
    html += `<li class="page-item ${page >= pages ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
    </li>`;

    document.querySelector('#pagination ul').innerHTML = html;

    // Add click handlers
    document.querySelectorAll('#pagination a[data-page]').forEach(a => {
      a.onclick = (e) => {
        e.preventDefault();
        const p = parseInt(a.dataset.page);
        if (p >= 1 && p <= pages) {
          fetchDomains(p);
        }
      };
    });
  }

  function initCheckboxHandlers() {
    const selectAll = document.querySelector('#select-all');
    const bulkActions = document.querySelector('#bulk-actions');
    const selectedCount = document.querySelector('#selected-count');

    selectAll.checked = false;
    selectAll.onclick = () => {
      const checkboxes = document.querySelectorAll('.domain-select');
      checkboxes.forEach(cb => cb.checked = selectAll.checked);
      updateSelection();
    };

    document.querySelectorAll('.domain-select').forEach(cb => {
      cb.onclick = updateSelection;
    });

    function updateSelection() {
      const checked = document.querySelectorAll('.domain-select:checked');
      selectedCount.textContent = checked.length;
      bulkActions.style.display = checked.length > 0 ? 'block' : 'none';
    }
  }

  function getSelectedDomains() {
    const checked = document.querySelectorAll('.domain-select:checked');
    return Array.from(checked).map(cb => ({
      id: cb.value,
      name: cb.closest('tr').dataset.domainname
    }));
  }

  // Sort column headers
  function updateSortIndicators() {
    document.querySelectorAll('th.sortable').forEach(th => {
      const field = th.dataset.sort;
      const bare = currentSort.replace(/^[+-]/, '');
      const arrow = bare === field ? (currentSort[0] === '-' ? ' \u25BC' : ' \u25B2') : '';
      // Remove old indicator, add new
      th.textContent = th.textContent.replace(/ [\u25B2\u25BC]$/, '') + arrow;
      th.style.cursor = 'pointer';
    });
  }

  document.querySelector('#domains thead').addEventListener('click', (e) => {
    const th = e.target.closest('th.sortable');
    if (!th) return;
    const field = th.dataset.sort;
    const bare = currentSort.replace(/^[+-]/, '');
    if (bare === field) {
      // Toggle direction
      currentSort = currentSort[0] === '-' ? field : '-' + field;
    } else {
      currentSort = field;
    }
    setSortCookie(currentSort);
    fetchDomains(currentPage);
  });

  // Search form handler
  document.querySelector('#dataform')?.addEventListener('submit', (e) => {
    e.preventDefault();
    fetchDomains(1);
  });

  // Live search (debounced)
  let searchTimeout = null;
  searchtermInput?.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    if (searchtermInput.value.length >= 3 || searchtermInput.value.length === 0) {
      searchTimeout = setTimeout(() => fetchDomains(1), 300);
    }
  });

  // Filter change handlers
  filterStatus?.addEventListener('change', () => fetchDomains(1));
  customerFilter?.addEventListener('change', () => fetchDomains(1));

  // Bulk action handlers
  document.querySelector('#bulk-renew').onclick = () => {
    const selected = getSelectedDomains();
    if (selected.length === 0) return;
    console.log('Renew domains:', selected);
    alert('<%== __("Renew") %>: ' + selected.map(d => d.name).join(', '));
  };

  document.querySelector('#bulk-export').onclick = () => {
    const selected = getSelectedDomains();
    if (selected.length === 0) return;
    const csv = selected.map(d => d.name).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'domains.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  // Initial load
  fetchDomains(1);
})();
