async function sendData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch(window.location, request);
    if (response.error) {
      alert(error);
    } else {
      populate(await response.json());
    }
  } catch (e) {
    // Silent error handling
  }
}

function getCustomers(){
  sendData();
}

function populate(formdata) {
  let customers = formdata.customers;
  let searchterm = formdata.searchterm;
  let snippet = ''
  customers = customers.sortBy('-customerid');
  for (const customer of customers) {
    snippet += `
      <tr data-customerid="${customer.customerid}">
        <td><a class="w-auto" href="<%== url_for('customer_index') %>/${customer.customerid}">${customer.customerid}</a></td>
        <td>${customer.company.replace(searchterm, '<b>' + searchterm + '</b>')}</td>
        <td>${customer.firstname.replace(searchterm, '<b>' + searchterm + '</b>')}</td>
        <td>${customer.lastname.replace(searchterm, '<b>' + searchterm + '</b>')}</td>
      </tr>`;
  }
  document.querySelector('#customers tbody').innerHTML = snippet + `\n          `;
}

getCustomers();