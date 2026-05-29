// Payment modal shared functionality
window.openPaymentModal = function(invoiceData) {
  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  if (!modalDialog) {
    console.error('Modal dialog not found');
    return;
  }

  // Fetch and inject the payment modal content
  const modalUrl = '<%== url_for("invoice_payment_modal") %>';

  fetch(modalUrl, {
    headers: { 'Accept': 'text/html' }
  })
  .then(response => response.text())
  .then(html => {
    modalDialog.innerHTML = html;

    // Populate the modal with invoice data
    document.getElementById('payment-customer').textContent = invoiceData.customerName || '';
    document.getElementById('payment-invoice-number').textContent = invoiceData.fakturanummer || '';
    document.getElementById('payment-invoice-date').textContent = invoiceData.invoicedate || '';
    document.getElementById('payment-debt').textContent = (invoiceData.debt || invoiceData.totalcost || '0') + ' ' + (invoiceData.currency || '');
    document.getElementById('payment-amount').value = invoiceData.debt || invoiceData.totalcost || '';
    document.getElementById('payment-date').value = new Date().toISOString().split('T')[0];

    // Store invoice data for submission
    modalDialog.dataset.invoiceid = invoiceData.invoiceid;
    modalDialog.dataset.customerid = invoiceData.customerid;

    // Set up form submission
    const form = document.getElementById('paymentform');
    form.addEventListener('submit', handlePaymentSubmit);

    // Show the modal
    const modal = new bootstrap.Modal(document.getElementById('universalmodal'));
    modal.show();
  })
  .catch(error => {
    console.error('Error loading payment modal:', error);
    alert('<%== __("Failed to load payment form") %>');
  });
};

async function handlePaymentSubmit(event) {
  event.preventDefault();

  const modalDialog = document.querySelector('#universalmodal #modalDialog');
  const invoiceid = modalDialog.dataset.invoiceid;
  const amount = document.getElementById('payment-amount').value;
  const paydate = document.getElementById('payment-date').value;

  if (!paydate) {
    alert('<%== __("Please enter a payment date") %>');
    return;
  }

  try {
    const url = `<%== url_for('Invoice.update', invoiceid => '_IID_') %>`.replace('_IID_', invoiceid);
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({ paydate: paydate, amount: parseFloat(amount) || 0 })
    });

    if (!response.ok) {
      if (response.status === 401) {
        // Defer to the global fetch interceptor (apidom.js): it opens the login
        // form in #universalmodal. Navigating away here would clobber the modal.
        return;
      }
      throw new Error('<%== __("Failed to register payment") %>');
    }

    // Close modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('universalmodal'));
    if (modal) modal.hide();

    // Show success toast if available
    const toastEl = document.getElementById('invoice-toast');
    if (toastEl) {
      toastEl.querySelector('.toast-body').textContent = '<%== __("Payment registered successfully") %>';
      const toast = new bootstrap.Toast(toastEl);
      toast.show();
    }

    // Reload the data - call page-specific refresh function if available
    if (typeof window.refreshInvoiceData === 'function') {
      window.refreshInvoiceData();
    } else {
      window.location.reload();
    }

  } catch (error) {
    console.error('Error registering payment:', error);
    alert(error.message || '<%== __("Failed to register payment") %>');
  }
}
