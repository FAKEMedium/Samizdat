(async function() {
  const filterUsername = document.getElementById('filterUsername');
  const filterDomain = document.getElementById('filterDomain');
  const filterAction = document.getElementById('filterAction');
  const logList = document.getElementById('logList');
  const pagination = document.getElementById('pagination');

  let currentPage = 1;
  let actions = [];

  // Pre-fill filters from URL params
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('username')) filterUsername.value = urlParams.get('username');
  if (urlParams.get('domain')) filterDomain.value = urlParams.get('domain');
  if (urlParams.get('action')) filterAction.value = urlParams.get('action');

  // Format timestamp for display
  function formatTimestamp(ts) {
    if (!ts) return '';
    const d = new Date(ts);
    return d.toLocaleString();
  }

  // Format action for display (e.g., create_domain -> Create Domain)
  function formatAction(action) {
    if (!action) return '';
    return action.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  }

  // Format JSON data for display
  function formatData(data) {
    if (!data) return '';
    try {
      const obj = typeof data === 'string' ? JSON.parse(data) : data;
      return Object.entries(obj)
        .map(([k, v]) => `<span class="badge bg-secondary me-1">${k}: ${v}</span>`)
        .join('');
    } catch (e) {
      return data;
    }
  }

  // Load logs
  async function loadLogs(page = 1) {
    const params = new URLSearchParams();
    params.set('page', page);
    params.set('limit', 50);

    if (filterUsername.value) params.set('username', filterUsername.value);
    if (filterDomain.value) params.set('domain', filterDomain.value);
    if (filterAction.value) params.set('action', filterAction.value);

    const data = await window.authenticatedFetch(`<%== url_for('Email.logs.index') %>?${params}`);

    if (!data) return;

    // Populate action filter if not done yet
    if (data.actions && data.actions.length && filterAction.options.length <= 1) {
      data.actions.forEach(a => {
        const opt = document.createElement('option');
        opt.value = a.action;
        opt.textContent = formatAction(a.action);
        filterAction.appendChild(opt);
      });
    }

    // Render logs
    const logs = data.data || [];
    if (logs.length === 0) {
      logList.innerHTML = '<tr><td colspan="5" class="text-center text-muted"><%== __("No log entries") %></td></tr>';
    } else {
      logList.innerHTML = logs.map(log => `
        <tr>
          <td><small>${formatTimestamp(log.timestamp)}</small></td>
          <td>${log.username || ''}</td>
          <td>${log.domain || ''}</td>
          <td>${formatAction(log.action)}</td>
          <td>${formatData(log.data)}</td>
        </tr>
      `).join('');
    }

    // Render pagination
    renderPagination(data.pagination);
    currentPage = page;
  }

  function renderPagination(p) {
    if (!p || p.pages <= 1) {
      pagination.innerHTML = '';
      return;
    }

    let html = '';

    // Previous button
    html += `<li class="page-item ${p.page <= 1 ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${p.page - 1}">&laquo;</a>
    </li>`;

    // Page numbers
    const startPage = Math.max(1, p.page - 2);
    const endPage = Math.min(p.pages, p.page + 2);

    if (startPage > 1) {
      html += `<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>`;
      if (startPage > 2) html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }

    for (let i = startPage; i <= endPage; i++) {
      html += `<li class="page-item ${i === p.page ? 'active' : ''}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>`;
    }

    if (endPage < p.pages) {
      if (endPage < p.pages - 1) html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
      html += `<li class="page-item"><a class="page-link" href="#" data-page="${p.pages}">${p.pages}</a></li>`;
    }

    // Next button
    html += `<li class="page-item ${p.page >= p.pages ? 'disabled' : ''}">
      <a class="page-link" href="#" data-page="${p.page + 1}">&raquo;</a>
    </li>`;

    pagination.innerHTML = html;
  }

  // Pagination click handler
  pagination.addEventListener('click', (e) => {
    e.preventDefault();
    const link = e.target.closest('[data-page]');
    if (link && !link.closest('.disabled')) {
      loadLogs(parseInt(link.dataset.page));
    }
  });

  // Filter handlers
  document.getElementById('applyFilters').addEventListener('click', () => loadLogs(1));
  document.getElementById('clearFilters').addEventListener('click', () => {
    filterUsername.value = '';
    filterDomain.value = '';
    filterAction.value = '';
    loadLogs(1);
  });

  // Enter key to apply filters
  [filterUsername, filterDomain].forEach(el => {
    el.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') loadLogs(1);
    });
  });

  filterAction.addEventListener('change', () => loadLogs(1));

  // Initial load
  loadLogs();
})();
