// Swish button initialization
(function() {
  const container = document.getElementById('swish-button-container');
  const phoneInput = document.getElementById('swish-phone');
  const payBtn = document.getElementById('swish-pay-btn');
  const statusDiv = document.getElementById('swish-status');
  const qrDiv = document.getElementById('swish-qr');

  if (!container || !payBtn) return;

  // Get amount and other data from container data attributes
  const amount = container.dataset.amount || '100';
  const message = container.dataset.message || '';
  const reference = container.dataset.reference || '';
  const customerid = container.dataset.customerid || '';

  payBtn.addEventListener('click', async function() {
    payBtn.disabled = true;
    statusDiv.style.display = 'block';
    statusDiv.innerHTML = '<div class="alert alert-info"><%= __("Creating payment...") %></div>';

    // Format phone number (convert 07xxx to 467xxx)
    let payerAlias = phoneInput.value.trim().replace(/\D/g, '');
    if (payerAlias.startsWith('0')) {
      payerAlias = '46' + payerAlias.substring(1);
    }

    const body = {
      amount: parseInt(amount),
      message: message,
      reference: reference
    };

    // Add payer alias for e-commerce flow (if phone provided)
    if (payerAlias && payerAlias.length >= 10) {
      body.payer_alias = payerAlias;
    }

    // Add customer ID if provided
    if (customerid) {
      body.customerid = parseInt(customerid);
    }

    try {
      const response = await fetch('<%== url_for('Swish.payments.create') %>', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body)
      });

      const payment = await response.json();

      if (payment.error) {
        statusDiv.innerHTML = `<div class="alert alert-danger">${payment.error_message || '<%= __("Payment failed") %>'}</div>`;
        payBtn.disabled = false;
        return;
      }

      if (payment.flow_type === 'mcommerce' && payment.payment_request_token) {
        // M-commerce: show QR code or app link
        statusDiv.innerHTML = '<div class="alert alert-info"><%= __("Scan QR code or tap to open Swish app") %></div>';
        qrDiv.style.display = 'block';

        // Fetch QR code SVG from server
        const qrUrl = `<%== url_for('Swish.qr') %>?payee=${encodeURIComponent(payment.payee_alias || '')}&amount=${amount}&message=${encodeURIComponent(message)}`;
        fetch(qrUrl)
          .then(r => r.text())
          .then(svg => {
            qrDiv.innerHTML = `
              <div class="text-center mb-3">${svg}</div>
              <a href="${payment.swish_url}" class="btn btn-lg btn-success d-block mb-2">
                <%= __("Open Swish App") %>
              </a>
              <p class="text-muted small"><%= __("Or scan QR code with Swish app") %></p>
            `;
          })
          .catch(() => {
            qrDiv.innerHTML = `
              <a href="${payment.swish_url}" class="btn btn-lg btn-success d-block mb-2">
                <%= __("Open Swish App") %>
              </a>
              <p class="text-muted small"><%= __("Or scan QR code with Swish app") %></p>
            `;
          });

        // Poll for payment status
        pollPaymentStatus(payment.instruction_id);
      } else {
        // E-commerce: payment request sent to phone
        statusDiv.innerHTML = '<div class="alert alert-success"><%= __("Payment request sent! Open your Swish app to confirm.") %></div>';
        // Poll for payment status
        pollPaymentStatus(payment.instruction_id);
      }

    } catch (error) {
      console.error('Swish payment error:', error);
      statusDiv.innerHTML = '<div class="alert alert-danger"><%= __("An error occurred. Please try again.") %></div>';
      payBtn.disabled = false;
    }
  });

  async function pollPaymentStatus(instructionId) {
    let attempts = 0;
    const maxAttempts = 60; // 5 minutes with 5 second intervals

    const poll = async () => {
      attempts++;
      if (attempts > maxAttempts) {
        statusDiv.innerHTML = '<div class="alert alert-warning"><%= __("Payment timeout. Please check your Swish app.") %></div>';
        payBtn.disabled = false;
        return;
      }

      try {
        const response = await fetch(`<%== url_for('Swish.payments.get', id => '_ID_') %>`.replace('_ID_', instructionId));
        const payment = await response.json();

        if (payment.status === 'PAID') {
          statusDiv.innerHTML = '<div class="alert alert-success"><%= __("Payment successful!") %></div>';
          qrDiv.style.display = 'none';
          setTimeout(() => {
            window.location.href = '<%== url_for('swish_success') %>?id=' + instructionId;
          }, 1500);
          return;
        }

        if (payment.status === 'DECLINED' || payment.status === 'ERROR' || payment.status === 'CANCELLED') {
          statusDiv.innerHTML = `<div class="alert alert-danger">${payment.error_message || '<%= __("Payment was declined or cancelled.") %>'}</div>`;
          qrDiv.style.display = 'none';
          payBtn.disabled = false;
          return;
        }

        // Still pending, poll again
        setTimeout(poll, 5000);
      } catch (error) {
        console.error('Poll error:', error);
        setTimeout(poll, 5000);
      }
    };

    setTimeout(poll, 3000); // Start polling after 3 seconds
  }
})();
