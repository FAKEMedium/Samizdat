% # JavaScript for Swish panel - fetches JSON data
fetch('<%== url_for('Swish.index') %>', {
  headers: {
    'Accept': 'application/json'
  }
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    // Update statistics cards
    const stats = data.stats;

    document.getElementById('paid-amount').textContent =
      formatCurrency(stats.total_paid);
    document.getElementById('paid-count').textContent =
      stats.count_paid + ' <%= __("payments") %>';

    document.getElementById('pending-amount').textContent =
      formatCurrency(stats.total_pending);
    document.getElementById('pending-count').textContent =
      stats.count_pending + ' <%= __("payments") %>';

    document.getElementById('declined-amount').textContent =
      formatCurrency(stats.total_declined);
    document.getElementById('declined-count').textContent =
      stats.count_declined + ' <%= __("declined") %>';

    document.getElementById('error-amount').textContent =
      formatCurrency(stats.total_error);
    document.getElementById('error-count').textContent =
      stats.count_error + ' <%= __("errors") %>';

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
        if (payment.status === 'PAID') statusClass = 'success';
        else if (payment.status === 'CREATED') statusClass = 'warning';
        else if (payment.status === 'DECLINED') statusClass = 'secondary';
        else if (payment.status === 'ERROR' || payment.status === 'CANCELLED') statusClass = 'danger';

        // Flow type badge
        let flowClass = payment.flow_type === 'mcommerce' ? 'info' : 'primary';

        row.innerHTML = `
          <td>${dateStr}</td>
          <td><small>${payment.instruction_id || '-'}</small></td>
          <td><span class="badge bg-${statusClass}">${payment.status || '-'}</span></td>
          <td><span class="badge bg-${flowClass}">${payment.flow_type || '-'}</span></td>
          <td>${payment.payer_alias || payment.payer_name || '-'}</td>
          <td>${formatCurrency(payment.amount / 100)}</td>
          <td>${payment.message || '-'}</td>
        `;

        tbody.appendChild(row);
      });
    } else {
      tbody.innerHTML = '<tr><td colspan="7" class="text-center"><%= __("No payments found") %></td></tr>';
    }
  }
})
.catch(error => {
  console.error('Error fetching Swish data:', error);
  document.getElementById('payments-tbody').innerHTML =
    '<tr><td colspan="7" class="text-center text-danger"><%= __("Error loading payments") %></td></tr>';
});

function formatCurrency(amount) {
  if (amount === null || amount === undefined) return '-';
  return new Intl.NumberFormat('sv-SE', {
    style: 'currency',
    currency: 'SEK'
  }).format(amount);
}
