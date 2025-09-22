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
        const url = ref.href || ref.action;
        const method = ref.method || 'get';
        const response = await fetch(url, { method: method});
        const body = await response.text();
        let modaldialog = document.querySelector('#modalDialog');
        modaldialog.innerHTML = "\n" + body;
        let modalscript = document.querySelector('#modalscript');
        let script = document.createElement('script');
        script.id = 'modaljs';
        script.innerHTML = modalscript.innerHTML;
        modaldialog.appendChild(script);
        document.querySelector('#modalscript').remove();
    } catch (e) {
        // Silent error handling
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