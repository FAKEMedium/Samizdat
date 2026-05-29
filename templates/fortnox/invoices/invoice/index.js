async function loadInvoice() {
  try {
    const invoiceid = window.location.pathname.split('/').pop();
    const response = await fetch(`<%== url_for('Fortnox.invoices.get', invoiceid => '_IID_') %>`.replace('_IID_', invoiceid), {
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
      const invoice = data.fortnox.invoice.Invoice || data.fortnox.invoice;
      populateInvoiceDetails(invoice);
    }
  } catch (error) {
    console.error('Failed to load invoice:', error);
  }
}

// Translation map for invoice types from Fortnox API
const invoiceTypeTranslations = {
  'INVOICE': '<%== __("Invoice") %>',
  'CREDIT': '<%== __("Credit invoice") %>',
  'CASH': '<%== __("Cash invoice") %>',
  'INTEREST': '<%== __("Interest invoice") %>'
};

function populateInvoiceDetails(invoice) {
  // Invoice Details
  document.getElementById('documentNumber').textContent = invoice.DocumentNumber || '';
  document.getElementById('invoiceDate').textContent = invoice.InvoiceDate || '';
  document.getElementById('dueDate').textContent = invoice.DueDate || '';
  document.getElementById('termsOfPayment').textContent = invoice.TermsOfPayment || '';
  document.getElementById('currency').textContent = invoice.Currency || '';
  const invoiceType = invoice.InvoiceType || '';
  document.getElementById('invoiceType').textContent = invoiceTypeTranslations[invoiceType] || invoiceType;

  // Customer Info
  document.getElementById('customerNumber').textContent = invoice.CustomerNumber || '';
  document.getElementById('customerName').textContent = invoice.CustomerName || '';
  document.getElementById('yourReference').textContent = invoice.YourReference || '';
  document.getElementById('ourReference').textContent = invoice.OurReference || '';

  // Delivery Address
  document.getElementById('deliveryName').textContent = invoice.DeliveryName || '';
  document.getElementById('deliveryAddress').textContent = [invoice.DeliveryAddress1, invoice.DeliveryAddress2].filter(Boolean).join(', ') || '';
  document.getElementById('deliveryZipCode').textContent = invoice.DeliveryZipCode || '';
  document.getElementById('deliveryCity').textContent = invoice.DeliveryCity || '';
  document.getElementById('deliveryCountry').textContent = invoice.DeliveryCountry || '';

  // Totals
  const net = parseFloat(invoice.Net) || 0;
  const vat = parseFloat(invoice.TotalVAT) || 0;
  const total = parseFloat(invoice.Total) || 0;
  const balance = parseFloat(invoice.Balance) || 0;
  const booked = total - balance;

  document.getElementById('net').textContent = net.toFixed(2);
  document.getElementById('vat').textContent = vat.toFixed(2);
  document.getElementById('total').textContent = total.toFixed(2);
  document.getElementById('balance').textContent = balance.toFixed(2);
  document.getElementById('booked').textContent = booked.toFixed(2);

  // Remarks
  document.getElementById('remarks').textContent = invoice.Remarks || '';

  // Invoice Rows
  const tbody = document.querySelector('#invoiceRows tbody');
  let rowsHtml = '';

  if (invoice.InvoiceRows && invoice.InvoiceRows.length) {
    invoice.InvoiceRows.forEach(row => {
      const articleNumber = row.ArticleNumber || '';
      const description = row.Description || '';
      const quantity = parseFloat(row.DeliveredQuantity) || 0;
      const price = parseFloat(row.Price) || 0;
      const discount = parseFloat(row.Discount) || 0;
      const rowTotal = parseFloat(row.Total) || 0;

      rowsHtml += `
        <tr>
          <td>${articleNumber}</td>
          <td>${description}</td>
          <td class="text-end">${quantity}</td>
          <td class="text-end">${price.toFixed(2)}</td>
          <td class="text-end">${discount ? discount + '%' : ''}</td>
          <td class="text-end">${rowTotal.toFixed(2)}</td>
        </tr>
      `;
    });
  } else {
    rowsHtml = '<tr><td colspan="6" class="text-muted text-center"><%== __("No invoice rows") %></td></tr>';
  }

  tbody.innerHTML = rowsHtml;

  // Update page title
  const modalTitle = document.querySelector('.modal-title');
  if (modalTitle) {
    modalTitle.textContent = `<%== __('Invoice') %>: ${invoice.DocumentNumber || ''}`;
  }

  // Set navigation links
  const docNum = invoice.DocumentNumber;
  if (docNum) {
    document.getElementById('nav-prev').href = `<%== url_for('Fortnox.invoices.navigate', invoiceid => '_IID_', direction => 'prev') %>`.replace('_IID_', docNum);
    document.getElementById('nav-next').href = `<%== url_for('Fortnox.invoices.navigate', invoiceid => '_IID_', direction => 'next') %>`.replace('_IID_', docNum);
  }
}

// Load invoice on page load
loadInvoice();
