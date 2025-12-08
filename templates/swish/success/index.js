% # JavaScript for Swish success page
const urlParams = new URLSearchParams(window.location.search);
const details = document.getElementById('transaction-details');

if (urlParams.has('id')) {
  details.innerHTML = '<p><%= __("Payment ID:") %> ' + urlParams.get('id') + '</p>';
}
