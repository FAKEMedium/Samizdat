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
                <td colspan="${showActions ? '7' : '6'}" class="text-center py-5">
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
                <td>${msg.id}</td>
                <td>
                    <span class="badge ${msg.direction === 'outbound' ? 'bg-primary' : 'bg-success'}">
                        <i class="bi bi-arrow-${msg.direction === 'outbound' ? 'up' : 'down'}"></i>
                        ${msg.direction === 'outbound' ? '<%== __("Sent") %>' : '<%== __("Received") %>'}
                    </span>
                </td>
                <td>
                    ${isPhoneNumber(msg.phone) ? 
                        `<a href="/sms?to=${encodeURIComponent(msg.phone)}&message=${encodeURIComponent('<%== __("Re:") %> ' + msg.message)}" class="text-decoration-none">${msg.phone}</a>` :
                        `<span>${msg.phone}</span>`
                    }
                </td>
                <td>
                    <div class="message-preview" data-bs-toggle="tooltip" title="${msg.message}">
                        ${msg.message.length > 50 ? msg.message.substring(0, 50) + '...' : msg.message}
                    </div>
                </td>
                <td>
                    <span class="badge ${['sent', 'received'].includes(msg.status) ? 'bg-success' : 
                                     msg.status === 'failed' ? 'bg-danger' : 'bg-warning'}">
                        ${msg.status}
                    </span>
                </td>
                <td class="text-muted small">${formatTimestamp(msg.created_at)}</td>
                ${showActions ? `
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-primary view-message" 
                                    data-message="${msg.message}" data-phone="${msg.phone}">
                                <i class="bi bi-eye"></i>
                            </button>
                            ${msg.direction === 'inbound' ? `
                                <button class="btn btn-outline-success reply-message" 
                                        data-phone="${msg.phone}">
                                    <i class="bi bi-reply"></i>
                                </button>
                            ` : ''}
                            <button class="btn btn-outline-danger delete-message" 
                                    data-id="${msg.id}">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </td>
                ` : ''}
            </tr>
        `;
    }).join('');
    
    // Re-initialize tooltips for new content
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));
}