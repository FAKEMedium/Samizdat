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

async function updatePaymentDate(invoiceId, paymentDate) {
  try {
    const response = await fetch(`/invoices/${invoiceId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({ paydate: paymentDate })
    });

    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        if (window.handle401Error) {
          window.handle401Error(data.error || `<%== __("Authentication required") %>`);
        } else {
          window.location.href = `<%== url_for('account_login') %>`;
        }
      } else {
        alert(`<%== __('Failed to update payment date') %>`);
      }
    }
  } catch (e) {
    console.error('Error updating payment date:', e);
    alert(`<%== __('Failed to update payment date') %>`);
  }
}


function populateForm(formdata, method) {
  let invoices = formdata.invoices;
  let customer = formdata.customer;

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
    // Create payment date cell based on state
    let paymentCell = '';
    if (invoice.state === 'fakturerad') {
      // Show date input field for unpaid invoices
      paymentCell = `<input type="date" class="form-control form-control-sm" name="paydate_${invoice.invoiceid}" value="${invoice.paydate ? invoice.paydate.substring(0, 10) : ''}" onchange="updatePaymentDate(${invoice.invoiceid}, this.value)">`;
    } else if (invoice.state === 'bokford') {
      // Show payment date for paid invoices
      paymentCell = invoice.paydate ? invoice.paydate.substring(0, 10) : '';
    } else {
      // Empty for other states
      paymentCell = '';
    }

    // Format last reminder date with badge for count
    let reminderCell = '';
    if (invoice.lastreminderdate) {
      reminderCell = invoice.lastreminderdate.substring(0, 10);
      if (invoice.remindercount > 0) {
        reminderCell += ` <span class="badge bg-secondary">${invoice.remindercount}</span>`;
      }
    } else if (invoice.remindercount > 0) {
      reminderCell = `<span class="badge bg-secondary">${invoice.remindercount}</span>`;
    }

    snippet += `
                <tr data-invoiceid="${invoice.invoiceid}">
                  <td><a href="<%== invoice->url(config->{sitesurl}, config->{baseurl}) %>${invoice.uuid}.pdf"><%== icon 'file-pdf' %></a></td>
                  <td><a class="w-auto" href="<%== url_for('invoice_index') %>/${invoice.invoiceid}">${invoice.fakturanummer}</a></td>
                  <td>${invoice.customername || ''}</td>
                  <td>${invoice.invoicedate.substring(0, 10)}</td>
                  <td>${reminderCell}</td>
                  <td>${paymentCell}</td>
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

getInvoices();