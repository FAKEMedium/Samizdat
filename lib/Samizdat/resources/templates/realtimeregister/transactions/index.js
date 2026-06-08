// RealtimeRegister transactions list
const transactionsTable = document.getElementById('transactionsTable');
const tbody = transactionsTable.querySelector('tbody');
const paginationControls = document.getElementById('pagination-controls');
const apiUrl = '<%== url_for('RTR.transactions.index') %>';
const perPage = <%= $perpage %>;
const startDateInput = document.getElementById('startDate');
const endDateInput = document.getElementById('endDate');
const currentBalanceInput = document.getElementById('currentBalance');
const filterBtn = document.getElementById('filterBtn');
const balanceRow = document.getElementById('balanceRow');
const balanceInEl = document.getElementById('balanceIn');
const balanceOutEl = document.getElementById('balanceOut');
const totalInEl = document.getElementById('totalIn');
const totalOutEl = document.getElementById('totalOut');

// Default: last 30 days
const today = new Date();
const thirtyDaysAgo = new Date(today);
thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
startDateInput.value = thirtyDaysAgo.toISOString().slice(0, 10);
endDateInput.value = today.toISOString().slice(0, 10);

// Restore current balance from localStorage
const savedBalance = localStorage.getItem('rtr_current_balance');
if (savedBalance) currentBalanceInput.value = savedBalance;

currentBalanceInput.addEventListener('change', () => {
  localStorage.setItem('rtr_current_balance', currentBalanceInput.value);
});

// Format amount from cents to EUR
function formatAmount(cents) {
  const amount = cents / 100;
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}

// Format date
function formatDate(dateStr) {
  if (!dateStr) return 'N/A';
  const date = new Date(dateStr);
  return date.toLocaleDateString('sv-SE') + ' ' + date.toLocaleTimeString('sv-SE', { hour: '2-digit', minute: '2-digit' });
}

function buildFilterParams() {
  const params = new URLSearchParams();
  if (startDateInput.value) params.set('startDate', startDateInput.value);
  if (endDateInput.value) params.set('endDate', endDateInput.value);
  if (currentBalanceInput.value) params.set('currentBalance', currentBalanceInput.value);
  return params;
}

async function loadTransactions(offset = 0) {
  tbody.innerHTML = '<tr><td colspan="5" class="text-center"><div class="spinner-border spinner-border-sm" role="status"></div></td></tr>';

  try {
    const filterParams = buildFilterParams();
    const url = `${apiUrl}?limit=${perPage}&offset=${offset}&order=-date&${filterParams.toString()}`;
    const data = await window.authenticatedFetch(url);

    if (!data || !data.transactions) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-danger"><%== __('Failed to load transactions') %></td></tr>';
      return;
    }

    const transactions = data.transactions.entities || [];
    const pagination = data.transactions.pagination || {};

    // Show balance/totals info
    const hasData = data.ingoing != null || data.openingBalance != null;
    balanceRow.style.display = hasData ? '' : 'none';
    if (hasData) {
      totalInEl.textContent = data.ingoing != null ? formatAmount(data.ingoing) : '-';
      totalOutEl.textContent = data.outgoing != null ? formatAmount(data.outgoing) : '-';
      balanceInEl.textContent = data.openingBalance != null ? formatAmount(data.openingBalance) : '-';
      balanceOutEl.textContent = data.closingBalance != null ? formatAmount(data.closingBalance) : '-';
    }

    if (transactions.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-muted"><%== __('No transactions found') %></td></tr>';
      return;
    }

    tbody.innerHTML = transactions.map(t => `
      <tr class="cursor-pointer" data-id="${t.id}">
        <td>${formatDate(t.date)}</td>
        <td>${t.processType || 'N/A'}</td>
        <td><code>${t.processIdentifier || 'N/A'}</code></td>
        <td>${t.processAction || 'N/A'}</td>
        <td class="text-end ${(t.chargesPerAccount?.EUR || 0) < 0 ? 'text-danger' : ''}">${formatAmount(t.chargesPerAccount?.EUR || 0)}</td>
      </tr>
    `).join('');

    // Update pagination
    updatePagination(pagination, offset);

  } catch (error) {
    console.error('Error loading transactions:', error);
    tbody.innerHTML = '<tr><td colspan="5" class="text-danger"><%== __('Error loading transactions') %></td></tr>';
  }
}

function updatePagination(pagination, offset) {
  if (!paginationControls) return;

  const total = pagination.total || 0;
  const limit = pagination.limit || perPage;
  const currentPage = Math.floor(offset / limit) + 1;
  const totalPages = Math.ceil(total / limit);

  if (totalPages <= 1) {
    paginationControls.innerHTML = '';
    return;
  }

  let items = '';

  // Previous button
  items += `<li class="page-item ${currentPage === 1 ? 'disabled' : ''}">
    <a class="page-link" href="#" data-offset="${offset - limit}" aria-label="<%== __('Previous') %>">
      <%== icon 'chevron-left' %>
    </a>
  </li>`;

  // Page numbers (show max 5 pages around current)
  const startPage = Math.max(1, currentPage - 2);
  const endPage = Math.min(totalPages, currentPage + 2);

  for (let i = startPage; i <= endPage; i++) {
    items += `<li class="page-item ${i === currentPage ? 'active' : ''}">
      <a class="page-link" href="#" data-offset="${(i - 1) * limit}">${i}</a>
    </li>`;
  }

  // Next button
  items += `<li class="page-item ${currentPage === totalPages ? 'disabled' : ''}">
    <a class="page-link" href="#" data-offset="${offset + limit}" aria-label="<%== __('Next') %>">
      <%== icon 'chevron-right' %>
    </a>
  </li>`;

  paginationControls.innerHTML = `<ul class="pagination pagination-sm mb-0">${items}</ul>`;
}

// Event delegation for row clicks
tbody.addEventListener('click', (e) => {
  const row = e.target.closest('tr[data-id]');
  if (row) {
    window.location = `<%== url_for('rtr_transactions') %>/${row.dataset.id}`;
  }
});

// Event delegation for pagination
paginationControls?.addEventListener('click', (e) => {
  e.preventDefault();
  const link = e.target.closest('a[data-offset]');
  if (link && !link.closest('.disabled')) {
    loadTransactions(parseInt(link.dataset.offset, 10));
  }
});

// Filter button
filterBtn.addEventListener('click', () => loadTransactions(0));

// Initial load
loadTransactions(0);
