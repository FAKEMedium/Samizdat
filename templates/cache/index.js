let currentPage = 1;
let currentPattern = '*';

// Universal modal elements
const universalModal = new bootstrap.Modal('#universalmodal');
const modalDialog = document.getElementById('modalDialog');

// Load cache entries from API
async function loadCacheEntries() {
  const params = new URLSearchParams({
    page: currentPage,
    limit: 50,
    pattern: currentPattern
  });

  const data = await window.authenticatedFetch(`${window.location.pathname}?${params}`, {
    method: 'GET'
  });

  if (data) {
    populateTable(data.entries);
    updatePagination(data.pagination);
  }
}

// Populate the table with cache entries
function populateTable(entries) {
  const tbody = document.querySelector('#cacheEntries tbody');

  if (!entries || entries.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" class="text-center"><%== __('No cache entries found') %></td></tr>`;
    return;
  }

  let snippet = '';
  entries.forEach(entry => {
    const ttlText = entry.ttl === -1 ? '<%== __("Never") %>' :
                    entry.ttl === -2 ? '<%== __("Not found") %>' :
                    `${entry.ttl}s`;

    snippet += `
      <tr>
        <td><code>${escapeHtml(entry.key)}</code></td>
        <td><span class="badge bg-info">${escapeHtml(entry.type)}</span></td>
        <td>${ttlText}</td>
        <td><small>${escapeHtml(entry.preview)}</small></td>
        <td class="text-end">
          <button class="btn btn-sm btn-primary btn-view" data-key="${escapeHtml(entry.key)}">
            <%== icon 'eye', {} %>
          </button>
          <button class="btn btn-sm btn-danger btn-delete" data-key="${escapeHtml(entry.key)}">
            <%== icon 'trash', {} %>
          </button>
        </td>
      </tr>
    `;
  });

  tbody.innerHTML = snippet;

  // Attach event handlers
  document.querySelectorAll('.btn-view').forEach(btn => {
    btn.addEventListener('click', async () => {
      const key = btn.getAttribute('data-key');
      await viewCacheEntry(key);
    });
  });

  document.querySelectorAll('.btn-delete').forEach(btn => {
    btn.addEventListener('click', async () => {
      const key = btn.getAttribute('data-key');
      if (confirm(`<%== __("Are you sure you want to delete this cache entry?") %>\n\n${key}`)) {
        await deleteCacheEntry(key);
      }
    });
  });
}

// View cache entry details
async function viewCacheEntry(key) {
  const data = await window.authenticatedFetch(`<%== url_for('cache_index') %>/${encodeURIComponent(key)}`, {
    method: 'GET'
  });

  if (data && data.success) {
    const entry = data.entry;

    // Load modal template
    const modalResponse = await fetch('<%== url_for('cache_index') %>/view');
    const modalHTML = await modalResponse.text();
    modalDialog.innerHTML = modalHTML;

    // Populate modal with data
    document.querySelector('#universalmodal #modalKey').textContent = entry.key;
    document.querySelector('#universalmodal #modalType').textContent = entry.type;

    const ttlText = entry.ttl === -1 ? '<%== __("Never expires") %>' :
                    entry.ttl === -2 ? '<%== __("Not found") %>' :
                    `${entry.ttl} <%== __("seconds") %>`;
    document.querySelector('#universalmodal #modalTTL').textContent = ttlText;

    // Pretty print the value
    const valueStr = typeof entry.value === 'object' ?
                     JSON.stringify(entry.value, null, 2) :
                     String(entry.value);
    document.querySelector('#universalmodal #modalValue').textContent = valueStr;

    universalModal.show();
  }
}

// Delete a cache entry
async function deleteCacheEntry(key) {
  const result = await window.authenticatedFetch(
    `<%== url_for('cache_index') %>/${encodeURIComponent(key)}`,
    { method: 'DELETE' }
  );

  if (result && result.success) {
    showToast('success', result.message);
    loadCacheEntries(); // Reload the list
  }
}

// Purge all cache entries matching pattern
async function purgeCache(confirmed = false) {
  const pattern = currentPattern;

  if (pattern === '*' && !confirmed) {
    if (!confirm('<%== __("Are you sure you want to purge ALL cache entries? This cannot be undone!") %>')) {
      return;
    }
  }

  const result = await window.authenticatedFetch(
    `<%== url_for('cache_purge') %>`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pattern: pattern, confirmed: pattern === '*' })
    }
  );

  if (result && result.success) {
    showToast('success', result.message);
    loadCacheEntries(); // Reload the list
  }
}

// Update pagination controls
function updatePagination(pagination) {
  const paginationEl = document.getElementById('pagination');

  if (!pagination || pagination.pages <= 1) {
    paginationEl.innerHTML = '';
    return;
  }

  let snippet = '';

  // Previous button
  snippet += `<li class="page-item ${currentPage === 1 ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${currentPage - 1}"><%== __('Previous') %></a>
  </li>`;

  // Page numbers
  for (let i = 1; i <= pagination.pages; i++) {
    if (i === 1 || i === pagination.pages || (i >= currentPage - 2 && i <= currentPage + 2)) {
      snippet += `<li class="page-item ${i === currentPage ? 'active' : ''}">
        <a class="page-link" href="#" data-page="${i}">${i}</a>
      </li>`;
    } else if (i === currentPage - 3 || i === currentPage + 3) {
      snippet += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
  }

  // Next button
  snippet += `<li class="page-item ${currentPage === pagination.pages ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${currentPage + 1}"><%== __('Next') %></a>
  </li>`;

  paginationEl.innerHTML = snippet;

  // Attach event handlers
  document.querySelectorAll('#pagination .page-link').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const page = parseInt(link.getAttribute('data-page'));
      if (page && page !== currentPage) {
        currentPage = page;
        loadCacheEntries();
      }
    });
  });
}

// Show toast notification
function showToast(type, message) {
  const toastHtml = `
    <div class="toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'} border-0" role="alert">
      <div class="d-flex">
        <div class="toast-body">${escapeHtml(message)}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>
  `;

  const container = document.getElementById('toast-messages');
  container.innerHTML = toastHtml;

  const toastEl = container.querySelector('.toast');
  const toast = new bootstrap.Toast(toastEl);
  toast.show();
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Search form submission
document.getElementById('searchForm').addEventListener('submit', (e) => {
  e.preventDefault();
  currentPattern = document.getElementById('pattern').value || '*';
  currentPage = 1;
  loadCacheEntries();
});

// Purge all button
document.getElementById('purgeAllBtn').addEventListener('click', () => {
  purgeCache();
});

// Initial load
loadCacheEntries();
