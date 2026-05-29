async function sendData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(window.location, request);
    if (!response.ok) {
      if (response.status === 401) {
        // Handled by the global fetch interceptor (apidom.js), which opens the
        // login form in #universalmodal. Don't double-handle it here.
        return;
      } else {
        alert('Request failed: ' + response.statusText);
      }
    } else {
      populate(await response.json());
    }
  } catch (e) {
    console.error('Request error:', e);
    alert('Request failed');
  }
}

function getCustomers(){
  sendData();
}

function populate(formdata) {
  const customers = (formdata.customers || []);
  const isAdmin = formdata.admin !== 0;

  if (isAdmin) {
    const searchterm = formdata.searchterm || '';
    let snippet = '';
    customers.sortBy('-customerid');
    for (const customer of customers) {
      snippet += `
        <tr data-customerid="${customer.customerid}">
          <td><a class="w-auto" href="<%== url_for('customer_index') %>/${customer.customerid}">${customer.customerid}</a></td>
          <td>${(customer.company || '').replace(searchterm, '<b>' + searchterm + '</b>')}</td>
          <td>${(customer.firstname || '').replace(searchterm, '<b>' + searchterm + '</b>')}</td>
          <td>${(customer.lastname || '').replace(searchterm, '<b>' + searchterm + '</b>')}</td>
        </tr>`;
    }
    document.querySelector('#customers tbody').innerHTML = snippet;
    document.querySelector('#customers').classList.remove('d-none');
  } else {
    if (customers.length === 0) {
      document.querySelector('#no-affiliations').classList.remove('d-none');
    } else {
      let snippet = '';
      customers.sortBy('customerid');
      for (const customer of customers) {
        const name = [customer.firstname, customer.lastname].filter(Boolean).join(' ');
        snippet += `
          <tr data-customerid="${customer.customerid}">
            <td><a class="w-auto" href="<%== url_for('customer_index') %>/${customer.customerid}">${customer.customerid}</a></td>
            <td>${customer.company || ''}</td>
            <td>${name}</td>
            <td>${customer.roles || ''}</td>
          </tr>`;
      }
      document.querySelector('#mycustomers tbody').innerHTML = snippet;
      document.querySelector('#mycustomers').classList.remove('d-none');
    }
  }
}

getCustomers();
