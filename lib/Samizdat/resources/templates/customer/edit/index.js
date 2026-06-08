% use Mojo::Util qw(trim);
// Universal modal access
const universalModal = new bootstrap.Modal('#universalmodal');
const modalDialog = document.getElementById('modalDialog');

// Open SMS modal with pre-filled phone number
function openSMSModal(phoneNumber) {
  const modalContent = `
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title"><%== __('Send SMS') %></h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <%== web->indent(eval { trim include 'sms/chunks/sendform', format => 'html'}, 4) %>
      </div>
    </div>`;
  
  modalDialog.innerHTML = modalContent;
  
  // Pre-fill phone number after modal content is inserted
  setTimeout(() => {
    const phoneInput = document.querySelector('#universalmodal #to');
    const messageInput = document.querySelector('#universalmodal #message');
    const charCountSpan = document.querySelector('#universalmodal #charCount');
    
    if (phoneInput) {
      phoneInput.value = phoneNumber;
    }
    if (messageInput) {
      messageInput.focus();
    }
    
    // Initialize SMS form functionality for the modal
    initializeSMSFormInModal();
  }, 100);
  
  universalModal.show();
}

// Open VAT lookup modal
function openVATModal(vatno) {
  modalDialog.innerHTML = `<%== web->indent(eval { trim include 'customer/vatno/index', format => 'html'}, 2) %>`;

  // Pre-fill VAT number if provided
  if (vatno) {
    const inputField = document.querySelector('#vatlookup-input');
    if (inputField) {
      inputField.value = vatno;
    }
    window.vatnoForLookup = vatno;
  }

  // Initialize VAT modal functionality
  <%== web->indent(eval { trim include 'customer/vatno/index', format => 'js'}, 1) %>

  universalModal.show();
}

// Initialize SMS form in modal
function initializeSMSFormInModal() {
  const modalForm = document.querySelector('#universalmodal #smsForm');
  const messageTextarea = document.querySelector('#universalmodal #message');
  const charCountSpan = document.querySelector('#universalmodal #charCount');
  const sendButton = document.querySelector('#universalmodal #sendButton');
  const toInput = document.querySelector('#universalmodal #to');
  
  if (messageTextarea && charCountSpan) {
    function updateCharCount() {
      const count = messageTextarea.value.length;
      charCountSpan.textContent = count;
      
      if (count > 160) {
        charCountSpan.classList.add('text-danger');
      } else if (count > 140) {
        charCountSpan.classList.add('text-warning');
        charCountSpan.classList.remove('text-danger');
      } else {
        charCountSpan.classList.remove('text-warning', 'text-danger');
      }
    }
    
    messageTextarea.addEventListener('input', updateCharCount);
    updateCharCount();
  }
  
  if (modalForm) {
    modalForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      
      if (!modalForm.checkValidity()) {
        modalForm.classList.add('was-validated');
        return;
      }
      
      const originalText = sendButton.innerHTML;
      sendButton.disabled = true;
      sendButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span><%== __("Sending...") %>';
      
      try {
        const formData = new FormData(modalForm);
        const response = await fetch(`<%= url_for 'SMS.send' %>`, {
          method: 'POST',
          headers: {
            'Accept': 'application/json'
          },
          body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
          // Close modal and show success
          universalModal.hide();
          alert('<%== __("SMS sent successfully!") %>');
        } else {
          // Handle validation errors
          if (result.valid) {
            if (result.valid.to === 'is-invalid') {
              toInput.classList.add('is-invalid');
              toInput.classList.remove('is-valid');
            }
            if (result.valid.message === 'is-invalid') {
              messageTextarea.classList.add('is-invalid');
              messageTextarea.classList.remove('is-valid');
            }
          }
          
          let errorMsg = 'Failed to send SMS';
          if (result.errors && result.errors.general) {
            errorMsg = result.errors.general;
          }
          alert(errorMsg);
        }
      } catch (error) {
        console.error('Send SMS error:', error);
        alert('<%== __("Connection error. Please try again.") %>');
      } finally {
        sendButton.disabled = false;
        sendButton.innerHTML = originalText;
      }
    });
  }
}

