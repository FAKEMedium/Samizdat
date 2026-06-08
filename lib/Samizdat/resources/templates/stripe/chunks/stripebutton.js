% # Stripe Payment Element initialization script
let stripe;
let elements;

async function initStripePayment(amount, options = {}) {
  // Fetch Stripe config
  const configResponse = await fetch('<%== url_for('Stripe.config') %>');
  const config = await configResponse.json();

  // Load Stripe.js
  if (!window.Stripe) {
    const script = document.createElement('script');
    script.src = 'https://js.stripe.com/v3/';
    script.async = true;
    await new Promise(resolve => {
      script.onload = resolve;
      document.head.appendChild(script);
    });
  }

  stripe = Stripe(config.publishable_key);

  // Create PaymentIntent
  const intentResponse = await fetch('<%== url_for('Stripe.paymentIntents.create') %>', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: amount,
      currency: options.currency || config.currency,
      description: options.description,
      customer_email: options.customerEmail,
      metadata: options.metadata,
    }),
  });

  const intent = await intentResponse.json();

  if (intent.error) {
    showMessage(intent.error_message || 'Failed to create payment intent');
    return;
  }

  // Initialize Stripe Elements
  elements = stripe.elements({
    clientSecret: intent.client_secret,
    appearance: {
      theme: 'stripe',
      variables: {
        colorPrimary: '#0d6efd',
      },
    },
  });

  // Create and mount Payment Element
  const paymentElement = elements.create('payment');
  paymentElement.mount('#stripe-payment-element');

  paymentElement.on('ready', () => {
    document.getElementById('stripe-submit-button').disabled = false;
  });

  paymentElement.on('change', (event) => {
    if (event.error) {
      showMessage(event.error.message);
    } else {
      hideMessage();
    }
  });

  // Handle form submission
  const form = document.getElementById('stripe-payment-form');
  form.addEventListener('submit', handleStripeSubmit);
}

async function handleStripeSubmit(event) {
  event.preventDefault();

  const submitButton = document.getElementById('stripe-submit-button');
  const buttonText = document.getElementById('stripe-button-text');
  const spinner = document.getElementById('stripe-spinner');

  submitButton.disabled = true;
  buttonText.classList.add('d-none');
  spinner.classList.remove('d-none');

  const { error } = await stripe.confirmPayment({
    elements,
    confirmParams: {
      return_url: window.location.origin + '<%== url_for('stripe_success') %>',
    },
  });

  if (error) {
    showMessage(error.message);
    submitButton.disabled = false;
    buttonText.classList.remove('d-none');
    spinner.classList.add('d-none');
  }
}

function showMessage(message) {
  const messageDiv = document.getElementById('stripe-payment-message');
  messageDiv.textContent = message;
  messageDiv.classList.remove('d-none');
}

function hideMessage() {
  const messageDiv = document.getElementById('stripe-payment-message');
  messageDiv.classList.add('d-none');
}

// Alternative: Redirect to Stripe Checkout
async function redirectToCheckout(amount, options = {}) {
  const response = await fetch('<%== url_for('Stripe.checkoutSessions.create') %>', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: amount,
      currency: options.currency,
      description: options.description,
      customer_email: options.customerEmail,
      metadata: options.metadata,
    }),
  });

  const session = await response.json();

  if (session.error) {
    showMessage(session.error_message || 'Failed to create checkout session');
    return;
  }

  // Redirect to Stripe Checkout
  window.location.href = session.url;
}
