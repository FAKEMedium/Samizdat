% # JavaScript for Stripe panel - fetches JSON data
fetch('<%== url_for('Stripe.payments.list') %>', {
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

    document.getElementById('succeeded-amount').textContent =
      formatCurrency(stats.total_succeeded);
    document.getElementById('succeeded-count').textContent =
      stats.count_succeeded + ' <%= __("payments") %>';

    document.getElementById('pending-amount').textContent =
      formatCurrency(stats.total_pending);
    document.getElementById('pending-count').textContent =
      stats.count_pending + ' <%= __("payments") %>';

    document.getElementById('failed-amount').textContent =
      formatCurrency(stats.total_failed + stats.total_refunded);
    document.getElementById('failed-count').textContent =
      stats.count_failed + ' <%= __("failed") %>, ' + stats.count_refunded + ' <%= __("refunded") %>';

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
        if (payment.status === 'succeeded') statusClass = 'success';
        else if (payment.status === 'pending' || payment.status === 'created') statusClass = 'warning';
        else if (payment.status === 'failed') statusClass = 'danger';
        else if (payment.status === 'canceled') statusClass = 'secondary';

        row.innerHTML = `
          <td>${dateStr}</td>
          <td><small>${payment.payment_intent_id || payment.checkout_session_id || '-'}</small></td>
          <td><span class="badge bg-${statusClass}">${payment.status || '-'}</span></td>
          <td>${payment.payment_method_type || '-'}</td>
          <td>${payment.customer_email || '-'}</td>
          <td>${formatCurrency(payment.amount / 100)}</td>
          <td>${payment.description || '-'}</td>
        `;

        tbody.appendChild(row);
      });
    } else {
      tbody.innerHTML = '<tr><td colspan="7" class="text-center"><%= __("No payments found") %></td></tr>';
    }
  }
})
.catch(error => {
  console.error('Error fetching Stripe data:', error);
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
