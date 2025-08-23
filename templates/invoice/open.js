async function getData() {
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  try {
    const response = await fetch('<%== sprintf("%sinvoices/open", config->{managerurl}) %>', request);
    dress(await response.json());
  } catch (e) {
    // Silent error handling
  }
}

function dress(thedata) {
  let snippet = '';
  let totalsum = 0.00;
  let customers = thedata.customers;
  for (let customerid in customers) {
    if (customers.hasOwnProperty(customerid)) {
      let customer = customers[customerid];
      let debt = 0.00;
      let invoicesnippet = '';
      for (let invoiceid in customer.invoices) {
        if (customer.invoices.hasOwnProperty(invoiceid)) {
          let invoice = customer.invoices[invoiceid];
          let itemssnippet = '';
          for (let invoiceitemid in invoice.invoiceitems) {
            if (invoice.invoiceitems.hasOwnProperty(invoiceitemid)) {
              let invoiceitem = invoice.invoiceitems[invoiceitemid];
              let price = invoiceitem.price * invoiceitem.number * (1 + customer.vat);
              debt += price;
              totalsum += price;
              itemssnippet += `
        <tr>
          <td>${invoiceitem.invoiceitemtext}</td>
          <td class="text-end">${price} ${customer.currency}</td>
        </tr>`;
           }
          }
          invoicesnippet += itemssnippet;
        }
      }
      snippet += `
        <tr class="mt-2">
          <td class="orange px-2"><a href="<%== sprintf("%scustomers/", config->{managerurl}) %>${customerid}/invoices/open">${customerid} ${customer.name}</a></td>
          <td class="orange px-2 text-end">${debt} ${customer.currency}</td>
        </tr>`;
      snippet += invoicesnippet;
    }
  }
  document.querySelector('#openinvoices').innerHTML = snippet;
}

getData();