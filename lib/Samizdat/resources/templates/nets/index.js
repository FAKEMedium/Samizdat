// Nets Easy Checkout - Payment Form
const CHECKOUT_URL = '<%== url_for('Nets.checkout') %>';

const form = document.getElementById('payment-form');
const errorDiv = document.getElementById('payment-error');

form.addEventListener('submit', async (e) => {
  e.preventDefault();

  // Hide previous errors
  errorDiv.style.display = 'none';

  // Get form values
  const amount = parseFloat(document.getElementById('amount').value);
  const reference = document.getElementById('reference').value || `PAY-${Date.now()}`;
  const description = document.getElementById('description').value;

  // Convert amount to øre (smallest unit)
  const amountInOre = Math.round(amount * 100);

  // Build order items
  const items = [
    {
      reference: reference,
      name: description,
      quantity: 1,
      unit: 'pcs',
      unitPrice: amountInOre,
      taxRate: 0,
      taxAmount: 0,
      grossTotalAmount: amountInOre,
      netTotalAmount: amountInOre
    }
  ];

  // Create payment
  try {
    const response = await fetch(CHECKOUT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        amount: amountInOre,
        currency: 'SEK',
        reference: reference,
        items: items
      })
    });

    const data = await response.json();

    if (data.success && data.checkout_url) {
      // Redirect to Nets checkout page
      window.location.href = data.checkout_url;
    } else {
      throw new Error(data.error || '<%= __('Failed to create payment') %>');
    }
  } catch (error) {
    console.error('Payment error:', error);
    errorDiv.textContent = error.message || '<%= __('An error occurred') %>';
    errorDiv.style.display = 'block';
  }
});
