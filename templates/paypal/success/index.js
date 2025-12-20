% # JavaScript for PayPal success page - fetches JSON data
const urlParams = new URLSearchParams(window.location.search);

fetch('<%== url_for('PayPal.success') %>' + '?' + urlParams.toString(), {
  headers: {
    'Accept': 'application/json'
  }
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    const detailsDiv = document.getElementById('transaction-details');
    let html = '';

    if (data.txn_id) {
      html += '<p class="mb-0"><%= __("Transaction ID:") %> <strong>' + data.txn_id + '</strong></p>';
    }
    if (data.amount) {
      html += '<p class="mb-0"><%= __("Amount:") %> <strong>' + data.amount + '</strong></p>';
    }
    if (data.item_number) {
      html += '<p class="mb-0"><%= __("Item:") %> <strong>' + data.item_number + '</strong></p>';
    }

    detailsDiv.innerHTML = html;
  }
})
.catch(error => {
  console.error('Error fetching payment details:', error);
});