const form = document.querySelector("#dataform");
form.addEventListener("submit", (event) => {
  event.preventDefault();
});

async function sendData(method, customerid = 0) {
  let url;
  if (customerid > 0) {
    url = `<%== url_for('Customer.get', customerid => '_CID_') %>`.replace('_CID_', customerid);
    form.action = url;
  } else if (method === 'PUT') {
    // Use API route for PUT - extract customerid from form
    const cid = document.querySelector('#customerid')?.value || 0;
    url = `<%== url_for('Customer.update', customerid => '_CID_') %>`.replace('_CID_', cid);
  } else {
    url = form.action || "";
  }
  const formData = new FormData(form);
  const request = {
    method: method,
    headers: {Accept: 'application/json'}
  };
  if (method != 'GET') {
    request.body = formData;
  }
  try {
    const response = await fetch(url, request);
    if (!response.ok) {
      // 401 errors are handled by global fetch interceptor in apidom.js
      if (response.status !== 401) {
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

// https://deano.me/javascript-change-address-bar-url-when-loading-content-with-ajax/
window.onpopstate = function(event) {
//  alert("location: " + document.location + ", state: " + JSON.stringify(event.state));
  if (event.state != undefined) {
//    loadPage(document.location.toString(),1);
  }
};
var stateObj = { foo: 1000 + Math.random()*1001 };

window.getId = async function getId(what, customerid = 0) {
  customerid = parseInt(customerid);
  let url;
  // Use API routes for navigation
  if (what === 'prev') {
    url = `<%== url_for('Customer.prev', customerid => '_CID_') %>`.replace('_CID_', customerid);
  } else if (what === 'next') {
    url = `<%== url_for('Customer.next', customerid => '_CID_') %>`.replace('_CID_', customerid);
  } else if (what === 'first') {
    url = `<%== url_for('Customer.first') %>`;
  } else if (what === 'newest') {
    url = `<%== url_for('Customer.newest') %>`;
  } else {
    url = `<%== url_for('Customer.get', customerid => '_CID_') %>`.replace('_CID_', customerid);
  }
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(url, request);
    if (!response.ok) {
      // 401 errors are handled by global fetch interceptor in apidom.js
      if (response.status !== 401) {
        alert('Request failed: ' + response.statusText);
      }
      return false;
    } else {
      populateForm(await response.json(), 'GET');
      return true;
    }
  } catch (e) {
    // Silent error handling
  }
}

window.updateCustomer = function(){
  sendData('PUT');
}

window.createCustomer = function() {
//  sendData('POST');
  form.submit();
}

function getCustomer(customerid = 0) {
  sendData('GET', customerid);
}

// Fetch DNS zones from Zone model
async function fetchCustomerZones(customerid) {
  try {
    const response = await fetch(`<%== url_for('Zone.customer.index', customerid => '_CID_') %>`.replace('_CID_', customerid), {
      headers: { 'Accept': 'application/json' }
    });
    if (!response.ok) return;

    const data = await response.json();
    const zones = data.zones || [];

    let snippet = '';
    zones.sort((a, b) => a.name.localeCompare(b.name));
    for (const zone of zones) {
      const displayName = zone.unicode_name && zone.unicode_name !== zone.name
        ? zone.unicode_name
        : zone.name.replace(/\.$/, '');
      snippet += `
                <tr data-zoneid="${zone.name}"><td><a class="d-block" href="<%== url_for('zone_index') %>/${zone.name}/records/">${displayName}</a></td></tr>`;
    }
    document.querySelector('#dnsdomains tbody').innerHTML = snippet;

    if (zones.length > 0) {
      document.querySelector('#nrdnsdomains').innerHTML = zones.length;
      document.querySelector('#nrdnsdomains').classList.remove("d-none");
    }
  } catch (e) {
    console.error('Failed to fetch zones:', e);
  }
}


function populateForm(formdata, method) {
  let customer = formdata.customer || {};
  let domains = formdata.domains || [];
  let invoices = formdata.invoices || [];
  let invoiceitems = formdata.invoiceitems || {};
  let databases = formdata.databases || [];
  let sites = formdata.sites || [];
  let maildomains = formdata.maildomains || [];
  let subscriptions = formdata.subscriptions || [];
  let userlogins = formdata.userlogins || [];

  // Customer data, including default values for new customer
  for (const field of [<%== join ", ", map "\"$_\"" => @{$fields} %>]) {
    if (Object.hasOwn(customer, field)) {
      document.querySelector('#' + field).value = customer[field];
    }
  }
  for (const checkfield of [<%== join ", ", map "\"$_\"" => @{$checkfields} %>]) {
    if (Object.hasOwn(customer, checkfield)) {
      document.querySelector('#' + checkfield).checked = (customer[checkfield] > 0) ? true : false;
    } else {
      document.querySelector('#' + checkfield).checked = false;
    }
  }

  // Reset generated content
  document.querySelectorAll('.reset').forEach((el) => {
    el.href = '';
    el.classList.add("d-none");
  });
  document.querySelectorAll('.blank').forEach((el) => {
    el.innerHTML = '';
    if (el.tagName == 'SPAN') {
      el.classList.add("d-none");
    }
  });

  // Use addEventListener instead of onclick for CSP compliance
  document.querySelector('#minid').onclick = (e) => { e.preventDefault(); getId('first', 1000); };
  document.querySelector('#maxid').onclick = (e) => { e.preventDefault(); getId('newest', 1000); };
  if (!customer.customerid) {
    thisurl = `<%== url_for('customer_index') %>`;
    document.querySelector('#dataform').action = `<%== url_for('customer_index') %>`;
    document.querySelector('#submitbutton').innerHTML = `<%== __('Create customer') %>`;
    document.querySelector('#submitbutton').onclick = () => createCustomer();
    document.querySelector('#previd').onclick = (e) => { e.preventDefault(); getId('first', 1000); };
    document.querySelector('#nextid').onclick = (e) => { e.preventDefault(); getId('newest', 1000); };
    return;
  }

  document.querySelector('#submitbutton').innerHTML = `<%== __('Update customer') %>`;
  document.querySelector('#submitbutton').onclick = () => updateCustomer();
  thisurl = `<%== url_for('customer_index') %>/${ customer.customerid }`
  history.pushState(stateObj, "ajax page loaded...", thisurl);
  document.querySelector('#dataform').action = thisurl;
  document.querySelector('#headline').innerHTML = `<%==__('Customer') %> #${customer.customerid}`;
  document.querySelector('#previd').onclick = (e) => { e.preventDefault(); getId('prev', customer.customerid); };
  document.querySelector('#nextid').onclick = (e) => { e.preventDefault(); getId('next', customer.customerid); };

  // VAT lookup modal - always show icon, pre-fill with existing vatno if available
  const vatlookupBtn = document.querySelector('#vatlookup');
  vatlookupBtn.onclick = (e) => {
    e.preventDefault();
    openVATModal(document.querySelector('#vatno').value || '');
  };
  vatlookupBtn.classList.remove("d-none");
  if (Object.hasOwn(customer, 'contactemail') && ('' != customer.contactemail)) {
    document.querySelector('#mailto').href = 'mailto:' + customer.contactemail;
    document.querySelector('#mailto').classList.remove("d-none");
  }
  if (Object.hasOwn(customer, 'phone1') && customer.phone1) {
    let tel1 = customer.phone1.replace(/[^+0-9]+/g, '');
    if ('' != tel1) {
      document.querySelector('#tel1').href = 'tel:' + tel1;
      document.querySelector('#tel1').classList.remove("d-none");
    }
  }
  if (Object.hasOwn(customer, 'phone2') && customer.phone2) {
    let tel2 = customer.phone2.replace(/[^+0-9]+/g, '');
    if ('' != tel2) {
      document.querySelector('#tel2').href = 'tel:' + tel2;
      document.querySelector('#tel2').classList.remove("d-none");
      
      // Setup SMS modal functionality
      const smsButton = document.querySelector('#sms');
      smsButton.onclick = (e) => {
        e.preventDefault();
        openSMSModal(tel2);
      };
      smsButton.classList.remove("d-none");
    }
  }
  let eucountries = /(<%== join '|',  @{$eucountries} %>)/i;
  if (Object.hasOwn(customer, 'orgno') && ('' != customer.orgno)) {
    if ('SE' == customer.country) {
      if (parseInt(customer.orgno.substring(2, 4)) < 20) {
        document.querySelector('#upplysning').href = `https://upplysning.se/person/?sl=detail&b=${customer.orgno}`;
        document.querySelector('#upplysning').classList.remove("d-none");
        document.querySelector('#allabolag').href = `https://www.allabolag.se/befattningshavare?q=${customer.orgno.replace(/[^0-9]/g, '')}`;
      } else {
        document.querySelector('#allabolag').href = `https://www.allabolag.se/bransch-sök?q=${customer.orgno}`;
      }
      document.querySelector('#allabolag').classList.remove("d-none");
    } else if ('NO' == customer.country) {
      document.querySelector('#brreg').href = `https://w2.brreg.no/enhet/sok/valg.jsp?inputparam=${customer.orgno}`;
      document.querySelector('#brreg').classList.remove("d-none");
    } else if (eucountries.test(customer.country)) {
      document.querySelector('#ejustice').href = `https://e-justice.europa.eu/content_find_a_company-489-en.do?companyRegNumber=${customer.orgno}&amp;searchCountries=${customer.country}`;
      document.querySelector('#ejustice').classList.remove("d-none");
    }
  }

  // Userlogins
  let userloginsHtml = '';
  for (const userlogin of userlogins) {
    userloginsHtml += `
      <li class="d-flex align-items-center mb-2">
        <span class="me-2">${userlogin.userlogin}</span>
        <a href="<%== url_for('account_login') %>?action=impersonate&impersonate=${userlogin.userlogin}" title="Impersonate ${userlogin.userlogin}">
          <%== icon 'person-fill', {extraclasses => 'mx-1'} %>
        </a>
        <a href="<%== url_for('account_index') %>/${userlogin.userlogin}" title="Edit ${userlogin.userlogin}">
          <%== icon 'pen-fill', {extraclasses => 'mx-1'} %>
        </a>
      </li>`;
  }
  document.querySelector('#userlogins').innerHTML = userloginsHtml;

  // Invoices
  let snippet = '';
  let due = 0;
  let notdue = 0;
  let paid = 0;
  invoices = invoices.sortBy('-invoicedate', '-invoiceid');
  for (const invoice of invoices) {
    let rowclass = ['text-end'];
    if (invoice.due) {
      due++;
      rowclass.push('text-white');
      rowclass.push('bg-danger');
    } else if ('fakturerad' === invoice.state) {
      notdue++;
      rowclass.push('text-dark');
      rowclass.push('bg-warning');
    } else if ('bokford' === invoice.state) {
      paid++;
      rowclass.push('text-white');
      rowclass.push('bg-success');
    }
    snippet += `
                <tr data-invoiceid="${invoice.invoiceid}">
                  <td><a href="<%== config->{manager}->{invoice}->{invoiceurl} %>${invoice.uuid}.pdf"><%== icon 'file-pdf' %></a></td>
                  <td><a class="w-auto" href="<%== url_for('customer_index') %>/${customer.customerid}/invoices/${invoice.invoiceid}">${invoice.fakturanummer}</a></td>
                  <td>${invoice.invoicedate.substring(10, 0)}</td>
                  <td class="text-end">${invoice.totalcost}</td>
                  <td class="${rowclass.join(' ')}">${invoice.state}</td>
                </tr>`;
  }
  document.querySelector('#invoices tbody').innerHTML = snippet;
  document.querySelector('#invoicelistlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/invoices`;
  document.querySelectorAll('.currencynote').forEach((currencynote) => {
    currencynote.innerHTML = `${'<%== __x("Invoice currency is {currency}.", currency => "customercurrency") %>'.replace('customercurrency', customer.currency.toUpperCase())}`;
  });
  if (due > 0) {
    document.querySelector('#due').innerHTML = due;
    document.querySelector('#due').classList.remove("d-none");
  }
  if (notdue > 0) {
    document.querySelector('#notdue').innerHTML = notdue;
    document.querySelector('#notdue').classList.remove("d-none");
  }
  if (paid > 0) {
    document.querySelector('#paid').innerHTML = paid;
    document.querySelector('#paid').classList.remove("d-none");
  }

  // Invoice items in open invoice
  snippet = '';
  let amount = 0;
  let nrinvoiceitems = 0;
  for (let invoiceitemid in invoiceitems) {
    if (invoiceitems.hasOwnProperty(invoiceitemid)) {
      let invoiceitem = invoiceitems[invoiceitemid];
      amount += invoiceitem.price * invoiceitem.number * (1 + customer.vat / 100);
      let checked = (invoiceitem.include > 0) ? 'checked="true" ' : '';
      snippet += `
                <tr class="invoiceitem" data-invoiceitemid="${invoiceitemid}">
                  <td class="w-auto">${invoiceitem.invoiceitemtext}</td>
                  <td class="text-end">${(1 + customer.vat / 100) * invoiceitem.number * invoiceitem.price}</td>
                </tr>`;
    }
    nrinvoiceitems++;
  }
  document.querySelector('#invoiceitems tbody').innerHTML = snippet;
  document.querySelector('#amount').innerHTML = amount;
  if (nrinvoiceitems > 0) {
    document.querySelector('#nrinvoiceitems').innerHTML = nrinvoiceitems;
    document.querySelector('#nrinvoiceitems').classList.remove("d-none");
  }
  document.querySelectorAll('.openinvoicelink').forEach((openinvoicelink) => {
    openinvoicelink.href = `<%== url_for('customer_index') %>/${customer.customerid}/invoices/open`;
  });

  // Domains
  snippet = '';
  let duedomains = 0;
  let nrdomains = 0;
  domains = domains.sortBy('domainname');
  for (const domain of domains) {
    let rowclass = [domain.registrantid, 'text-end'];
    if (domain.due) {
      duedomains++;
      rowclass.push('text-white bg-danger');
    }
    nrdomains++;
    snippet += `
                <tr data-domainid="${domain.domainid}">
                  <td><a href="<%== url_for('customer_index') %>/${customer.customerid}/${domains.domainid}">${domain.domainname}</a></td>
                  <td class="${rowclass.join(' ')}">${domain.curexpiry.substring(10, 0)}</td>
                </tr>`;
  }
  document.querySelector('#domains tbody').innerHTML = snippet;
  if (duedomains > 0) {
    document.querySelector('#duedomains').innerHTML = duedomains;
    document.querySelector('#duedomains').classList.remove("d-none");
  }
  if (nrdomains > 0) {
    document.querySelector('#nrdomains').innerHTML = nrdomains;
    document.querySelector('#nrdomains').classList.remove("d-none");
  }
  document.querySelector('#domainlistlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/domains`;

  // DNS zones - fetch from Zone model via customer-specific endpoint
  if (customer.customerid) {
    document.querySelector('#zonelistlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/zones`;
    fetchCustomerZones(customer.customerid);
  }

  // Websites
  snippet = '';
  let nrsites = 0;
  let webusage = 0;
  let datausage = 0;
  sites = sites.sortBy('domainname');
  for (const site of sites) {
    nrsites++;
    webusage += site.web_usage || 0;
    datausage += site.web_usage || 0;
    snippet += `
                <tr data-websiteid="${site.websiteid}">
                  <td><a class="d-block" href="<%== url_for('website_edit', websiteid => '_ID_') %>".replace('_ID_', site.websiteid)>${site.domainname || site.home || site.websiteid}</a></td>
                  <td class="text-end">${shortbytes(site.web_usage || 0)}</td>
                </tr>`;
  }
  document.querySelector('#sites tbody').innerHTML = snippet;
  if (nrsites > 0) {
    document.querySelector('#nrsites').innerHTML = nrsites;
    document.querySelector('#nrsites').classList.remove("d-none");
  }

  // Mail domains
  snippet = '';
  let nrmaildomains = 0;
  let mailusage = 0;
  maildomains = maildomains.sortBy('domainname');
  for (const maildomain of maildomains) {
    nrmaildomains++;
    mailusage += maildomain.mailusage;
    datausage += maildomain.mailusage;
    snippet += `
                <tr data-domainname="${maildomain.domainname}">
                  <td><a class="d-block" href="<%== url_for('customer_index') %>/${customer.customerid}/maildomains/${maildomain.domainname}">${maildomain.domainname}</a></td>
                  <td class="text-end">${shortbytes(maildomain.mailusage)}</td>
                </tr>`;
  }
  document.querySelector('#maildomains tbody').innerHTML = snippet;
  if (nrmaildomains > 0) {
    document.querySelector('#nrmaildomains').innerHTML = nrmaildomains;
    document.querySelector('#nrmaildomains').classList.remove("d-none");
  }

  // Datahases
  snippet = '';
  let nrdatabases = 0;
  let dbusage = 0;
  databases = databases.sortBy('databasename');
  for (const database of databases) {
    nrdatabases++;
    dbusage += database.db_usage;
    datausage += database.db_usage;
    snippet += `
                <tr data-databasename="${database.databasename}">
                  <td><a href="<%== sprintf('%sindex.php?route=/database/structure&server=1&db=', config->{manager}->{database}->{phpmyadmin}->{url}) %>${database.databasename}"><%== icon 'link' %></a></td>
                  <td><a class="d-block" href="<%== url_for('customer_index') %>/${customer.customerid}/databases/${database.databasename}">${database.databasename}</a></td>
                  <td>${database.username}</td>
                  <td class="text-end">${shortbytes(database.db_usage)}</td>
                </tr>`;
  }
  document.querySelector('#databases tbody').innerHTML = snippet;
  if (nrdatabases > 0) {
    document.querySelector('#nrdatabases').innerHTML = nrdatabases;
    document.querySelector('#nrdatabases').classList.remove("d-none");
  }

  // Subscriptions
  snippet = '';
  for (const subscription of subscriptions) {
    snippet += `
            <li class="list-group-item fw-bold subscription">
              ${subscription.productname}
              <div class="position-absolute top-50 me-2 end-0 translate-middle-y text-break">
                <a href="<%== url_for('customer_index') %>/${customer.customerid}/products/${subscription.productid}/remove"><%== icon 'trash' %></a>
              </div>
            </li>`;
  }

  document.querySelectorAll('.subscription').forEach((subscription) => {
    subscription.remove();
  });
  document.querySelector('#subscriptions').innerHTML = snippet + document.querySelector('#subscriptions').innerHTML;
  document.querySelector('#addproductlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/products/subscribe`;
  document.querySelector('#adddomainlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/domains/new`;
  document.querySelector('#addsitelink').href = `<%== url_for('customer_index') %>/${customer.customerid}/sites/new`;
  document.querySelector('#adddatabaselink').href = `<%== url_for('customer_index') %>/${customer.customerid}/databases/new`;
  document.querySelector('#adddnsdomainlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/dnsdomains/new`;
  document.querySelector('#addmaildomainlink').href = `<%== url_for('customer_index') %>/${customer.customerid}/maildomains/new`;

  if (datausage > 0) {
    document.querySelector('#datausage').innerHTML = '<%== __x("Data usage: {usage}", usage => "datausage") %>'
      .replace('datausage', shortbytes(datausage));
    document.querySelector('#datausage').classList.remove("d-none");

  }
  if (customer.updater && customer.updated) {
    document.querySelector('#updater').innerHTML = "<%== __x('Updated {updated} by {updater}', updated => 'updated', updater => 'updater') %>"
      .replace('updated', customer.updated.substring(0, 10))
      .replace('updater', customer.updater);
    document.querySelector('#updater').classList.remove("d-none");
  }
  if (customer.creator && customer.created) {
    document.querySelector('#creator').innerHTML = "<%== __x('Created {created} by {creator}', created => 'created', creator => 'creator') %>"
      .replace('created', customer.created.substring(0, 10))
      .replace('creator', customer.creator);
    document.querySelector('#creator').classList.remove("d-none");
  }


  if ('PUT' == method) {
    document.querySelector('#toast-messages').innerHTML = `
<%== web->indent($toast, 1) %>`;

    window.setTimeout(dropToast, 2000);
  }
}

function dropToast() {
  document.querySelector('#toast-messages').innerHTML = '';
}

getCustomer();