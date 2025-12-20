let currentPage = 1;

async function loadPayments(page = 1) {
  currentPage = page;
  try {
    const response = await fetch(`<%== url_for('Fortnox.payments.index') %>?page=${page}`, {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });

    const data = await response.json();

    if (data.fortnox && data.fortnox.payment) {
      const payments = data.fortnox.payment.InvoicePayments || [];
      const perpage = data.fortnox.perpage || 25;
      const tbody = document.querySelector('#payments tbody');
      let html = '';
      let total = 0;

      // Data comes sorted from API (descending by paymentdate)
      payments.forEach(payment => {
        const invoiceNumber = payment.InvoiceNumber || '';
        const customerName = payment.CustomerName || '';
        const date = payment.PaymentDate || '';
        const amount = parseFloat(payment.Amount) || 0;
        total += amount;

        html += `
          <tr>
            <td><a href="<%== url_for('fortnox_invoice') %>/${invoiceNumber}">${invoiceNumber}</a></td>
            <td>${customerName}</td>
            <td>${date}</td>
            <td class="text-end">${amount.toFixed(2)}</td>
          </tr>
        `;
      });

      tbody.innerHTML = html || '<tr><td colspan="4" class="text-muted text-center"><%== __("No payments found") %></td></tr>';

      // Update footer with total and pagination
      const tfoot = document.querySelector('#payments tfoot th');
      const hasMore = payments.length >= perpage;
      const hasPrev = page > 1;

      let footerHtml = `<%== __('Total') %>: ${total.toFixed(2)}`;
      if (hasPrev || hasMore) {
        footerHtml += ' <span class="float-end">';
        if (hasPrev) {
          footerHtml += `<a href="#" class="btn-prev">&laquo; <%== __('Previous') %></a>`;
        }
        footerHtml += ` <%== __('Page') %> ${page} `;
        if (hasMore) {
          footerHtml += `<a href="#" class="btn-next"><%== __('Next') %> &raquo;</a>`;
        }
        footerHtml += '</span>';
      }
      tfoot.innerHTML = footerHtml;

      // Attach event listeners for pagination
      const prevBtn = tfoot.querySelector('.btn-prev');
      const nextBtn = tfoot.querySelector('.btn-next');
      if (prevBtn) prevBtn.addEventListener('click', (e) => { e.preventDefault(); loadPayments(page - 1); });
      if (nextBtn) nextBtn.addEventListener('click', (e) => { e.preventDefault(); loadPayments(page + 1); });
    }
  } catch (error) {
    console.error('Failed to load payments:', error);
  }
}

// Load payments on page load
loadPayments();
