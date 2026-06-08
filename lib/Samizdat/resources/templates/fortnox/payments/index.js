let currentView = 'unprocessed';
let currentPage = 1;

async function loadPayments(page = 1, refresh = false) {
  try {
    let url = `<%== url_for('Fortnox.payments.index') %>?page=${page}`;
    if (refresh) url += '&refresh=1';
    const response = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });

    const data = await response.json();

    // Handle Fortnox auth redirect (401 with auth_url)
    if (response.status === 401 && data.auth_url) {
      // Handled by the global fetch interceptor (apidom.js), which routes
      // through /fortnox/auth so the server returns us here afterwards.
      return;
    }

    // Check for Fortnox authorization error (403, ErrorInformation, or empty payment response)
    if (response.status === 403 || data.ErrorInformation ||
        (data.fortnox && data.fortnox.payment && !data.fortnox.payment.InvoicePayments)) {
      if (confirm('<%== __("Fortnox authorization required") %>')) {
        window.location.href = '<%== url_for('fortnox_auth') %>';
      }
      return;
    }

    if (data.fortnox && data.fortnox.payment) {
      const allPayments = data.fortnox.payment.InvoicePayments || [];
      const unprocessedPayments = data.fortnox.unprocessed_payments || [];
      const unpaidInvoices = data.fortnox.unpaid_invoices || {};
      const perpage = data.fortnox.perpage || 25;
      const tbody = document.querySelector('#payments tbody');

      let payments;
      if (currentView === 'unprocessed') {
        payments = unprocessedPayments;
      } else {
        payments = [...allPayments].sort((a, b) => {
          const aNum = parseInt(a.InvoiceNumber) || 0;
          const bNum = parseInt(b.InvoiceNumber) || 0;
          return bNum - aNum;
        });
      }

      let html = '';
      let total = 0;
      let count = 0;

      payments.forEach(payment => {
        const invoiceNumber = payment.InvoiceNumber || '';
        const localInvoice = unpaidInvoices[invoiceNumber];
        const customerName = localInvoice ? localInvoice.customername : '';
        const debt = localInvoice ? parseFloat(localInvoice.debt) || 0 : 0;
        const invoiceid = localInvoice ? localInvoice.invoiceid : '';
        const customerid = localInvoice ? localInvoice.customerid : '';
        const date = payment.PaymentDate || '';
        const amount = parseFloat(payment.Amount) || 0;
        const paymentNumber = payment.Number || '';
        total += amount;
        count++;

        const showCheckbox = currentView === 'unprocessed' && localInvoice;

        html += `
          <tr>
            <td>${showCheckbox ? `<input type="checkbox" class="form-check-input payment-checkbox"
                       data-invoice="${invoiceNumber}"
                       data-amount="${amount}"
                       data-date="${date}"
                       data-number="${paymentNumber}">` : ''}</td>
            <td>${invoiceid
              ? `<a href="<%== url_for('invoice_handle', invoiceid => '__ID__') =~ s/__ID__//r %>${invoiceid}">${invoiceNumber}</a>`
              : invoiceNumber}</td>
            <td>${customerid
              ? `<a href="<%== url_for('customer_edit', customerid => '__ID__') =~ s/__ID__//r %>${customerid}">${customerName}</a>`
              : customerName}</td>
            <td>${date}</td>
            <td class="text-end">${debt ? debt.toFixed(2) : ''}</td>
            <td class="text-end">${amount.toFixed(2)}</td>
          </tr>
        `;
      });

      if (count === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-muted text-center"><%== __("No payments") %></td></tr>';
        document.querySelector('#processSelected').style.display = 'none';
      } else {
        tbody.innerHTML = html;
        document.querySelector('#processSelected').style.display = currentView === 'unprocessed' ? 'inline-block' : 'none';
      }

      document.querySelector('#selectAll').style.display = currentView === 'unprocessed' ? '' : 'none';
      document.querySelector('#paymentTotals').innerHTML = `<%== __('Total') %>: ${total.toFixed(2)} (${count} <%== __('payments') %>)`;

      // Pagination for "all" view
      const paginationNav = document.querySelector('#paginationNav');
      if (currentView === 'all' && allPayments.length >= perpage) {
        paginationNav.style.display = '';
        renderPagination(page, allPayments.length >= perpage);
      } else {
        paginationNav.style.display = 'none';
      }

      // Select all checkbox handler
      document.querySelector('#selectAll')?.addEventListener('change', (e) => {
        document.querySelectorAll('.payment-checkbox').forEach(cb => {
          cb.checked = e.target.checked;
        });
      });
    }
  } catch (error) {
    console.error('Failed to load payments:', error);
  }
}

function renderPagination(page, hasMore) {
  const ul = document.querySelector('#pagination');
  let html = '';
  if (page > 1) {
    html += `<li class="page-item"><a class="page-link" href="#" data-page="${page - 1}">&laquo;</a></li>`;
  }
  html += `<li class="page-item active"><span class="page-link">${page}</span></li>`;
  if (hasMore) {
    html += `<li class="page-item"><a class="page-link" href="#" data-page="${page + 1}">&raquo;</a></li>`;
  }
  ul.innerHTML = html;
  ul.querySelectorAll('a[data-page]').forEach(a => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      currentPage = parseInt(a.dataset.page);
      loadPayments(currentPage);
    });
  });
}

async function processSelected() {
  const selected = [];
  document.querySelectorAll('.payment-checkbox:checked').forEach(cb => {
    selected.push({
      invoiceNumber: cb.dataset.invoice,
      amount: cb.dataset.amount,
      date: cb.dataset.date,
      number: cb.dataset.number
    });
  });

  if (selected.length === 0) {
    alert('<%== __("No payments selected") %>');
    return;
  }

  if (!confirm(`<%== __("Process") %> ${selected.length} <%== __("payments") %>?`)) {
    return;
  }

  try {
    const response = await fetch('<%== url_for('Fortnox.payments.process') %>', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({ payments: selected })
    });

    const result = await response.json();
    if (result.success) {
      alert(`<%== __("Processed") %> ${result.processed} <%== __("payments") %>`);
      loadPayments();
    } else {
      alert(result.error || '<%== __("Processing failed") %>');
    }
  } catch (error) {
    console.error('Failed to process payments:', error);
    alert('<%== __("Processing failed") %>');
  }
}

document.querySelector('#tabUnprocessed').addEventListener('click', (e) => {
  e.preventDefault();
  currentView = 'unprocessed';
  currentPage = 1;
  document.querySelector('#tabUnprocessed').classList.add('active');
  document.querySelector('#tabAll').classList.remove('active');
  loadPayments();
});

document.querySelector('#tabAll').addEventListener('click', (e) => {
  e.preventDefault();
  currentView = 'all';
  currentPage = 1;
  document.querySelector('#tabAll').classList.add('active');
  document.querySelector('#tabUnprocessed').classList.remove('active');
  loadPayments();
});

document.querySelector('#processSelected').addEventListener('click', processSelected);
document.querySelector('#refreshPayments').addEventListener('click', () => loadPayments(currentPage, true));
loadPayments();
