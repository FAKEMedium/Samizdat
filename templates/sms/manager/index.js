// Initialize tooltips
const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));

// Universal modal access
const universalModal = new bootstrap.Modal('#universalmodal');
const modalDialog = document.getElementById('modalDialog');

// View message handler
document.querySelectorAll('.view-message').forEach(btn => {
    btn.addEventListener('click', () => {
        const message = btn.dataset.message;
        const phone = btn.dataset.phone;
        
        // Create modal content for message view
        const modalContent = `
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="modaltitle">${window.i18n_('Message Details')}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="form-label fw-bold">${window.i18n_('Phone Number')}</label>
                        <div class="form-control-plaintext">${phone}</div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label fw-bold">${window.i18n_('Message')}</label>
                        <div class="form-control-plaintext border rounded p-3 bg-light">${message}</div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                        ${window.i18n_('Close')}
                    </button>
                </div>
            </div>
        `;
        
        modalDialog.innerHTML = modalContent;
        universalModal.show();
    });
});

// Reply message handler
document.querySelectorAll('.reply-message').forEach(btn => {
    btn.addEventListener('click', () => {
        const phone = btn.dataset.phone;
        window.location.href = `/sms?to=${encodeURIComponent(phone)}`;
    });
});

// Delete message handler
document.querySelectorAll('.delete-message').forEach(btn => {
    btn.addEventListener('click', async () => {
        const id = btn.dataset.id;
        
        if (!confirm(window.i18n_('Are you sure you want to delete this message?'))) {
            return;
        }
        
        try {
            const response = await fetch(`/sms/messages/${id}`, {
                method: 'DELETE'
            });
            const result = await response.json();
            
            if (result.success) {
                // Remove row from table
                const row = document.querySelector(`tr[data-message-id="${id}"]`);
                if (row) {
                    row.remove();
                }
            } else {
                alert(window.i18n_('Failed to delete message: {error}', {error: result.error || 'Unknown error'}));
            }
        } catch (error) {
            alert(window.i18n_('Failed to delete message: {error}', {error: error.message}));
        }
    });
});

// Refresh messages
document.getElementById('refreshMessages').addEventListener('click', () => {
    location.reload();
});

// Auto-refresh every 60 seconds
setInterval(() => {
    location.reload();
}, 60000);