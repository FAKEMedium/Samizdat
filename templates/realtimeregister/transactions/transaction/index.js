// RealtimeRegister transaction detail
const transactionDetails = document.getElementById('transactionDetails');
const id = window.location.pathname.split('/').pop();
const apiUrl = `<%== url_for('RTR.transactions.index') %>/${id}`;

function formatAmount(cents) {
  const amount = cents / 100;
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount);
}

function formatDate(dateStr) {
  if (!dateStr) return 'N/A';
  const date = new Date(dateStr);
  return date.toLocaleDateString('sv-SE') + ' ' + date.toLocaleTimeString('sv-SE');
}

fetch(apiUrl, {
  headers: { 'Accept': 'application/json' },
  credentials: 'same-origin'
})
.then(response => response.json())
.then(data => {
  if (!data.transaction) {
    transactionDetails.innerHTML = '<p class="text-danger"><%== __('Transaction not found') %></p>';
    return;
  }

  const t = data.transaction;
  document.title = `<%== __('Transaction') %> #${t.id}`;

  let html = `
    <h2 class="h5"><%== __('Transaction') %> #${t.id}</h2>
    <dl class="row">
      <dt class="col-sm-3"><%== __('Date') %></dt>
      <dd class="col-sm-9">${formatDate(t.date)}</dd>

      <dt class="col-sm-3"><%== __('Amount') %></dt>
      <dd class="col-sm-9 ${(t.chargesPerAccount?.EUR || 0) < 0 ? 'text-danger' : ''}">${formatAmount(t.chargesPerAccount?.EUR || 0)}</dd>

      <dt class="col-sm-3"><%== __('Type') %></dt>
      <dd class="col-sm-9">${t.processType || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Identifier') %></dt>
      <dd class="col-sm-9"><code>${t.processIdentifier || 'N/A'}</code></dd>

      <dt class="col-sm-3"><%== __('Action') %></dt>
      <dd class="col-sm-9">${t.processAction || 'N/A'}</dd>

      <dt class="col-sm-3"><%== __('Process ID') %></dt>
      <dd class="col-sm-9">${t.processId || 'N/A'}</dd>
    </dl>
  `;

  if (t.billables && t.billables.length > 0) {
    html += `
      <h3 class="h6 mt-4"><%== __('Billable Items') %></h3>
      <table class="table table-sm">
        <thead><tr><th><%== __('Product') %></th><th><%== __('Action') %></th><th><%== __('Qty') %></th><th class="text-end"><%== __('Amount') %></th></tr></thead>
        <tbody>
          ${t.billables.map(b => `
            <tr>
              <td>${b.product}</td>
              <td>${b.action}</td>
              <td>${b.quantity}</td>
              <td class="text-end">${formatAmount(b.amount)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  }

  transactionDetails.innerHTML = html;
})
.catch(error => {
  console.error('Error loading transaction:', error);
  transactionDetails.innerHTML = '<p class="text-danger"><%== __('Error loading transaction') %></p>';
});
