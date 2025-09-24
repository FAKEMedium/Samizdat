const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

// Bind button click events
document.getElementById('updateInvoiceBtn')?.addEventListener('click', () => updateInvoice());
document.getElementById('makeInvoiceBtn')?.addEventListener('click', () => makeInvoice());

async function sendData(method) {
  const url = form.action || "";
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
    const response = await fetch(url, request);
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        alert(data.error || 'Authentication required');
        window.location.href = '<%== url_for('account_login') %>';
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

function makeInvoice(){
  form.submit();
//  sendData('POST');
}

function getInvoice(){
  sendData('GET');
}

function populateForm(formdata, method) {
  // Check for Fortnox errors and display warning
  if (formdata.fortnox_error) {
    const alertDiv = document.createElement('div');
    alertDiv.className = 'alert alert-warning alert-dismissible fade show';
    alertDiv.role = 'alert';
    alertDiv.innerHTML = `
      <strong><%== __('Fortnox Warning') %>:</strong> ${formdata.fortnox_error}
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `;

    // Insert at the top of the content area
    const contentArea = document.querySelector('#thecontent');
    if (contentArea) {
      contentArea.insertBefore(alertDiv, contentArea.firstChild);
    }
  }

  let customer = formdata.customer;
  document.querySelector('#dataform').action = '<%== sprintf("%scustomers/", config->{manager}->{url}) %>' + customer.customerid + '/invoices/open';
  document.querySelector('#customerid').value = customer.customerid;
  document.querySelector('#billingemail').value = customer.billingemail;
  document.querySelector('#billingzip').value = customer.billingzip;
  document.querySelector('#billingcity').value = customer.billingcity;
  document.querySelector('#billingaddress').value = customer.billingaddress;
  document.querySelector('#billingcountry').value = customer.billingcountry;
  document.querySelector('#mailto').href = 'mailto:' + customer.billingemail;
  document.querySelector('#billinglang').value = customer.billinglang;
  document.querySelector('#headline').innerHTML = `<%==__('Open invoice for customer') %> #${customer.customerid}`;

  let invoice = formdata.invoice;
  document.querySelector('#invoiceid').value = invoice.invoiceid;

  let invoiceitems = formdata.invoiceitems;
  let articles = formdata.articles || [];  // Ensure articles is at least an empty array
  let i = 1;
  let snippet = '';
  for (let invoiceitemid in invoiceitems) {
    if (invoiceitems.hasOwnProperty(invoiceitemid)) {
      let invoiceitem = invoiceitems[invoiceitemid];
      let checked = (invoiceitem.include > 0) ? 'checked="true" ' : '';
      snippet += `
        <tr class="invoiceitem" data-invoiceitemid="${invoiceitemid}">
          <td class="text-end">${i}<input type="hidden" name="productid_${invoiceitemid}" id="productid_${invoiceitemid}" value="${invoiceitem.productid}"></td>
          <td><input type="checkbox" class="form-check-input" name="include_${invoiceitemid}" id="include_${invoiceitemid}" value="1" ${checked}/></td>
          <td>
            <select class="form-select" name="articlenumber_${invoiceitemid}" id="articlenumber_${invoiceitemid}">
                <option value="0"><%== __('Select') %></option>`;

      // Check if articles is an array and has items
      if (Array.isArray(articles) && articles.length > 0) {
        for (let i = 0; i < articles.length; i++) {
          snippet += `
                  <option value="${articles[i].ArticleNumber}"`;
          if (articles[i].ArticleNumber == invoiceitem.articlenumber) {
            snippet += ` selected="true"`;
          }
          snippet += `>${articles[i].Description}</option>`;
        }
      }
      snippet += `
            </select>
          </td>
          <td><input type="text" class="form-control" name="invoiceitemtext_${invoiceitemid}" id="invoiceitemtext_${invoiceitemid}" value="${invoiceitem.invoiceitemtext}" size="60"></td>
          <td><input type="text" class="form-control text-end" name="number_${invoiceitemid}" id="number_${invoiceitemid}" value="${invoiceitem.number}" size="5"></td>
          <td><input type="text" class="form-control text-end" name="price_${invoiceitemid}" id="price_${invoiceitemid}" value="${invoiceitem.price}" size="5"></td>
          <td class="text-end px-2" id="cost_${invoiceitemid}">${invoiceitem.number * invoiceitem.price}</td>
          <td class="text-end px-2" id="sum_${invoiceitemid}">${(1+invoiceitem.vat) * invoiceitem.number * invoiceitem.price}</td>
        </tr>`;
    }
    i++;
  }
  document.querySelector('#invoiceitems').innerHTML = snippet;

  if ('PUT' == method) {
    document.querySelector('#toast-messages').innerHTML = `
<%== web->indent($toast, 1) %>`;

    window.setTimeout(dropToast, 2000);
  }
}

function dropToast(){
  document.querySelector('#toast-messages').innerHTML = '';
}

getInvoice();