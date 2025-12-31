% # JavaScript for Nets Payments panel - fetches JSON data
fetch('<%== url_for('Nets.payments.index') %>', {
  headers: {
    'Accept': 'application/json'
  }
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    // Update statistics cards
    const stats = data.statistics;

    document.getElementById('total-amount').textContent =
      formatCurrency(stats.total_charged / 100);
    document.getElementById('total-count').textContent =
      stats.total_payments + ' <%= __("payments") %>';

    document.getElementById('charged-amount').textContent =
      formatCurrency(stats.total_charged / 100);
    document.getElementById('charged-count').textContent =
      stats.charged_payments + ' <%= __("charged") %>';

    document.getElementById('refunded-amount').textContent =
      formatCurrency(stats.total_refunded / 100);

    document.getElementById('net-amount').textContent =
      formatCurrency(stats.net_amount / 100);

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
        if (payment.status === 'charged') statusClass = 'success';
        else if (payment.status === 'created' || payment.status === 'pending') statusClass = 'warning';
        else if (payment.status === 'cancelled' || payment.status === 'failed') statusClass = 'danger';

        row.innerHTML = `
          <td>${dateStr}</td>
          <td><small>${payment.payment_id || '-'}</small></td>
          <td>${payment.reference || '-'}</td>
          <td><span class="badge bg-${statusClass}">${payment.status || '-'}</span></td>
          <td>${formatCurrency(payment.amount / 100)}</td>
          <td>${payment.charged_amount ? formatCurrency(payment.charged_amount / 100) : '-'}</td>
          <td>${payment.refunded_amount ? formatCurrency(payment.refunded_amount / 100) : '-'}</td>
          <td>${payment.payment_method || '-'}</td>
        `;

        tbody.appendChild(row);
      });
    } else {
      tbody.innerHTML = '<tr><td colspan="8" class="text-center"><%= __("No payments found") %></td></tr>';
    }
  }
})
.catch(error => {
  console.error('Error fetching Nets data:', error);
  document.getElementById('payments-tbody').innerHTML =
    '<tr><td colspan="8" class="text-center text-danger"><%= __("Error loading payments") %></td></tr>';
});

function formatCurrency(amount) {
  if (amount === null || amount === undefined) return '-';
  return new Intl.NumberFormat('sv-SE', {
    style: 'currency',
    currency: 'SEK'
  }).format(amount);
}
