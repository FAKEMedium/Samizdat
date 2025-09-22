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
          window.handle401Error(data.error || '<%== __("Authentication required") %>');
        } else {
          // Fallback to redirect if modal handler not available
          window.location.href = '<%== url_for('account_login') %>';
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
    snippet += `
                <tr data-invoiceid="${invoice.invoiceid}">
                  <td><a href="<%== config->{sitesurl} %>invoice/${invoice.uuid}.pdf"><%== icon 'file-pdf' %></a></td>
                  <td><a class="w-auto" href="<%== sprintf("%s%s", config->{manager}->{url}, 'invoices/') %>${invoice.invoiceid}">${invoice.fakturanummer}</a></td>
                  <td>${invoice.paydate.substring(10, 0)}</td>
                  <td>${invoice.invoicedate.substring(10, 0)}</td>
                  <td class="text-end">${invoice.costsum}</td>
                  <td class="text-end">${invoice.costsum}</td>
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