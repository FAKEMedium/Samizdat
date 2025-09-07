// Conversation state - get phone from URL
const pathParts = window.location.pathname.split('/');
const phoneNumber = decodeURIComponent(pathParts[pathParts.length - 1]);
let currentPage = 1;
let totalPages = 1;
const perPage = <%= config->{sms}->{teltonika}->{perpage} || 20 %>;

// Format timestamp to show seconds precision
function formatTimestamp(timestamp) {
    if (!timestamp) return '';
    
    if (typeof timestamp === 'string' && timestamp.length > 19) {
        return timestamp.substring(0, 19);
    }
    
    return timestamp;
}

// Load conversation messages with pagination
async function loadMessages(page = 1) {
    try {
        const offset = (page - 1) * perPage;
        const response = await fetch(`<%= url_for 'sms_messages' %>?phone=${encodeURIComponent(phoneNumber)}&limit=${perPage}&offset=${offset}&total=1`, {
            headers: {
                'Accept': 'application/json'
            }
        });
        const data = await response.json();
        
        if (data.success) {
            renderConversation(data.messages);
            
            // Update pagination
            currentPage = page;
            totalPages = Math.ceil((data.total || 0) / perPage);
            updatePagination();
        } else {
            document.getElementById('messagesContainer').innerHTML = '<div class="text-center text-danger py-5"><%== __("Failed to load conversation") %></div>';
        }
    } catch (error) {
        console.error('Conversation load failed:', error);
        document.getElementById('messagesContainer').innerHTML = '<div class="text-center text-danger py-5"><%== __("Failed to load conversation") %></div>';
    }
}

// Render conversation with left/right alignment
function renderConversation(messages) {
    const container = document.getElementById('messagesContainer');
    
    if (!messages || messages.length === 0) {
        container.innerHTML = `
          <div class="text-center py-5">
            <i class="bi bi-chat text-muted d-block mx-auto mb-3" style="font-size: 4em;"></i>
            <h5 class="text-muted"><%== __('No messages yet') %></h5>
            <p class="text-muted mb-0"><%== __('Start a conversation by sending a message') %></p>
          </div>
        `;
        return;
    }

    const messagesHtml = messages.map(msg => {
        const isOutbound = msg.direction === 'outbound';
        const alignClass = isOutbound ? 'text-end' : 'text-start';
        const bgClass = isOutbound ? 'bg-primary text-white' : 'bg-light';
        const marginClass = isOutbound ? 'ms-auto' : 'me-auto';
        
        return `
          <div class="mb-3 ${alignClass}">
            <div class="d-inline-block p-3 rounded ${bgClass} ${marginClass}" style="max-width: 70%;">
              <div class="message-text">${msg.message}</div>
              <div class="message-time text-muted mt-1" style="font-size: 0.8em; ${isOutbound ? 'color: rgba(255,255,255,0.7) !important;' : ''}">
                ${formatTimestamp(msg.created_at)}
                <span class="badge badge-sm ms-1 ${msg.status === 'sent' ? 'text-bg-success' : 
                                                    msg.status === 'received' ? 'text-bg-info' :
                                                    msg.status === 'failed' ? 'text-bg-danger' : 'text-bg-warning'}">
                  ${msg.status}
                </span>
              </div>
            </div>
          </div>
        `;
    }).join('');
    
    container.innerHTML = messagesHtml;
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
        if (paginationNav) paginationNav.style.display = 'none';
        return;
    }
    
    if (paginationNav) paginationNav.style.display = 'block';
    
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

// Pre-fill form with conversation phone number
function prefillForm() {
    const toInput = document.querySelector('#to');
    if (toInput && phoneNumber) {
        toInput.value = phoneNumber;
        toInput.readOnly = true; // Can't change phone in conversation
        
        const messageInput = document.querySelector('#message');
        if (messageInput) {
            messageInput.focus();
        }
    }
}

// Sync messages
document.getElementById('syncMessages').addEventListener('click', async () => {
    const syncButton = document.getElementById('syncMessages');
    const originalText = syncButton.innerHTML;
    
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
            loadMessages(currentPage);
        } else {
            alert('<%== __("Sync failed") %>: ' + (result.error || '<%== __("Unknown error") %>'));
        }
    } catch (error) {
        console.error('Sync failed:', error);
        alert('<%== __("Sync failed") %>: ' + error.message);
    } finally {
        syncButton.disabled = false;
        syncButton.innerHTML = originalText;
    }
});

// Initialize page
initializePagination();
loadMessages(1);
prefillForm();