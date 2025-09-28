let billingemail = '';
let fakturanummer = '';
let debt = '';
let invoicedate = '';

// Create sprintf function that uses window.sprintf if available, or fallback
function sprintf(format, ...args) {
  if (window.sprintf && typeof window.sprintf === 'function') {
    return window.sprintf(format, ...args);
  }
  // Simple fallback for %.2f format
  if (format === '%.2f' && args.length === 1) {
    return parseFloat(args[0]).toFixed(2);
  }
  return args[0]?.toString() || '';
}

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
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        alert(data.error || 'Authentication required');
        window.location.href = '<%== url_for('account_login') %>';
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      let formdata = await response.json();
      populateForm(formdata, method, dataform);
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
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

window.getId = async function getId(what, customerid = 0, invoiceid = 0, percustomer = 0, dataform = '#dataform') {
  let url = '<%== config->{manager}->{url} %>';
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
    if (!response.ok) {
      if (response.status === 401) {
        const data = await response.json();
        alert(data.error || 'Authentication required');
        window.location.href = '<%== url_for('account_login') %>';
      } else {
        alert('Request failed: ' + response.statusText);
      }
      return false;
    } else {
      populateForm(await response.json(), 'GET', dataform);
      return true;
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
    return false;
  }
}


function populateForm(formdata, method, dataform) {
  let customer = formdata.customer;
  let invoice = formdata.invoice;
  let invoiceitems = formdata.invoiceitems;
  let payments = formdata.payments;
  let reminders = formdata.reminders;

  // Determine percustomer from current URL - check if we're under the customer route
  let customerBaseUrl = `<%== url_for('customer_index') %>`;
  let percustomer = window.location.pathname.startsWith(customerBaseUrl) ? 1 : 0;

  document.querySelector('#previd').setAttribute('onclick', `return getId('prev', ${invoice.customerid}, ${invoice.invoiceid}, ${percustomer});`);
  document.querySelector('#nextid').setAttribute('onclick', `return getId('next', ${invoice.customerid}, ${invoice.invoiceid}, ${percustomer});`);

  if (percustomer) {
    thisurl = `<%== url_for('customer_index') %>/${invoice.customerid}/invoices/${invoice.invoiceid}`;
  } else {
    thisurl = `<%== url_for('invoice_index') %>/${invoice.invoiceid}`;
  }
  history.pushState(stateObj, "ajax page loaded...", thisurl);
  document.querySelector(dataform).action = thisurl;
  if (customer.billingemail !== '') {
    billingemail = customer.billingemail;
  } else {
    billingemail = customer.email;
  }
  fakturanummer = invoice.fakturanummer;
  invoicedate = invoice.invoicedate;
  debt = invoice.debt;

  // Set global variables for modals
  window.customerid = invoice.customerid;
  window.invoiceid = invoice.invoiceid;
  window.fakturanummer = invoice.fakturanummer;
  window.billingemail = billingemail;

  document.querySelector('#customer').innerHTML = customer.customerid + ', ' + customer.name;
  document.querySelector('#customer').href = `<%== url_for('customer_index') %>/` + customer.customerid;
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
      document.querySelector('#duedate').innerHTML = `<%== __('Invoice is credited') %>`;
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
  document.querySelector('#vat').innerHTML = sprintf('%.2f', invoice.costsum * (1 - 1 / (1 + invoice.vat)));
  if (invoice.state !== 'fakturerad') {
    document.querySelector(dataform).classList.add('d-none');
    document.querySelector('#remindbutton').href = '#';
//    document.querySelector('#paymentbutton').href = '#';
  } else {
    document.querySelector(dataform).classList.remove('d-none');
    document.querySelector('#duebox').classList.remove('d-none');
//    document.querySelector('#paymentbutton').href = `<%== url_for('customer_index') %>/${invoice.customerid}/invoices/${invoice.invoiceid}/payment`;
    document.querySelector('#remindbutton').href = `<%== url_for('customer_index') %>/${invoice.customerid}/invoices/${invoice.invoiceid}/remind`;
  }
  var pdfoffcanvas = document.getElementById('pdfoffcanvas');
  var pdfiframe = document.getElementById('pdfinvoice');
  let pdfsrc = '<%== config->{manager}->{invoice}->{invoiceurl} %>' + invoice.uuid + '.pdf';
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
      <li><b class="d-sm-inline d-none"><%== __('Payment') %>: </b>${payment.paydate} ${payment.amount} <span class="currency"></span></li>`;
  }
  document.querySelector('#payments').innerHTML = paymentssnippet;

  const tooltip = new bootstrap.Tooltip(document.querySelector('#remindbutton'), {
    html: true
  });
  if (reminders.length) {
    let remindersnippet = '';
    reminders = reminders.sortBy('-reminderdate');
    for (const reminder of reminders) {
      remindersnippet += `
        <li class="dropdown-item">${reminder.reminderdate}</li>`;
    }
    document.querySelector('#remindercount').innerHTML = reminders.length;
    document.querySelector('#remindercount').d
    tooltip.setContent({ '.tooltip-inner':remindersnippet});
  } else {
    document.querySelector('#remindercount').innerHTML = '';
//    document.querySelector('#reminders').innerHTML = '';
  }

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
    document.querySelector(dataform).action = `<%== url_for('customer_index') %>/` + customerid + '/invoices/' + invoiceid + '/creditinvoice';
    sendForm('POST', dataform);
  }
}

function remindInvoice() {
  let customerid = document.querySelector('#customerid').value;
  let invoiceid = document.querySelector('#invoiceid').value;
  document.querySelector('#remindbutton').href = `<%== url_for('customer_index') %>/${customerid}/invoices/${invoiceid}/remind`;
}

// Make functions globally accessible for onclick handlers
window.makeCreditInvoice = makeCreditInvoice;
window.remindInvoice = remindInvoice;

// Make invoice data globally accessible for modals
window.customerid = '';
window.reprintInvoice = async function() {
  const customerid = document.querySelector('#customerid')?.value;
  const invoiceid = document.querySelector('#invoiceid')?.value;

  if (!customerid || !invoiceid) {
    alert('<%== __("Missing customer or invoice ID") %>');
    return;
  }

  try {
    const url = `<%== url_for('customer_index') %>/${customerid}/invoices/${invoiceid}/reprint`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    });

    if (response.ok) {
      const data = await response.json();
      // Show success using the existing toast if available
      const toastEl = document.getElementById('invoice-toast');
      if (toastEl) {
        toastEl.querySelector('.toast-body').textContent = '<%== __("Invoice reprinted successfully") %>';
        const toast = new bootstrap.Toast(toastEl);
        toast.show();
      }

      // Reload the page to show the new PDF
      setTimeout(() => {
        window.location.reload();
      }, 1500);
    } else {
      const error = await response.text();
      alert(`<%== __("Failed to reprint invoice") %>: ${error}`);
    }
  } catch (error) {
    console.error('Error reprinting invoice:', error);
    alert(`<%== __("Error reprinting invoice") %>: ${error.message || error}`);
  }
}

// Make functions globally accessible for onclick handlers
window.resendInvoice = async function() {
  const customerid = document.querySelector('#customerid')?.value;
  const invoiceid = document.querySelector('#invoiceid')?.value;

  if (!customerid || !invoiceid) {
    alert('<%== __("Missing customer or invoice ID") %>');
    return;
  }

  // Confirm before resending
  if (!confirm('<%== __("Are you sure you want to resend this invoice?") %>')) {
    return;
  }

  try {
    const url = `<%== url_for('customer_index') %>/${customerid}/invoices/${invoiceid}/resend`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    });

    if (response.ok) {
      const data = await response.json();
      // Show success using the existing toast if available
      const toastEl = document.getElementById('invoice-toast');
      if (toastEl) {
        toastEl.querySelector('.toast-body').textContent = '<%== __("Invoice resent successfully") %>';
        const toast = new bootstrap.Toast(toastEl);
        toast.show();
      } else {
        alert('<%== __("Invoice resent successfully") %>');
      }
    } else {
      const error = await response.text();
      alert(`<%== __("Failed to resend invoice") %>: ${error}`);
    }
  } catch (error) {
    console.error('Error resending invoice:', error);
    alert(`<%== __("Error resending invoice") %>: ${error.message || error}`);
  }
}

window.markPayment = function() {
  // TODO: Implement mark payment functionality
  alert('Mark payment functionality not yet implemented');
}

function getInvoice(dataform) {
  sendForm('GET', dataform);
}

getInvoice('#dataform');
