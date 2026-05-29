async function loadCustomer() {
  try {
    const customerid = window.location.pathname.split('/').pop();
    const response = await fetch(`<%== url_for('Fortnox.customers.get', customerid => '_CID_') %>`.replace('_CID_', customerid), {
      method: 'GET',
      headers: { Accept: 'application/json' }
    });
    
    const data = await response.json();

    // Handle Fortnox auth redirect
    if (response.status === 401 && data.auth_url) {
      // Handled by the global fetch interceptor (apidom.js), which routes
      // through /fortnox/auth so the server returns us here afterwards.
      return;
    }

    if (data.fortnox && data.fortnox.customer) {
      const customer = data.fortnox.customer;
      populateCustomerDetails(customer);
    }
  } catch (error) {
    // Silent error handling
  }
}

function populateCustomerDetails(customer) {
  // Basic Information
  document.getElementById('customerNumber').textContent = customer.CustomerNumber || '';
  document.getElementById('name').textContent = customer.Name || '';
  document.getElementById('organisationNumber').textContent = customer.OrganisationNumber || '';
  document.getElementById('vatNumber').textContent = customer.VATNumber || '';

  // Set navigation links
  const custNum = customer.CustomerNumber;
  if (custNum) {
    document.getElementById('nav-prev').href = `<%== url_for('fortnox_customer_nav', customerid => '_CID_', to => 'prev') %>`.replace('_CID_', custNum);
    document.getElementById('nav-next').href = `<%== url_for('fortnox_customer_nav', customerid => '_CID_', to => 'next') %>`.replace('_CID_', custNum);
  }
  
  // Contact Information
  document.getElementById('email').textContent = customer.Email || '';
  document.getElementById('phone').textContent = customer.Phone || '';
  document.getElementById('emailInvoice').textContent = customer.EmailInvoice || '';
  document.getElementById('emailOffer').textContent = customer.EmailOffer || '';
  document.getElementById('emailOrder').textContent = customer.EmailOrder || '';
  
  // Address Information
  document.getElementById('address1').textContent = customer.Address1 || '';
  document.getElementById('address2').textContent = customer.Address2 || '';
  document.getElementById('zipCode').textContent = customer.ZipCode || '';
  document.getElementById('city').textContent = customer.City || '';
  document.getElementById('country').textContent = customer.Country || '';
  
  // Delivery Address
  document.getElementById('deliveryName').textContent = customer.DeliveryName || '';
  document.getElementById('deliveryAddress1').textContent = customer.DeliveryAddress1 || '';
  document.getElementById('deliveryAddress2').textContent = customer.DeliveryAddress2 || '';
  document.getElementById('deliveryZipCode').textContent = customer.DeliveryZipCode || '';
  document.getElementById('deliveryCity').textContent = customer.DeliveryCity || '';
  document.getElementById('deliveryCountry').textContent = customer.DeliveryCountry || '';
  
  // Financial Information
  document.getElementById('currency').textContent = customer.Currency || '';
  document.getElementById('termsOfPayment').textContent = customer.TermsOfPayment || '';
  document.getElementById('vatType').textContent = customer.VATType || '';
  document.getElementById('priceList').textContent = customer.PriceList || '';
  document.getElementById('discount').textContent = customer.Discount ? customer.Discount + '%' : '';
  
  // Other Information
  document.getElementById('active').textContent = customer.Active ? '<%== __('Yes') %>' : '<%== __('No') %>';
  document.getElementById('type').textContent = customer.Type || '';
  document.getElementById('comments').textContent = customer.Comments || '';
  document.getElementById('yourReference').textContent = customer.YourReference || '';
  document.getElementById('ourReference').textContent = customer.OurReference || '';
  
  // Update modal title
  const modalTitle = document.querySelector('.modal-title');
  if (modalTitle) {
    modalTitle.textContent = `<%== __('Customer') %>: ${customer.Name || customer.CustomerNumber || ''}`;
  }
}

// Load customer on page load
loadCustomer();