document.querySelector('#remindform').addEventListener("submit", (event) => {event.preventDefault()});

// Server-rendered default messages
const defaultMessages = {
  mild: `<%== $mild_message %>`,
  tough: `<%== $tough_message %>`
};

// Get invoice data from parent window (set by invoice/handle/index.js)
if (window.billingemail && document.querySelector('#billingemail')) {
  document.querySelector('#billingemail').value = window.billingemail;
}

// Get invoice number from parent window
if (window.fakturanummer && document.querySelector('#subject')) {
  document.querySelector('#subject').value = `<%== __x('Invoice reminder, {number}', number => 'INVOICE_NUMBER') %>`
    .replace('INVOICE_NUMBER', window.fakturanummer);
}

// Set default mild message
if (document.querySelector('#mailmessage')) {
  document.querySelector('#mailmessage').value = defaultMessages.mild;
}

// Handle radio button changes to switch message templates
document.querySelectorAll('input[name="severity"]').forEach(radio => {
  radio.addEventListener('change', (e) => {
    const messageField = document.querySelector('#mailmessage');
    if (messageField) {
      // Only change if current message matches one of the defaults
      const currentMessage = messageField.value.trim();
      if (currentMessage === defaultMessages.mild.trim() ||
          currentMessage === defaultMessages.tough.trim() ||
          currentMessage === '') {
        messageField.value = defaultMessages[e.target.value];
      }
    }
  });
});

// Function to send the reminder
window.sendReminder = async function() {
  const form = document.querySelector('#remindform');
  const formData = new FormData(form);

  // Get the reminder type from radio buttons
  const reminderType = document.querySelector('input[name="severity"]:checked').value;
  formData.set('type', reminderType);

  // Get customerid and invoiceid from parent window
  const customerid = window.customerid || document.querySelector('#customerid')?.value;
  const invoiceid = window.invoiceid || document.querySelector('#invoiceid')?.value;

  if (!customerid || !invoiceid) {
    alert('<%== __("Missing invoice information") %>');
    return false;
  }

  try {
    const response = await fetch(`<%== url_for('customer_index') %>/${customerid}/invoices/${invoiceid}/remind`, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: formData
    });

    if (response.ok) {
      const data = await response.json();
      // Close modal
      const modal = bootstrap.Modal.getInstance(document.querySelector('#universalmodal'));
      if (modal) {
        modal.hide();
      }
      // Show success message (could use a toast instead of alert)
      alert(`<%== __('Reminder sent successfully') %>`);
      // Reload the page to update reminder count
      window.location.reload();
    } else {
      const error = await response.text();
      alert(`<%== __('Failed to send reminder') %>: ${error}`);
    }
  } catch (error) {
    console.error('Error sending reminder:', error);
    alert(`<%== __('Error sending reminder') %>`);
  }

  return false;
}