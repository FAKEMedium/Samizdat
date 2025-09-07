// Format timestamp to show seconds precision
function formatTimestamp(timestamp) {
    if (!timestamp) return '';
    
    // If it's a database timestamp, just take the first 19 chars (YYYY-MM-DD HH:MM:SS)
    if (typeof timestamp === 'string' && timestamp.length > 19) {
        return timestamp.substring(0, 19);
    }
    
    return timestamp;
}

// Check if a string looks like a replyable phone number
function isPhoneNumber(phone) {
    if (!phone) return false;
    
    // Exclude short codes (3-5 digits), service numbers, and @ symbols
    if (/^[\d]{3,5}$/.test(phone) || phone.includes('@')) return false;
    
    // Must start with + or digit, and contain at least 8 digits (proper phone numbers)
    const digitCount = (phone.match(/\d/g) || []).length;
    return digitCount >= 8 && /^[\+]?[\d\s\-\(\)]+$/.test(phone);
}

// Populate messages table body
function populateMessagesTable(messages, showActions = true) {
    const tbody = document.getElementById('messagesTableBody');
    
    if (!messages || messages.length === 0) {
        tbody.innerHTML = `
          <tr>
            <td colspan="5" class="text-center py-5">
              <i class="bi bi-inbox text-muted d-block mx-auto mb-3" style="font-size: 3em;"></i>
              <h5 class="text-muted"><%== __('No messages found') %></h5>
              <p class="text-muted mb-0"><%== __('Messages will appear here once sent or received') %></p>
            </td>
          </tr>
        `;
        return;
    }

    tbody.innerHTML = messages.map(msg => {
        console.log('Message data:', msg); // Debug log
        return `
            <tr data-message-id="${msg.id}">
                <td>
                    ${isPhoneNumber(msg.phone) ? 
                        `<a href="<%= url_for 'sms_index' %>?to=${encodeURIComponent(msg.phone)}" class="text-decoration-none">${msg.phone}</a>` :
                        `<span>${msg.phone}</span>`
                    }
                </td>
                <td>
                    <div class="message-preview" data-bs-toggle="tooltip" title="${msg.message}">
                        ${msg.message.length > 50 ? msg.message.substring(0, 50) + '...' : msg.message}
                    </div>
                </td>
                <td>
                    <span class="badge ${msg.status === 'sent' ? 'bg-primary' : 
                                     msg.status === 'received' ? 'bg-success' :
                                     msg.status === 'failed' ? 'bg-danger' : 'bg-warning'}">
                        ${msg.status}
                    </span>
                </td>
                <td class="text-muted small">${formatTimestamp(msg.created_at)}</td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-primary view-message" data-message="${msg.message}" data-phone="${msg.phone}">
                            <%== icon('eye') %>
                        </button>
                        ${isPhoneNumber(msg.phone) && msg.direction === 'inbound' ? `
                            <button class="btn btn-outline-success reply-message" data-phone="${msg.phone}">
                                <%== icon('reply') %>
                            </button>
                        ` : ''}
                        <button class="btn btn-outline-danger delete-message" data-id="${msg.id}">
                            <%== icon('trash') %>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
    
    // Re-initialize tooltips for new content
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));
}

// Initialize pagination event handlers
function initializePagination() {
    const prevLink = document.getElementById('prevLink');
    const nextLink = document.getElementById('nextLink');
    
    if (prevLink) {
        prevLink.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(prevLink.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    }
    
    if (nextLink) {
        nextLink.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(nextLink.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    }
}

// Update pagination UI using static HTML structure
function updatePagination() {
    const paginationNav = document.getElementById('messagesPagination');
    const paginationList = document.getElementById('paginationList');
    const prevButton = document.getElementById('prevButton');
    const nextButton = document.getElementById('nextButton');
    const prevLink = document.getElementById('prevLink');
    const nextLink = document.getElementById('nextLink');
    
    if (totalPages <= 1) {
        paginationNav.style.display = 'none';
        return;
    }
    
    paginationNav.style.display = 'block';
    
    // Update prev button state
    if (currentPage === 1) {
        prevButton.classList.add('disabled');
        prevLink.removeAttribute('data-page');
    } else {
        prevButton.classList.remove('disabled');
        prevLink.setAttribute('data-page', currentPage - 1);
    }
    
    // Update next button state
    if (currentPage === totalPages) {
        nextButton.classList.add('disabled');
        nextLink.removeAttribute('data-page');
    } else {
        nextButton.classList.remove('disabled');
        nextLink.setAttribute('data-page', currentPage + 1);
    }
    
    // Clear all page number buttons (keep only prev/next)
    const pageButtons = paginationList.querySelectorAll('.page-item:not(#prevButton):not(#nextButton)');
    pageButtons.forEach(btn => btn.remove());
    
    // Generate page number buttons
    let pageNumbersHtml = '';
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);
    
    if (startPage > 1) {
        pageNumbersHtml += '<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>';
        if (startPage > 2) {
            pageNumbersHtml += '<li class="page-item disabled"><span class="page-link">...</span></li>';
        }
    }
    
    for (let i = startPage; i <= endPage; i++) {
        pageNumbersHtml += `<li class="page-item ${i === currentPage ? 'active' : ''}">
            <a class="page-link" href="#" data-page="${i}">${i}</a>
        </li>`;
    }
    
    if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
            pageNumbersHtml += '<li class="page-item disabled"><span class="page-link">...</span></li>';
        }
        pageNumbersHtml += `<li class="page-item"><a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a></li>`;
    }
    
    // Insert page numbers before the next button
    nextButton.insertAdjacentHTML('beforebegin', pageNumbersHtml);
    
    // Add click handlers to all pagination links
    paginationList.querySelectorAll('a.page-link[data-page]').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(link.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    });
}

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
                showAlert('success', result.message_text || 'SMS sent successfully!');
                
                // Clear form
                smsForm.reset();
                smsForm.classList.remove('was-validated');
                updateCharCount(); // Reset character count
                
                // Refresh messages
                loadMessages(currentPage);
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


// Pagination state
let currentPage = 1;
let totalPages = 1;
const perPage = <%= config->{sms}->{teltonika}->{perpage} || 20 %>;

// Load messages with pagination
async function loadMessages(page = 1) {
    try {
        const offset = (page - 1) * perPage;
        const response = await fetch(`<%= url_for 'sms_messages' %>?limit=${perPage}&offset=${offset}&total=1`, {
            headers: {
                'Accept': 'application/json'
            }
        });
        const data = await response.json();
        
        if (data.success) {
            populateMessagesTable(data.messages, true);
            
            // Update pagination
            currentPage = page;
            totalPages = Math.ceil((data.total || 0) / perPage);
            updatePagination();
            
            // Add event listeners to action buttons
            addMessageEventListeners();
        } else {
            document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="5" class="text-center text-danger">Failed to load messages</td></tr>';
        }
    } catch (error) {
        console.error('Messages load failed:', error);
        document.getElementById('messagesTableBody').innerHTML = '<tr><td colspan="5" class="text-center text-danger">Failed to load messages</td></tr>';
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

// Pre-fill form from URL parameters
function prefillForm() {
    const urlParams = new URLSearchParams(window.location.search);
    const phoneParam = urlParams.get('to');
    const messageParam = urlParams.get('message');
    
    if (phoneParam && toInput) {
        toInput.value = phoneParam;
    }
    
    if (messageParam && messageInput) {
        messageInput.value = messageParam;
        updateCharCount(); // Update character count
    }
    
    // Focus on appropriate field
    if (phoneParam || messageParam) {
        if (phoneParam && !messageParam && messageInput) {
            messageInput.focus();
        } else if (messageParam && !phoneParam && toInput) {
            toInput.focus();
        } else if (phoneParam && messageParam && messageInput) {
            messageInput.focus();
            // Position cursor at end of message
            messageInput.setSelectionRange(messageInput.value.length, messageInput.value.length);
        }
    }
}


// Add message event listeners (copied from manager)
function addMessageEventListeners() {
    // View message handlers
    document.querySelectorAll('.view-message').forEach(btn => {
        btn.addEventListener('click', () => {
            const message = btn.dataset.message;
            const phone = btn.dataset.phone;
            
            const modalContent = `
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="modaltitle"><%== __('Message Details') %></h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="mb-3">
                            <label class="form-label fw-bold"><%== __('Phone Number') %></label>
                            <div class="form-control-plaintext">${phone}</div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label fw-bold"><%== __('Message') %></label>
                            <div class="form-control-plaintext border rounded p-3 bg-light">${message}</div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><%== __('Close') %></button>
                    </div>
                </div>
            `;
            
            const modalDialog = document.getElementById('modalDialog');
            const universalModal = new bootstrap.Modal('#universalmodal');
            modalDialog.innerHTML = modalContent;
            universalModal.show();
        });
    });

    // Reply message handlers
    document.querySelectorAll('.reply-message').forEach(btn => {
        btn.addEventListener('click', () => {
            const phone = btn.dataset.phone;
            // Pre-fill the form on the same page
            const toInput = document.getElementById('to');
            const messageInput = document.getElementById('message');
            if (toInput) toInput.value = phone;
            if (messageInput) messageInput.focus();
        });
    });

    // Delete message handlers
    document.querySelectorAll('.delete-message').forEach(btn => {
        btn.addEventListener('click', async () => {
            const id = btn.dataset.id;
            
            if (!confirm('<%== __("Are you sure you want to delete this message?") %>')) {
                return;
            }
            
            try {
                const response = await fetch('<%= url_for 'sms_delete', id => 'PLACEHOLDER' %>'.replace('PLACEHOLDER', id), {
                    method: 'DELETE',
                    headers: {
                        'Accept': 'application/json'
                    }
                });
                const result = await response.json();
                
                if (result.success) {
                    loadMessages(currentPage); // Reload current page
                } else {
                    alert('<%== __("Failed to delete message") %>: ' + (result.error || '<%== __("Unknown error") %>'));
                }
            } catch (error) {
                alert('<%== __("Failed to delete message") %>: ' + error.message);
            }
        });
    });
}

// Sync messages
document.getElementById('syncMessages').addEventListener('click', async () => {
    const syncButton = document.getElementById('syncMessages');
    const originalText = syncButton.innerHTML;
    
    // Show loading state
    syncButton.disabled = true;
    syncButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span><%== __("Syncing...") %>';
    
    try {
        const response = await fetch('<%= url_for 'sms_sync' %>', {
            method: 'POST',
            headers: {
                'Accept': 'application/json'
            }
        });
        const result = await response.json();
        
        if (result.success) {
            // Show success message and refresh data
            showAlert('success', `<%== __("Sync completed!") %> ${result.new_messages || 0} <%== __("new messages retrieved.") %>`);
            loadMessages(currentPage);
        } else {
            showAlert('danger', '<%== __("Sync failed") %>: ' + (result.error || '<%== __("Unknown error") %>'));
        }
    } catch (error) {
        console.error('Sync failed:', error);
        showAlert('danger', '<%== __("Sync failed") %>: ' + error.message);
    } finally {
        // Restore button state
        syncButton.disabled = false;
        syncButton.innerHTML = originalText;
    }
});


// Load initial data
initializePagination();
loadMessages(1);
prefillForm();

// Auto-refresh every 30 seconds
setInterval(() => {
    loadMessages(currentPage);
}, 30000);