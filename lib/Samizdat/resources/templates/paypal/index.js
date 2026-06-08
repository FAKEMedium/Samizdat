% # JavaScript for PayPal panel - fetches JSON data
fetch('<%== url_for('PayPal.index') %>', {
  headers: {
    'Accept': 'application/json'
  }
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    // Update statistics cards
    const stats = data.stats;

    document.getElementById('balance-amount').textContent =
      formatCurrency(stats.balance);

    document.getElementById('completed-amount').textContent =
      formatCurrency(stats.total_completed);
    document.getElementById('completed-count').textContent =
      stats.count_completed + ' <%= __("payments") %>';

    document.getElementById('pending-amount').textContent =
      formatCurrency(stats.total_pending);
    document.getElementById('pending-count').textContent =
      stats.count_pending + ' <%= __("payments") %>';

    document.getElementById('refunded-amount').textContent =
      formatCurrency(stats.total_refunded);
    document.getElementById('failed-count').textContent =
      stats.count_refunded + ' <%= __("refunded") %>, ' + stats.count_failed + ' <%= __("failed") %>';

    // Update payments table
    const tbody = document.getElementById('payments-tbody');
    tbody.innerHTML = '';

    if (data.payments && data.payments.length > 0) {
      data.payments.forEach(payment => {
        const row = document.createElement('tr');

        // Format date
        const date = new Date(payment.created_at);
        const dateStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString();

        // Status badge color
        let statusClass = 'secondary';
        if (payment.payment_status === 'Completed') statusClass = 'success';
        else if (payment.payment_status === 'Pending') statusClass = 'warning';
        else if (payment.payment_status === 'Failed') statusClass = 'danger';
        else if (payment.payment_status === 'Refunded' || payment.payment_status === 'Reversed') statusClass = 'danger';

        row.innerHTML = `
          <td>${dateStr}</td>
          <td><small>${payment.txn_id || '-'}</small></td>
          <td><span class="badge bg-${statusClass}">${payment.payment_status || '-'}</span></td>
          <td>${payment.payer_email || '-'}</td>
          <td>${formatCurrency(payment.amount)}</td>
          <td>${payment.currency || '-'}</td>
          <td>${payment.item_number || '-'}</td>
        `;

        tbody.appendChild(row);
      });
    } else {
      tbody.innerHTML = '<tr><td colspan="7" class="text-center"><%= __("No payments found") %></td></tr>';
    }
  }
})
.catch(error => {
  console.error('Error fetching PayPal data:', error);
  document.getElementById('payments-tbody').innerHTML =
    '<tr><td colspan="7" class="text-center text-danger"><%= __("Error loading payments") %></td></tr>';
});

function formatCurrency(amount, currency = 'USD') {
  if (amount === null || amount === undefined) return '-';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency
  }).format(amount);
}

// Set default date range (last 30 days)
const today = new Date();
const thirtyDaysAgo = new Date(today);
thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

document.getElementById('start-date').value = thirtyDaysAgo.toISOString().split('T')[0];
document.getElementById('end-date').value = today.toISOString().split('T')[0];

// Fetch live transactions from PayPal API
document.getElementById('fetch-transactions').addEventListener('click', async function() {
  const startDate = document.getElementById('start-date').value;
  const endDate = document.getElementById('end-date').value;
  const tbody = document.getElementById('live-transactions-tbody');
  const infoDiv = document.getElementById('live-transactions-info');

  if (!startDate || !endDate) {
    alert('<%= __("Please select both start and end dates") %>');
    return;
  }

  // Show loading
  tbody.innerHTML = '<tr><td colspan="6" class="text-center"><%= __("Loading...") %></td></tr>';
  infoDiv.textContent = '';

  try {
    const startISO = startDate + 'T00:00:00-00:00';
    const endISO = endDate + 'T23:59:59-00:00';

    const response = await fetch(`<%== url_for('paypal_transactions') %>?start_date=${encodeURIComponent(startISO)}&end_date=${encodeURIComponent(endISO)}`, {
      headers: { 'Accept': 'application/json' }
    });

    const data = await response.json();

    if (data.success && data.transactions) {
      if (data.transactions.length > 0) {
        tbody.innerHTML = '';
        data.transactions.forEach(txn => {
          const row = document.createElement('tr');

          // Parse transaction info
          const txnInfo = txn.transaction_info || {};
          const payerInfo = txn.payer_info || {};

          // Format date
          const dateStr = txnInfo.transaction_updated_date
            ? new Date(txnInfo.transaction_updated_date).toLocaleString()
            : '-';

          // Status badge
          const status = txnInfo.transaction_status || 'Unknown';
          let statusClass = 'secondary';
          if (status === 'S') statusClass = 'success';  // Successful
          else if (status === 'P') statusClass = 'warning';  // Pending
          else if (status === 'D') statusClass = 'danger';  // Denied
          else if (status === 'V') statusClass = 'info';  // Reversed

          const statusLabels = { 'S': 'Success', 'P': 'Pending', 'D': 'Denied', 'V': 'Reversed' };

          // Amount
          const amount = txnInfo.transaction_amount?.value || '0';
          const currency = txnInfo.transaction_amount?.currency_code || 'USD';

          // Payer info
          const payerName = payerInfo.payer_name?.alternate_full_name || payerInfo.email_address || '-';

          row.innerHTML = `
            <td>${dateStr}</td>
            <td><small>${txnInfo.transaction_id || '-'}</small></td>
            <td><span class="badge bg-${statusClass}">${statusLabels[status] || status}</span></td>
            <td>${payerName}</td>
            <td>${txnInfo.transaction_subject || '-'}</td>
            <td>${formatCurrency(parseFloat(amount), currency)}</td>
          `;

          tbody.appendChild(row);
        });

        infoDiv.textContent = `<%= __("Total") %>: ${data.total_items || data.transactions.length} <%= __("transactions") %>`;
      } else {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted"><%= __("No transactions found for selected date range") %></td></tr>';
      }
    } else {
      tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger">${data.error || '<%= __("Error fetching transactions") %>'}</td></tr>`;
    }
  } catch (error) {
    console.error('Error fetching live transactions:', error);
    tbody.innerHTML = '<tr><td colspan="6" class="text-center text-danger"><%= __("Error fetching transactions") %></td></tr>';
  }
});
