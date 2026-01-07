// Wrap in IIFE to prevent redeclaration errors on modal re-open
(function() {
  document.querySelector('#remindform').addEventListener("submit", (event) => {event.preventDefault()});

  // Server-rendered default messages - strip leading whitespace from each line
  // This prevents markdown from interpreting content as code blocks
  function cleanMarkdown(str) {
    return str.split('\n').map(line => line.trimStart()).join('\n').trim();
  }

  const defaultMessages = {
    mild: cleanMarkdown(`<%== $mild_message %>`),
    tough: cleanMarkdown(`<%== $tough_message %>`)
  };

  let reminderEditor = null;
  let currentMessageType = 'mild';

  // Get invoice data from parent window (set by invoice/handle/index.js)
  if (window.billingemail && document.querySelector('#billingemail')) {
    document.querySelector('#billingemail').value = window.billingemail;
  }

  // Get invoice number from parent window
  if (window.fakturanummer && document.querySelector('#subject')) {
    document.querySelector('#subject').value = `<%== __x('Invoice reminder, {number}', number => 'INVOICE_NUMBER') %>`
      .replace('INVOICE_NUMBER', window.fakturanummer);
  }

  // Initialize Toast UI Editor
  async function initReminderEditor() {
    const editorContainer = document.querySelector('#reminder-editor');
    if (!editorContainer) return;

    // Load Toast UI Editor if not already loaded
    if (typeof window.loadToastUIEditor === 'function' && !window.toastui?.Editor) {
      await window.loadToastUIEditor();
    }

    // Check if Editor is available
    const EditorClass = window.toastui?.Editor;
    if (!EditorClass) {
      console.error('Toast UI Editor not available');
      // Fallback to textarea - create properly to avoid encoding issues
      const textarea = document.createElement('textarea');
      textarea.className = 'form-control';
      textarea.id = 'mailmessage-textarea';
      textarea.rows = 15;
      textarea.value = defaultMessages.mild;
      editorContainer.appendChild(textarea);
      return;
    }

    reminderEditor = new EditorClass({
      el: editorContainer,
      height: '300px',
      initialEditType: 'wysiwyg',
      previewStyle: 'vertical',
      usageStatistics: false,
      toolbarItems: [
        ['heading', 'bold', 'italic', 'strike'],
        ['ul', 'ol'],
        ['link'],
        ['hr']
      ],
      initialValue: defaultMessages.mild
    });
  }

  // Handle radio button changes to switch message templates
  document.querySelectorAll('input[name="severity"]').forEach(radio => {
    radio.addEventListener('change', (e) => {
      const newType = e.target.value;
      if (reminderEditor) {
        // Only change if current message matches one of the defaults
        const currentMd = reminderEditor.getMarkdown();
        const mildNormalized = defaultMessages.mild.replace(/\s+/g, ' ').trim();
        const toughNormalized = defaultMessages.tough.replace(/\s+/g, ' ').trim();
        const currentNormalized = currentMd.replace(/\s+/g, ' ').trim();

        if (currentNormalized === mildNormalized ||
            currentNormalized === toughNormalized ||
            currentNormalized === '') {
          reminderEditor.setMarkdown(defaultMessages[newType]);
        }
      } else {
        // Fallback for textarea
        const textarea = document.querySelector('#mailmessage-textarea');
        if (textarea) {
          textarea.value = defaultMessages[newType];
        }
      }
      currentMessageType = newType;
    });
  });

  // Function to send the reminder
  window.sendReminder = async function() {
    const form = document.querySelector('#remindform');
    const formData = new FormData(form);

    // Get Markdown content from editor
    let mailContent = '';
    if (reminderEditor) {
      mailContent = reminderEditor.getMarkdown();
    } else {
      const textarea = document.querySelector('#mailmessage-textarea');
      mailContent = textarea ? textarea.value : '';
    }
    formData.set('mailmessage', mailContent);

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
      const url = `<%== url_for('Invoice.customer.remind', customerid => '_CID_', invoiceid => '_IID_') %>`.replace('_CID_', customerid).replace('_IID_', invoiceid);
      const response = await fetch(url, {
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
        // Show success message
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
  };

  // Event listener for submit button (CSP-compliant)
  document.querySelector('#submitremind')?.addEventListener('click', () => sendReminder());

  // Initialize editor when DOM is ready
  initReminderEditor();
})();
