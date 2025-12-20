let currentPage = 1;

async function loadInvoices(page = 1) {
  currentPage = page;
  try {
    const response = await fetch(`<%== url_for('Fortnox.invoices.index') %>?page=${page}`, {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });

    const data = await response.json();

    if (data.fortnox && data.fortnox.invoice) {
      const invoices = data.fortnox.invoice.Invoices || [];
      const perpage = data.fortnox.perpage || 25;
      const tbody = document.querySelector('#invoices tbody');
      let html = '';
      let totalAmount = 0;
      let totalBalance = 0;

      // Data comes sorted from API (descending by invoicedate)
      invoices.forEach(invoice => {
        const invoiceNumber = invoice.DocumentNumber || '';
        const customerName = invoice.CustomerName || '';
        const invoiceDate = invoice.InvoiceDate || '';
        const dueDate = invoice.DueDate || '';
        const total = parseFloat(invoice.Total) || 0;
        const balance = parseFloat(invoice.Balance) || 0;
        totalAmount += total;
        totalBalance += balance;

        // Highlight unpaid invoices
        const rowClass = balance > 0 ? 'table-warning' : '';

        html += `
          <tr class="${rowClass}">
            <td><a href="<%== url_for('fortnox_invoice') %>/${invoiceNumber}">${invoiceNumber}</a></td>
            <td>${customerName}</td>
            <td>${invoiceDate}</td>
            <td>${dueDate}</td>
            <td class="text-end">${total.toFixed(2)}</td>
            <td class="text-end">${balance.toFixed(2)}</td>
          </tr>
        `;
      });

      tbody.innerHTML = html || '<tr><td colspan="6" class="text-muted text-center"><%== __("No invoices found") %></td></tr>';

      // Update footer with totals and pagination
      const tfoot = document.querySelector('#invoices tfoot th');
      const hasMore = invoices.length >= perpage;
      const hasPrev = page > 1;

      let footerHtml = `<%== __('Total') %>: ${totalAmount.toFixed(2)} | <%== __('Balance') %>: ${totalBalance.toFixed(2)}`;
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
      if (prevBtn) prevBtn.addEventListener('click', (e) => { e.preventDefault(); loadInvoices(page - 1); });
      if (nextBtn) nextBtn.addEventListener('click', (e) => { e.preventDefault(); loadInvoices(page + 1); });
    }
  } catch (error) {
    console.error('Failed to load invoices:', error);
  }
}

// Load invoices on page load
loadInvoices();
