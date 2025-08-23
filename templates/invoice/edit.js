const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

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
    if (response.error) {
      alert(error);
    } else {
      populateForm(await response.json(), method);
    }
  } catch (e) {
    // Silent error handling
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
  let customer = formdata.customer;
  document.querySelector('#dataform').action = '<%== sprintf("%scustomers/", config->{managerurl}) %>' + customer.customerid + '/invoices/open';
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
  let articles = formdata.articles;
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

      for (let i = 0; i < articles.length; i++) {
        snippet += `
                <option value="${articles[i].ArticleNumber}"`;
        if (articles[i].ArticleNumber == invoiceitem.articlenumber) {
          snippet += ` selected="true"`;
        }
        snippet += `>${articles[i].Description}</option>`;
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