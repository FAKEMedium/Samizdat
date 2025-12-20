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

function formatCurrency(amount) {
  if (amount === null || amount === undefined) return '-';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(amount);
}
