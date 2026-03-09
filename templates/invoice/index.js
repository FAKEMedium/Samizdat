const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

async function sendData(method) {
  const url = form.action || "";
  const target = form.target || "";
  const formData = new FormData(form);
  const request = {
    method: method,
    headers: {Accept: 'application/json'}
  };
  if (method != 'GET') {
    request.body = formData;
  }
  if (method == 'POST') {
    request.headers.Accept = 'application/json, application/pdf';
  }
  try {
    const response = await fetch(window.location, request);
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        // Show login modal with error message
        if (window.handle401Error) {
          window.handle401Error(data.error || `<%== __("Authentication required") %>`);
        } else {
          // Fallback to redirect if modal handler not available
          window.location.href = `<%== url_for('account_login') %>`;
        }
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      populateForm(await response.json(), method);
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
  }
}

function updateInvoice() {
  sendData('PUT');
}

function getInvoices(){
  sendData('GET');
}

function populateForm(formdata, method) {
  let invoices = formdata.invoices;
  let customer = formdata.customer;
  const isAdmin = formdata.admin ? true : false;

  // Toggle admin-only columns
  document.querySelectorAll('.admin-only').forEach(el => {
    el.classList.toggle('d-none', !isAdmin);
  });

  // Invoices
  let snippet = '';
  let due = 0;
  let notdue = 0;
  let unpaid = 0;
  let paid = 0;
  invoices = invoices.sortBy('-invoicedate', '-invoiceid');
  for (const invoice of invoices) {
    let rowclass = ['text-end'];
    if (invoice.due) {
      due++;
      unpaid++;
      rowclass.push('text-white');
      rowclass.push('bg-danger');
    } else if ('fakturerad' === invoice.state) {
      notdue++;
      unpaid++;
      rowclass.push('text-dark');
      rowclass.push('bg-warning');
    } else if ('bokford' === invoice.state) {
      paid++;
      rowclass.push('text-white');
      rowclass.push('bg-success');
    }
    // Create payment date cell based on state (admin only)
    let paymentCell = '';
    if (isAdmin) {
      if (invoice.state === 'fakturerad') {
        // Show payment button for unpaid invoices
        paymentCell = `<button type="button" class="btn btn-sm btn-outline-primary payment-btn"
          data-invoiceid="${invoice.invoiceid}"
          data-customerid="${invoice.customerid}"
          data-customername="${invoice.customername || ''}"
          data-fakturanummer="${invoice.fakturanummer}"
          data-invoicedate="${invoice.invoicedate ? invoice.invoicedate.substring(0, 10) : ''}"
          data-debt="${invoice.debt || invoice.totalcost}"
          data-totalcost="${invoice.totalcost}"
          data-currency="${invoice.currency || ''}">
          <%== icon 'clipboard-plus' %>
        </button>`;
      } else if (invoice.state === 'bokford') {
        // Show payment date for paid invoices
        paymentCell = invoice.paydate ? invoice.paydate.substring(0, 10) : '';
      }
    }

    // Format last reminder date with badge for count (admin only)
    let reminderCell = '';
    if (isAdmin) {
      if (invoice.lastreminderdate) {
        reminderCell = invoice.lastreminderdate.substring(0, 10);
        if (invoice.remindercount > 0) {
          reminderCell += ` <span class="badge bg-secondary">${invoice.remindercount}</span>`;
        }
      } else if (invoice.remindercount > 0) {
        reminderCell = `<span class="badge bg-secondary">${invoice.remindercount}</span>`;
      }
    }

    snippet += `
                <tr data-invoiceid="${invoice.invoiceid}">
                  <td><a href="<%== invoice->url() %>${invoice.uuid}.pdf"><%== icon 'file-pdf' %></a></td>
                  <td><a class="w-auto" href="<%== url_for('invoice_index') %>/${invoice.invoiceid}">${invoice.fakturanummer}</a></td>
                  <td>${invoice.customername || ''}</td>
                  <td>${invoice.invoicedate.substring(0, 10)}</td>
                  <td class="admin-only${isAdmin ? '' : ' d-none'}">${reminderCell}</td>
                  <td class="admin-only${isAdmin ? '' : ' d-none'}">${paymentCell}</td>
                  <td class="text-end">${invoice.totalcost}</td>
                  <td class="text-end">${invoice.totalcost}</td>
                </tr>`;
  }
  document.querySelector('#invoices tbody').innerHTML = snippet;

  if ('PUT' == method) {
    document.querySelector('#toast-messages').innerHTML = `
<%== web->indent($toast, 1) %>`;

    window.setTimeout(dropToast, 2000);
  }
}

function dropToast(){
  document.querySelector('#toast-messages').innerHTML = '';
}

// Refresh function called after payment modal submission
window.refreshInvoiceData = function() {
  getInvoices();
};

// Event delegation for payment buttons
document.querySelector('#invoices tbody').addEventListener('click', (e) => {
  const btn = e.target.closest('.payment-btn');
  if (btn && typeof window.openPaymentModal === 'function') {
    window.openPaymentModal({
      invoiceid: btn.dataset.invoiceid,
      customerid: btn.dataset.customerid,
      customerName: btn.dataset.customername,
      fakturanummer: btn.dataset.fakturanummer,
      invoicedate: btn.dataset.invoicedate,
      debt: btn.dataset.debt,
      totalcost: btn.dataset.totalcost,
      currency: btn.dataset.currency
    });
  }
});

getInvoices();