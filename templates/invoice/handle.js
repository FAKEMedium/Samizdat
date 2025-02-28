document.querySelectorAll('form').forEach((el) => {
  el.addEventListener("submit", (event) => {
    event.preventDefault();
  })
});

async function sendForm(method, dataform='#dataform') {
  const form = document.querySelector(dataform);
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
      let formdata = await response.json();
      populateForm(formdata, method, dataform);
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

async function getId(what, customerid = 0, invoiceid = 0, percustomer = 0, dataform = '#dataform') {
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
      populateForm(await response.json(), 'GET', dataform);
      return true;
    }
  } catch (e) {
    console.error(e);
  }
}


function populateForm(formdata, method, dataform) {
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
  document.querySelector(dataform).action = thisurl;

  document.querySelector('#customer').innerHTML = customer.customerid + ', ' + customer.name;
  document.querySelector('#customer').href = `<%== sprintf("%s%s/", config->{managerurl}, "customers") %>` + customer.customerid;
  document.querySelector('#headline').innerHTML = `<%==__('Invoice') %> ${invoice.fakturanummer}`;
  document.querySelector('#invoiceid').value = invoice.invoiceid;
  document.querySelector('#customerid').value = invoice.customerid;
  document.querySelector('#duedate').innerHTML = `${invoice.duedate}`;
  document.querySelector('#duebox').classList.add('d-none');

  if (parseInt(invoice.due) > 0) {
    document.querySelector('#duebox').classList.remove('d-none');
  } else {
    document.querySelector(dataform).classList.add('d-none');
  }
  document.querySelector('#creditedbox').classList.add('d-none');
  document.querySelector('#creditedinvoice').innerHTML = '';

  if (invoice.state === 'raderad') {
    document.querySelector('#duebox').classList.add('d-none');
    if (parseInt(invoice.kreditfakturaavser) === 0) {
      document.querySelector('#duedate').innerHTML = `<%== __('Invoice credited m') %>`;
      document.querySelector('#headline').innerHTML = `<%==__('Invoice (credited)') %> ${invoice.fakturanummer}`;
    } else {
      document.querySelector('#creditedbox').classList.remove('d-none');
      document.querySelector('#creditedinvoice').innerHTML = `${invoice.kreditfakturaavser}`;
      document.querySelector('#headline').innerHTML = `<%==__('Credit invoice') %> ${invoice.fakturanummer}`;
    }
  }
  document.querySelector('#amount').value = invoice.debt;
  document.querySelector('#invoicedate').innerHTML = invoice.invoicedate;
  document.querySelector('#costsum').innerHTML = invoice.costsum;
  document.querySelector('#vat').innerHTML = sprintf('%.2f', invoice.costsum * (1 - 1/(1 + invoice.vat)));
  if (invoice.state !== 'fakturerad') {
    document.querySelector(dataform).classList.add('d-none');
    document.querySelector('#remindbutton').href = '#';
  } else {
    document.querySelector(dataform).classList.remove('d-none');
    document.querySelector('#duebox').classList.remove('d-none');
    document.querySelector('#remindbutton').href = `<%== sprintf("%s%s/", config->{managerurl}, "customers") %>${invoice.customerid}/invoices/${invoice.invoiceid}/remind`;
  }
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

  let infoboxsnippet = '';
  payments = payments.sortBy('-paydate');
  for (const payment of payments) {
    infoboxsnippet += `
      <div><b class="d-sm-inline d-none"><%== __('Payment') %>: </b>${payment.paydate} ${payment.amount} <span class="currency"></span></div>`;
  }
  document.querySelector('#infobox').innerHTML = infoboxsnippet;

  let i = 1;
  let itemssnippet = '';
  for (let invoiceitemid in invoiceitems) {
    if (invoiceitems.hasOwnProperty(invoiceitemid)) {
      let invoiceitem = invoiceitems[invoiceitemid];
      let net = sprintf('%.2f', invoiceitem.number * invoiceitem.price);
      let vat = sprintf('%.2f', invoice.vat * invoiceitem.number * invoiceitem.price);
      let gross = sprintf('%.2f', (1+invoice.vat) * invoiceitem.number * invoiceitem.price);
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

function makeCreditInvoice(dataform) {
  if (confirm('<%== __("Do you want to credit the invoice?") %>')) {
    let customerid = document.querySelector('#customerid').value;
    let invoiceid = document.querySelector('#invoiceid').value;
    document.querySelector(dataform).action = '<%== sprintf("%s%s/", config->{managerurl}, "customers") %>' + customerid + '/invoices/' + invoiceid + '/creditinvoice';
    sendForm('POST', dataform);
  }
}

function remindInvoice() {
  let customerid = document.querySelector('#customerid').value;
  let invoiceid = document.querySelector('#invoiceid').value;
  document.querySelector('#remindbutton').href = `<%== sprintf("%s%s/", config->{managerurl}, "customers") %>${customerid}/invoices/${invoiceid}/remind`;
}

function reprintInvoice() {

}

function resendInvoice() {

}

function markPaymentInvoice() {

}

function getInvoice(dataform) {
  sendForm('GET', dataform);
}

getInvoice('#dataform');
