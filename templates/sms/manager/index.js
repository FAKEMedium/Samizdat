<%== include 'sms/chunks/messagetable', format => 'js' %>

// Universal modal access
const universalModal = new bootstrap.Modal('#universalmodal');
const modalDialog = document.getElementById('modalDialog');


// Load messages table
async function loadMessagesTable() {
    try {
        const response = await fetch('/sms/messages?limit=25');
        const data = await response.json();
        
        if (data.success) {
            populateMessagesTable(data.messages, true);
            // Add event listeners to buttons
            addMessageEventListeners();
        } else {
            document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="7" class="text-center text-danger">Failed to load messages</td></tr>';
        }
    } catch (error) {
        console.error('Messages load failed:', error);
        document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="7" class="text-center text-danger">Failed to load messages</td></tr>';
    }
}

// Add event listeners to message buttons
function addMessageEventListeners() {
    // View message handlers
    document.querySelectorAll('.view-message').forEach(btn => {
        btn.addEventListener('click', () => {
            const message = btn.dataset.message;
            const phone = btn.dataset.phone;
            
            const modalContent = `
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="modaltitle">Message Details</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="mb-3">
                            <label class="form-label fw-bold">Phone Number</label>
                            <div class="form-control-plaintext">${phone}</div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label fw-bold">Message</label>
                            <div class="form-control-plaintext border rounded p-3 bg-light">${message}</div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    </div>
                </div>
            `;
            
            modalDialog.innerHTML = modalContent;
            universalModal.show();
        });
    });

    // Reply message handlers
    document.querySelectorAll('.reply-message').forEach(btn => {
        btn.addEventListener('click', () => {
            const phone = btn.dataset.phone;
            window.location.href = `/sms?to=${encodeURIComponent(phone)}`;
        });
    });

    // Delete message handlers
    document.querySelectorAll('.delete-message').forEach(btn => {
        btn.addEventListener('click', async () => {
            const id = btn.dataset.id;
            
            if (!confirm('Are you sure you want to delete this message?')) {
                return;
            }
            
            try {
                const response = await fetch(`/sms/messages/${id}`, {
                    method: 'DELETE'
                });
                const result = await response.json();
                
                if (result.success) {
                    loadMessagesTable(); // Reload the table
                } else {
                    alert('Failed to delete message: ' + (result.error || 'Unknown error'));
                }
            } catch (error) {
                alert('Failed to delete message: ' + error.message);
            }
        });
    });
}

// Refresh messages
document.getElementById('refreshMessages').addEventListener('click', () => {
    loadMessagesTable();
});

// Sync messages
document.getElementById('syncMessages').addEventListener('click', async () => {
    const syncButton = document.getElementById('syncMessages');
    const originalText = syncButton.innerHTML;
    
    // Show loading state
    syncButton.disabled = true;
    syncButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Syncing...';
    
    try {
        const response = await fetch('/sms/sync', {
            method: 'POST'
        });
        const result = await response.json();
        
        if (result.success) {
            // Show success message and refresh data
            alert(`Sync completed! ${result.new_messages || 0} new messages retrieved.`);
            loadMessagesTable();
        } else {
            alert('Sync failed: ' + (result.error || 'Unknown error'));
        }
    } catch (error) {
        console.error('Sync failed:', error);
        alert('Sync failed: ' + error.message);
    } finally {
        // Restore button state
        syncButton.disabled = false;
        syncButton.innerHTML = originalText;
    }
});

// Load initial data
loadMessagesTable();

// Auto-refresh every 60 seconds
setInterval(() => {
    loadMessagesTable();
}, 60000);