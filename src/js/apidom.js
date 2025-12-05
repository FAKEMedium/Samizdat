 async function magiclink (event, el) {
    try {
        const ref = el || event.relatedTarget;
        const url = ref.href || ref.action;
        const method = ref.method || 'get';
        const response = await fetch(url, { method: method});
        return await response.text();
    } catch (e) {
        return '';
    }
}

async function modalLoad(event) {
    try {
        let ref = event.relatedTarget;
        // Skip if modal was opened programmatically (no relatedTarget)
        if (!ref) return;

        const url = ref.href || ref.action;
        const method = ref.method || 'get';
        const response = await fetch(url, { method: method});
        const body = await response.text();
        let modaldialog = document.querySelector('#modalDialog');
        modaldialog.dataset.sourceUrl = url;
        modaldialog.innerHTML = "\n" + body;
        let modalscript = document.querySelector('#modalscript');
        if (modalscript) {
            let script = document.createElement('script');
            script.id = 'modaljs';
            script.innerHTML = modalscript.innerHTML;
            modaldialog.appendChild(script);
            modalscript.remove();
        }
    } catch (e) {
        console.error('modalLoad error:', e);
    }
}

document.querySelectorAll("html").forEach(docroot => {
    docroot.classList.remove("no-js");
    docroot.classList.add("js");
});
const universalmodal = document.querySelector('#universalmodal');
universalmodal.addEventListener('shown.bs.modal', (event) => modalLoad(event));

// Function to show login modal with optional error message
async function showLoginModal(errorMessage) {
    try {
        // Fetch the login form
        const response = await fetch('/account/login', {
            method: 'GET',
            headers: {
                'Accept': 'text/html'
            }
        });
        const body = await response.text();

        // Insert into modal
        let modaldialog = document.querySelector('#modalDialog');
        modaldialog.innerHTML = "\n" + body;

        // If there's an error message, display it
        if (errorMessage) {
            const loginalert = modaldialog.querySelector('#loginalert');
            if (loginalert) {
                loginalert.classList.add('alert-danger');
                loginalert.classList.remove('alert-light');
                loginalert.innerHTML = errorMessage;
            }
        }

        // Extract and execute any scripts in the modal
        let modalscript = modaldialog.querySelector('#modalscript');
        if (modalscript) {
            let script = document.createElement('script');
            script.id = 'modaljs';
            script.innerHTML = modalscript.innerHTML;
            modaldialog.appendChild(script);
            modalscript.remove();
        }

        // Show the modal
        const modal = bootstrap.Modal.getOrCreateInstance(universalmodal);
        modal.show();
    } catch (e) {
        console.error('Error loading login modal:', e);
    }
}

// Global 401 handler
window.handle401Error = function(errorMessage) {
    showLoginModal(errorMessage);
};

// Reusable authenticated fetch wrapper
async function authenticatedFetch(url, options = {}) {
    // Set default headers
    options.headers = options.headers || {};
    if (!options.headers.Accept) {
        options.headers.Accept = 'application/json';
    }
    // Auto-set Content-Type for JSON bodies
    if (options.body && typeof options.body === 'string' && !options.headers['Content-Type']) {
        try {
            JSON.parse(options.body);
            options.headers['Content-Type'] = 'application/json';
        } catch (e) {
            // Not JSON, leave Content-Type unset
        }
    }

    try {
        const response = await fetch(url, options);

        if (!response.ok) {
            if (response.status === 401) {
                const data = await response.json();
                // Show login modal with error message
                if (window.handle401Error) {
                    window.handle401Error(data.error || 'Authentication required');
                } else {
                    // Fallback to redirect if modal handler not available
                    window.location.href = '/account/login';
                }
                return null; // Return null to indicate auth failure
            } else {
                // For other errors, try to get error message from response
                try {
                    const errorData = await response.json();
                    if (errorData.error) {
                        console.error('Request failed:', errorData.error);
                        alert(errorData.error);
                    } else {
                        console.error('Request failed:', response.statusText);
                        alert('Request failed: ' + response.statusText);
                    }
                } catch {
                    console.error('Request failed:', response.statusText);
                    alert('Request failed: ' + response.statusText);
                }
                return null;
            }
        }

        // Parse response based on content type
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
            return await response.json();
        } else {
            return await response.text();
        }
    } catch (e) {
        console.error('Request error:', e);
        alert('Request failed');
        return null;
    }
}

// Export for use in other scripts
window.authenticatedFetch = authenticatedFetch;

// Global toast notification function
window.showToast = function(message, type = 'success') {
    const toastContainer = document.getElementById('toast-messages');
    if (!toastContainer) {
        console.warn('Toast container #toast-messages not found');
        return;
    }

    const bgClass = type === 'danger' ? 'bg-danger' : (type === 'warning' ? 'bg-warning' : 'bg-success');
    const toastHtml = `
        <div class="toast align-items-center text-white ${bgClass} border-0" role="alert" aria-live="assertive" aria-atomic="true">
            <div class="d-flex">
                <div class="toast-body">${message}</div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
            </div>
        </div>
    `;
    toastContainer.insertAdjacentHTML('beforeend', toastHtml);
    const toastEl = toastContainer.lastElementChild;
    const toast = new bootstrap.Toast(toastEl, { delay: 3000 });
    toast.show();
    toastEl.addEventListener('hidden.bs.toast', () => toastEl.remove());
};

// Simple fetch wrapper that silently handles errors (for public endpoints)
async function simpleFetch(url, options = {}) {
    options.headers = options.headers || {};
    if (!options.headers.Accept) {
        options.headers.Accept = 'application/json';
    }

    try {
        const response = await fetch(url, options);
        if (!response.ok) {
            return null;
        }

        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
            return await response.json();
        } else {
            return await response.text();
        }
    } catch (e) {
        // Silent error handling for public endpoints
        return null;
    }
}

window.simpleFetch = simpleFetch;

// Global fetch interceptor to handle 401 responses automatically
(function() {
    const originalFetch = window.fetch;
    window.fetch = function(...args) {
        return originalFetch.apply(this, args).then(async response => {
            // If 401 and response is JSON, trigger login modal
            if (response.status === 401) {
                const contentType = response.headers.get('content-type');
                if (contentType && contentType.includes('application/json')) {
                    try {
                        const clonedResponse = response.clone();
                        const data = await clonedResponse.json();
                        if (window.handle401Error) {
                            window.handle401Error(data.error || 'Authentication required');
                        }
                    } catch (e) {
                        // If JSON parsing fails, just show generic message
                        if (window.handle401Error) {
                            window.handle401Error('Authentication required');
                        }
                    }
                }
            }
            return response;
        });
    };
})();