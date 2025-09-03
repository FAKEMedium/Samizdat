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

// Form validation
const forms = document.querySelectorAll('.needs-validation');
forms.forEach(form => {
    form.addEventListener('submit', event => {
        if (!form.checkValidity()) {
            event.preventDefault();
            event.stopPropagation();
        }
        form.classList.add('was-validated');
    });
});

// Auto-refresh status every 30 seconds
setInterval(async () => {
    try {
        const response = await fetch('/sms/status');
        const data = await response.json();
        
        if (data.success) {
            // Update status indicators
            const status = data.status;
            // Could update UI elements here if needed
        }
    } catch (error) {
        console.log('Status update failed:', error);
    }
}, 30000);