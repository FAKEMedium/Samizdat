// Clean URL - remove UUID from location and history (like invoice/handle.js pattern)
function cleanUrl() {
  const stateObj = { confirmed: true };
  const cleanPath = window.location.pathname.replace(/\/[a-f0-9-]{36}$/, '');
  window.history.pushState(stateObj, document.title, cleanPath);
}

// Fetch confirmation status and handle result
async function handleConfirmation() {
  try {
    // Fetch confirmation result as JSON
    const form = document.querySelector('#dataform');
    const url = form ? form.action : window.location.pathname;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      credentials: 'same-origin'
    });

    const result = await response.json();

    if (result.success) {
      showSuccess(result.message);
      cleanUrl();
    } else {
      showError(result.message || '<%== __('Confirmation failed') %>');
      cleanUrl();
    }
  } catch (error) {
    console.error('<%== __('Confirmation error:') %>', error);
    showError('<%== __('Network error - please try again') %>');
  }
}

// Show success message
function showSuccess(message) {
  const content = document.getElementById('thecontent');
  if (content) {
    content.innerHTML = `
      <div class="alert alert-success" role="alert">
        <h4 class="alert-heading"><%== __('Email Confirmed!') %></h4>
        <p>${message}</p>
        <hr>
        <p class="mb-0"><%== __('You can now log in to your account.') %></p>
      </div>
    `;
  }
}

// Show error message in form or content area
function showError(message) {
  // Try to find existing form first
  const form = document.querySelector('form');
  if (form) {
    // Add error to form
    let errorDiv = form.querySelector('.alert-danger');
    if (!errorDiv) {
      errorDiv = document.createElement('div');
      errorDiv.className = 'alert alert-danger';
      errorDiv.setAttribute('role', 'alert');
      form.insertBefore(errorDiv, form.firstChild);
    }
    errorDiv.textContent = message;
  } else {
    // Fallback: replace content area
    const content = document.getElementById('thecontent');
    if (content) {
      content.innerHTML = `
        <div class="alert alert-danger" role="alert">
          <h4 class="alert-heading"><%== __('Confirmation Failed') %></h4>
          <p>${message}</p>
          <hr>
          <p class="mb-0"><%== __('Please check your confirmation link or register again.') %></p>
        </div>
      `;
    }
  }
}

// Setup POST JSON for any forms on the page
function setupFormHandling() {
  const forms = document.querySelectorAll('form');
  forms.forEach(form => {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const formData = new FormData(form);
      const data = Object.fromEntries(formData);
      
      try {
        const response = await fetch(form.action || window.location.pathname, {
          method: 'PUT',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(data),
          credentials: 'same-origin'
        });
        
        const result = await response.json();
        
        if (result.success) {
          showSuccess(result.message);
        } else {
          showError(result.message || '<%== __('An error occurred') %>');
        }
      } catch (error) {
        console.error('<%== __('Form submission error:') %>', error);
        showError('<%== __('Network error - please try again') %>');
      }
    });
  });
}

handleConfirmation();
setupFormHandling();
