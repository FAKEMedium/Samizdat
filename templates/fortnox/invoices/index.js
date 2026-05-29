let currentPage = 1;

async function loadInvoices(page = 1) {
  currentPage = page;
  try {
    const response = await fetch(`<%== url_for('Fortnox.invoices.index') %>?page=${page}`, {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });

    const data = await response.json();

    // Handle Fortnox auth redirect
    if (response.status === 401 && data.auth_url) {
      // Handled by the global fetch interceptor (apidom.js), which routes
      // through /fortnox/auth so the server returns us here afterwards.
      return;
    }

    if (data.fortnox && data.fortnox.invoice) {
      const invoices = data.fortnox.invoice.Invoices || [];
      const meta = data.fortnox.invoice.MetaInformation || {};
      const perpage = data.fortnox.perpage || 25;
      const totalPages = meta['@TotalPages'] || 1;
      const tbody = document.querySelector('#invoices tbody');
      let html = '';
      let totalAmount = 0;
      let totalBalance = 0;

      const invoiceUrlTemplate = "<%== url_for('Fortnox.invoices.get', invoiceid => '_ID_') %>";
      invoices.forEach(invoice => {
        const invoiceNumber = invoice.DocumentNumber || '';
        const customerName = invoice.CustomerName || '';
        const invoiceDate = invoice.InvoiceDate || '';
        const dueDate = invoice.DueDate || '';
        const total = parseFloat(invoice.Total) || 0;
        const balance = parseFloat(invoice.Balance) || 0;
        totalAmount += total;
        totalBalance += balance;

        const rowClass = balance > 0 ? 'table-warning' : '';

        html += `
          <tr class="${rowClass}">
            <td><a href="${invoiceUrlTemplate.replace('_ID_', invoiceNumber)}">${invoiceNumber}</a></td>
            <td>${customerName}</td>
            <td>${invoiceDate}</td>
            <td>${dueDate}</td>
            <td class="text-end">${total.toFixed(2)}</td>
            <td class="text-end">${balance.toFixed(2)}</td>
          </tr>
        `;
      });

      tbody.innerHTML = html || '<tr><td colspan="6" class="text-muted text-center"><%== __("No invoices found") %></td></tr>';

      // Update totals
      document.querySelector('#invoiceTotals').innerHTML =
        `<%== __('Total') %>: ${totalAmount.toFixed(2)} | <%== __('Balance') %>: ${totalBalance.toFixed(2)}`;

      // Build Bootstrap pagination
      const pagination = document.querySelector('#invoicePagination');
      let paginationHtml = '';

      // Previous button
      paginationHtml += `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
        <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
      </li>`;

      // Page numbers (show max 5 pages around current)
      const startPage = Math.max(1, page - 2);
      const endPage = Math.min(totalPages, page + 2);

      if (startPage > 1) {
        paginationHtml += `<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>`;
        if (startPage > 2) {
          paginationHtml += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
        }
      }

      for (let i = startPage; i <= endPage; i++) {
        paginationHtml += `<li class="page-item ${i === page ? 'active' : ''}">
          <a class="page-link" href="#" data-page="${i}">${i}</a>
        </li>`;
      }

      if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
          paginationHtml += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
        }
        paginationHtml += `<li class="page-item"><a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a></li>`;
      }

      // Next button
      paginationHtml += `<li class="page-item ${page >= totalPages ? 'disabled' : ''}">
        <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
      </li>`;

      pagination.innerHTML = paginationHtml;

      // Attach click handlers
      pagination.querySelectorAll('a.page-link').forEach(link => {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          const targetPage = parseInt(link.dataset.page);
          if (targetPage >= 1 && targetPage <= totalPages && targetPage !== page) {
            loadInvoices(targetPage);
          }
        });
      });
    }
  } catch (error) {
    console.error('Failed to load invoices:', error);
  }
}

loadInvoices();
