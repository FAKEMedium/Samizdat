// Nets Easy Checkout - Success Page
// Auto-refresh payment status
const PAYMENT_ID = '<%= $payment->{payment_id} %>';
const STATUS_URL = '<%== url_for('Nets.payment.status', payment_id => $payment->{payment_id}) %>';

// Optional: Poll for updated status
async function checkPaymentStatus() {
  try {
    const response = await fetch(STATUS_URL);
    const data = await response.json();

    if (data.success && data.status === 'charged') {
      console.log('Payment confirmed:', data);
    }
  } catch (error) {
    console.error('Status check error:', error);
  }
}

// Check status once after page load
setTimeout(checkPaymentStatus, 2000);
