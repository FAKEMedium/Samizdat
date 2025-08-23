async function loadCustomers() {
  try {
    const response = await fetch('<%== url_for('fortnox_customer') %>', {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });
    
    const data = await response.json();
    
    if (data.fortnox && data.fortnox.customers) {
      const customers = data.fortnox.customers || [];
      const tbody = document.querySelector('#customers tbody');
      let html = '';
      
      // Sort customers by customer number or name
      customers.sort((a, b) => {
        if (a.CustomerNumber && b.CustomerNumber) {
          return a.CustomerNumber.localeCompare(b.CustomerNumber);
        }
        return 0;
      });
      
      customers.forEach(customer => {
        const customerNumber = customer.CustomerNumber || '';
        const name = customer.Name || '';
        const orgno = customer.OrganisationNumber || ''
        html += `
          <tr>
            <td><a href="<%== url_for('fortnox_customer') %>/${customerNumber}">${customerNumber}</a></td>
            <td>${name}</td>
            <td class="text-end">${orgno}</td>
          </tr>
        `;
      });
      
      tbody.innerHTML = html;
      
      // Update footer with total count
      const tfoot = document.querySelector('#customers tfoot th');
      tfoot.textContent = `<%== __x('Total: {count} customers', { count => '${customers.length}' }) %>`;
    }
  } catch (error) {
    // Silent error handling
  }
}

// Load customers on page load
loadCustomers();