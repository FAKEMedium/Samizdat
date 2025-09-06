<%== include 'sms/chunks/messagetable', format => 'js' %>

// SMS form functionality
const messageTextarea = document.getElementById('message');
const charCountSpan = document.getElementById('charCount');

if (messageTextarea && charCountSpan) {
    // Update character count
    function updateCharCount() {
        const count = messageTextarea.value.length;
        charCountSpan.textContent = count;
        
        if (count > 160) {
            charCountSpan.classList.add('text-danger');
        } else if (count > 140) {
            charCountSpan.classList.add('text-warning');
            charCountSpan.classList.remove('text-danger');
        } else {
            charCountSpan.classList.remove('text-warning', 'text-danger');
        }
    }
    
    messageTextarea.addEventListener('input', updateCharCount);
    updateCharCount(); // Initial count
}

// Form submission via AJAX
const smsForm = document.getElementById('smsForm');
const sendButton = document.getElementById('sendButton');
const toInput = document.getElementById('to');
const messageInput = document.getElementById('message');

if (smsForm) {
    smsForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        
        if (!smsForm.checkValidity()) {
            smsForm.classList.add('was-validated');
            return;
        }
        
        // Show loading state
        const originalText = sendButton.innerHTML;
        sendButton.disabled = true;
        sendButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Sending...';
        
        try {
            const formData = new FormData(smsForm);
            const response = await fetch('/sms', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json'
                },
                body: formData
            });
            
            const result = await response.json();
            
            if (result.success) {
                // Show success message
                showAlert('success', result.message_text || 'SMS sent successfully!');
                
                // Clear form
                smsForm.reset();
                smsForm.classList.remove('was-validated');
                updateCharCount(); // Reset character count
                
                // Refresh recent messages
                loadRecentMessages();
            } else {
                // Handle validation errors
                if (result.valid) {
                    // Update field validation states
                    if (result.valid.to === 'is-invalid') {
                        toInput.classList.add('is-invalid');
                        toInput.classList.remove('is-valid');
                    } else if (result.valid.to === 'is-valid') {
                        toInput.classList.add('is-valid');
                        toInput.classList.remove('is-invalid');
                    }
                    
                    if (result.valid.message === 'is-invalid') {
                        messageInput.classList.add('is-invalid');
                        messageInput.classList.remove('is-valid');
                    } else if (result.valid.message === 'is-valid') {
                        messageInput.classList.add('is-valid');
                        messageInput.classList.remove('is-invalid');
                    }
                }
                
                // Show error message
                let errorMsg = 'Failed to send SMS';
                if (result.errors) {
                    if (result.errors.general) {
                        errorMsg = result.errors.general;
                    } else if (result.errors.to) {
                        errorMsg = result.errors.to;
                    } else if (result.errors.message) {
                        errorMsg = result.errors.message;
                    }
                }
                showAlert('danger', errorMsg);
            }
        } catch (error) {
            console.error('Send SMS error:', error);
            showAlert('danger', 'Connection error. Please try again.');
        } finally {
            // Restore button state
            sendButton.disabled = false;
            sendButton.innerHTML = originalText;
        }
    });
}

// Clear validation on input change
if (toInput) {
    toInput.addEventListener('input', () => {
        toInput.classList.remove('is-invalid', 'is-valid');
    });
}

if (messageInput) {
    messageInput.addEventListener('input', () => {
        messageInput.classList.remove('is-invalid', 'is-valid');
    });
}


// Load recent messages
async function loadRecentMessages() {
    try {
        const response = await fetch('/sms/messages?limit=20');
        const data = await response.json();
        
        if (data.success) {
            populateMessagesTable(data.messages, false);
        } else {
            document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="6" class="text-center text-danger">Failed to load messages</td></tr>';
        }
    } catch (error) {
        console.error('Messages load failed:', error);
        document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="6" class="text-center text-danger">Failed to load messages</td></tr>';
    }
}

// Show alert function
function showAlert(type, message) {
    const alertsContainer = document.querySelector('.container-fluid .row:first-child .col-12');
    const existingAlert = alertsContainer.querySelector('.alert');
    
    // Remove existing alert
    if (existingAlert) {
        existingAlert.remove();
    }
    
    const alertHTML = `
        <div class="alert alert-${type} alert-dismissible fade show" role="alert">
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    `;
    
    const titleElement = alertsContainer.querySelector('h1');
    titleElement.insertAdjacentHTML('afterend', alertHTML);
    
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
        const alert = alertsContainer.querySelector('.alert');
        if (alert) {
            const bsAlert = new bootstrap.Alert(alert);
            bsAlert.close();
        }
    }, 5000);
}

// Pre-fill phone number from URL parameter
function prefillForm() {
    const urlParams = new URLSearchParams(window.location.search);
    const phoneParam = urlParams.get('to');
    
    if (phoneParam && toInput) {
        toInput.value = phoneParam;
        // Focus on message field if phone is pre-filled
        if (messageInput) {
            messageInput.focus();
        }
    }
}

// Load initial data
loadRecentMessages();
prefillForm();

// Auto-refresh every 30 seconds
setInterval(() => {
    loadRecentMessages();
}, 30000);