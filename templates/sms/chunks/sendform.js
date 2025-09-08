// SMS form functionality
console.log('Sendform.js loading...');
const messageTextarea = document.getElementById('message');
const charCountSpan = document.getElementById('charCount');
console.log('Elements found:', {messageTextarea, charCountSpan});

// Global update character count function
function updateCharCount() {
    if (messageTextarea && charCountSpan) {
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
}

if (messageTextarea && charCountSpan) {
    messageTextarea.addEventListener('input', updateCharCount);
    updateCharCount(); // Initial count
}

// Form submission via AJAX
const smsForm = document.getElementById('smsForm');
const sendButton = document.getElementById('sendButton');
const toInput = document.getElementById('to');
const messageInput = document.getElementById('message');
console.log('Form elements found:', {smsForm, sendButton, toInput, messageInput});

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
        sendButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span><%== __("Sending...") %>';
        
        try {
            const formData = new FormData(smsForm);
            const response = await fetch('<%= url_for 'sms_index' %>', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json'
                },
                body: formData
            });
            
            const result = await response.json();
            
            if (result.success) {
                // Show success message
                if (window.showAlert) {
                    try {
                        showAlert('success', result.message_text || '<%== __("SMS sent successfully!") %>');
                    } catch (e) {
                        alert('<%== __("SMS sent successfully!") %>');
                    }
                } else {
                    alert('<%== __("SMS sent successfully!") %>');
                }
                
                // Clear form
                smsForm.reset();
                smsForm.classList.remove('was-validated');
                updateCharCount();
                
                // Refresh messages if loadMessages function exists
                if (window.loadMessages && window.currentPage !== undefined) {
                    loadMessages(currentPage);
                }
                
                // Re-fill phone if in conversation mode
                if (window.phoneNumber && toInput) {
                    toInput.value = phoneNumber;
                }
                if (messageInput) {
                    messageInput.focus();
                }
            } else {
                // Handle validation errors
                if (result.valid) {
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
                let errorMsg = '<%== __("Failed to send SMS") %>';
                if (result.errors) {
                    if (result.errors.general) {
                        errorMsg = result.errors.general;
                    } else if (result.errors.to) {
                        errorMsg = result.errors.to;
                    } else if (result.errors.message) {
                        errorMsg = result.errors.message;
                    }
                }
                
                if (window.showAlert) {
                    try {
                        showAlert('danger', errorMsg);
                    } catch (e) {
                        alert(errorMsg);
                    }
                } else {
                    alert(errorMsg);
                }
            }
        } catch (error) {
            console.error('Send SMS error:', error);
            const errorMsg = '<%== __("Connection error. Please try again.") %>';
            if (window.showAlert) {
                try {
                    showAlert('danger', errorMsg);
                } catch (e) {
                    alert(errorMsg);
                }
            } else {
                alert(errorMsg);
            }
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