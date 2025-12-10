% # JavaScript for Stripe success page
const urlParams = new URLSearchParams(window.location.search);
const sessionId = urlParams.get('session_id');
const paymentIntent = urlParams.get('payment_intent');

if (sessionId || paymentIntent) {
  const details = document.getElementById('payment-details');
  if (sessionId) {
    details.innerHTML = '<small class="text-muted"><%= __("Session:") %> ' + sessionId.substring(0, 20) + '...</small>';
  } else if (paymentIntent) {
    details.innerHTML = '<small class="text-muted"><%= __("Payment:") %> ' + paymentIntent.substring(0, 20) + '...</small>';
  }
}
