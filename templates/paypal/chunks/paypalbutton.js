// PayPal button initialization using JavaScript SDK
(async function() {
  // Fetch PayPal configuration from server
  const configResponse = await fetch('<%== url_for('PayPal.config') %>');
  const config = await configResponse.json();

  // Load PayPal SDK dynamically
  const script = document.createElement('script');
  script.src = `https://www.paypal.com/sdk/js?client-id=${config.client_id}&currency=${config.currency}`;
  script.setAttribute('data-sdk-integration-source', 'button-factory');

  script.onload = function() {
    // Initialize PayPal Buttons
    paypal.Buttons({
      // Create order on server
      createOrder: async function(data, actions) {
        // Get button data attributes from container
        const container = document.getElementById('paypal-button-container');
        const amount = container.dataset.amount || '10.00';
        const currency = container.dataset.currency || config.currency;
        const description = container.dataset.description || 'Payment';

        const response = await fetch('<%== url_for('PayPal.orders.create') %>', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: amount,
            currency: currency,
            description: description
          })
        });

        const order = await response.json();
        return order.id;
      },

      // Capture order on server after approval
      onApprove: async function(data, actions) {
        const response = await fetch(`<%== url_for('PayPal.orders.create') %>`.replace('/create', `/${data.orderID}/capture`), {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          }
        });

        const orderData = await response.json();

        // Handle successful payment
        if (orderData.status === 'COMPLETED') {
          // Redirect to success page or show success message
          window.location.href = '<%== url_for('paypal_success') %>';
        } else {
          console.error('Payment not completed:', orderData);
          alert('Payment processing incomplete. Please contact support.');
        }
      },

      // Handle errors
      onError: function(err) {
        console.error('PayPal error:', err);
        alert('An error occurred during payment. Please try again.');
      },

      // Handle cancellation
      onCancel: function(data) {
        console.log('Payment cancelled:', data);
        window.location.href = '<%== url_for('paypal_cancel') %>';
      }
    }).render('#paypal-button-container');
  };

  document.head.appendChild(script);
})();
