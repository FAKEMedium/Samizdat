async function loadPayments(refresh = false) {
  try {
    const url = refresh
      ? `<%== url_for('Fortnox.payments.index') %>?refresh=1`
      : `<%== url_for('Fortnox.payments.index') %>`;
    const response = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });

    const data = await response.json();

    // Handle Fortnox auth redirect (401 with auth_url)
    if (response.status === 401 && data.auth_url) {
      window.location.href = data.auth_url;
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
      const payments = data.fortnox.payment.InvoicePayments || [];
      const unpaidInvoices = data.fortnox.unpaid_invoices || {};
      const tbody = document.querySelector('#payments tbody');
      let html = '';
      let total = 0;
      let count = 0;

      // Filter payments to only those matching unpaid local invoices
      payments.forEach(payment => {
        const invoiceNumber = payment.InvoiceNumber || '';
        const localInvoice = unpaidInvoices[invoiceNumber];
        if (!localInvoice) return; // Skip if already paid locally

        const invoiceid = localInvoice.invoiceid || '';
        const customerid = localInvoice.customerid || '';
        const customerName = localInvoice.customername || '';
        const debt = parseFloat(localInvoice.debt) || 0;
        const date = payment.PaymentDate || '';
        const amount = parseFloat(payment.Amount) || 0;
        const paymentNumber = payment.Number || '';
        total += amount;
        count++;

        html += `
          <tr>
            <td><input type="checkbox" class="form-check-input payment-checkbox"
                       data-invoice="${invoiceNumber}"
                       data-amount="${amount}"
                       data-date="${date}"
                       data-number="${paymentNumber}"></td>
            <td><a href="<%== url_for('invoice_handle', invoiceid => '__ID__') =~ s/__ID__//r %>${invoiceid}">${invoiceNumber}</a></td>
            <td><a href="<%== url_for('customer_edit', customerid => '__ID__') =~ s/__ID__//r %>${customerid}">${customerName}</a></td>
            <td>${date}</td>
            <td class="text-end">${debt.toFixed(2)}</td>
            <td class="text-end">${amount.toFixed(2)}</td>
          </tr>
        `;
      });

      if (count === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-muted text-center"><%== __("No unprocessed payments") %></td></tr>';
        document.querySelector('#processSelected').style.display = 'none';
      } else {
        tbody.innerHTML = html;
        document.querySelector('#processSelected').style.display = 'inline-block';
      }

      // Update totals
      document.querySelector('#paymentTotals').innerHTML = `<%== __('Total') %>: ${total.toFixed(2)} (${count} <%== __('payments') %>)`;

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
    const response = await fetch('<%== url_for('Fortnox.payments.index') %>', {
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
      loadPayments(); // Reload to show updated list
    } else {
      alert(result.error || '<%== __("Processing failed") %>');
    }
  } catch (error) {
    console.error('Failed to process payments:', error);
    alert('<%== __("Processing failed") %>');
  }
}

document.querySelector('#processSelected').addEventListener('click', processSelected);
document.querySelector('#refreshPayments').addEventListener('click', () => loadPayments(true));
loadPayments();
