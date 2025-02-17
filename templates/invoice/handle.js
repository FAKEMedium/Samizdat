const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

async function sendData(method, customerid = 0, invoiceid = 0) {
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
  if (method == 'PUT') {
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
    console.error(e);
  }
}


// https://deano.me/javascript-change-address-bar-url-when-loading-content-with-ajax/
window.onpopstate = function(event) {
//  alert("location: " + document.location + ", state: " + JSON.stringify(event.state));
  if (event.state != undefined) {
//    loadPage(document.location.toString(),1);
  }
};
var stateObj = { foo: 1000 + Math.random()*1001 };

async function getId(what, customerid = 0, invoiceid = 0, percustomer = 0) {
  let url = '<%== config->{managerurl} %>';
  if (percustomer) {
    customerid = parseInt(customerid);
    if (customerid) {
      url += 'customers/'
      url += customerid;
      url += '/'
    }
  }
  url += 'invoices/';
  invoiceid = parseInt(invoiceid);
  if (invoiceid > 1000) {
    url += invoiceid;
    url += '/';
  }
  url += what;
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(url, request);
    if (response.error) {
      alert(error);
    } else {
      populateForm(await response.json(), 'GET');
      return true;
    }
  } catch (e) {
    console.error(e);
  }
}


function populateForm(formdata, method) {
  let customer = formdata.customer;
  let invoice = formdata.invoice;
  let payments = formdata.payments;
  let invoiceitems = formdata.invoiceitems;
  let percustomer = formdata.percustomer; // Are we under invoices/ or custumor/customerid/invoices/

  document.querySelector('#previd').setAttribute('onclick', `return getId('prev', ${invoice.customerid}, ${invoice.invoiceid}, ${percustomer});`);
  document.querySelector('#nextid').setAttribute('onclick', `return getId('next', ${invoice.customerid}, ${invoice.invoiceid}, ${percustomer});`);

  if (percustomer) {
    thisurl = `<%== sprintf("%s%s/", config->{managerurl}, "customers") %>${invoice.customerid}/invoices/${invoice.invoiceid}`;
  } else {
    thisurl = `<%== sprintf("%s%s/", config->{managerurl}, "invoices") %>${invoice.invoiceid}`;
  }
  history.pushState(stateObj, "ajax page loaded...", thisurl);
  document.querySelector('#dataform').action = thisurl;

  document.querySelector('#customer').innerHTML = customer.customerid + ', ' + customer.name;
  document.querySelector('#customer').href = `<%== sprintf("%s%s/", config->{managerurl}, "customers") %>` + customer.customerid;
  document.querySelector('#headline').innerHTML = `<%==__('Invoice') %> ${invoice.fakturanummer}`;
  document.querySelector('#invoiceid').value = invoice.invoiceid;
  if (invoice.debt == 0) {
    document.querySelector('#dataform').classList.add('d-none');
  } else {
    document.querySelector('#duedate').innerHTML = invoice.duedate;
    document.querySelector('#duebox').classList.remove('d-none');
  }
  document.querySelector('#amount').value = invoice.debt;
  document.querySelector('#invoicedate').innerHTML = invoice.invoicedate;
  document.querySelector('#costsum').innerHTML = invoice.costsum;
  document.querySelector('#vat').innerHTML = sprintf('%.2f', invoice.costsum * (1 - 1/(1 + invoice.vat)));

  var pdfoffcanvas = document.getElementById('pdfoffcanvas');
  var pdfiframe = document.getElementById('pdfinvoice');
  let pdfsrc = '<%== sprintf("%s/invoice/", config->{siteurl}) %>' + invoice.uuid + '.pdf';
  if (pdfoffcanvas.classList.contains('show')) {
    pdfiframe.setAttribute('src', pdfsrc);
  }
  pdfoffcanvas.addEventListener('shown.bs.offcanvas', function () {
    if (!pdfiframe.getAttribute('src')) {
      pdfiframe.setAttribute('src', pdfsrc);
    }
  });

  let paymentssnippet = '';
  payments = payments.sortBy('-paydate');
  for (const payment of payments) {
    paymentssnippet += `
      <div><b><%== __('Payment') %></b>: ${payment.paydate} ${payment.amount} <span class="currency"></span></div>`;
  }
  document.querySelector('#payments').innerHTML = paymentssnippet;

  let i = 1;
  let itemssnippet = '';
  for (let invoiceitemid in invoiceitems) {
    if (invoiceitems.hasOwnProperty(invoiceitemid)) {
      let invoiceitem = invoiceitems[invoiceitemid];
      let net = sprintf('%.2f', invoiceitem.number * invoiceitem.price);
      let vat = sprintf('%.2f', invoiceitem.vat * invoiceitem.number * invoiceitem.price);
      let gross = sprintf('%.2f', (1+invoiceitem.vat) * invoiceitem.number * invoiceitem.price);
      itemssnippet += `
        <tr class="invoiceitem" data-invoiceitemid="${invoiceitemid}">
          <td>${invoiceitem.articlenumber}</td>
          <td>${invoiceitem.invoiceitemtext}</td>
          <td class="text-end px-2">${invoiceitem.number}</td>
          <td class="text-end px-2">${invoiceitem.price}</td>
          <td class="text-end px-2">${net}</td>
          <td class="text-end px-2">${vat}</td>
          <td class="text-end px-2">${gross} <span class="currency"></span></td>
        </tr>`;
    }
    i++;
  }
  document.querySelector('#invoiceitems').innerHTML = itemssnippet;
  document.querySelectorAll('.currency').forEach((el) => {
    el.innerHTML = invoice.currency;
  });

  return true;
}

function makeCreditInvoice() {
  form.action = '<%== sprintf("%s%s/", config->{managerurl}, "customers") %>' + customerid + '/' + invoiceid + '/creditinvoice';

  sendData('POST');
}

function remindInvoice() {

}

function reprintInvoice() {

}

function resendInvoice() {

}

function markpaidInvoice() {

}

function getInvoice(customerid = 0, invoiceid = 0){
  sendData('GET', customerid, invoiceid);
}

getInvoice();
