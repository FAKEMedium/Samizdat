// Authenticated user functionality
// This bundle is loaded only for logged-in users

// Additional styles for authenticated users
import '../scss/authenticated.scss';

// Bootstrap components only needed for authenticated users
import Offcanvas from 'bootstrap/js/dist/offcanvas';
import Toast from 'bootstrap/js/dist/toast';
import Tooltip from 'bootstrap/js/dist/tooltip';
import Popover from 'bootstrap/js/dist/popover';
// Extend the existing bootstrap object
if (window.bootstrap) {
    window.bootstrap.Offcanvas = Offcanvas;
    window.bootstrap.Toast = Toast;
    window.bootstrap.Tooltip = Tooltip;
    window.bootstrap.Popover = Popover;
} else {
    window.bootstrap = { Offcanvas, Toast, Tooltip, Popover };
}

// String formatting functions for authenticated areas
import { sprintf, vsprintf } from 'sprintf-js';
window.sprintf = sprintf;
window.vsprintf = vsprintf;

// Byte formatting for file sizes in admin areas
import './shortbytes.js';

// Support for roomservice templates
window.initRoomService = function(serviceId) {
    const cardCol = document.querySelector(`#cardcol-${serviceId}`);
    if (cardCol) {
    }
};

// Dynamic form handling for authenticated areas
window.handleAuthForm = function(formId, endpoint) {
    const form = document.getElementById(formId);
    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(form);
            try {
                const response = await fetch(endpoint, {
                    method: 'POST',
                    body: formData,
                    credentials: 'same-origin'
                });
                const result = await response.json();
                if (result.success) {
                    location.reload();
                }
            } catch (error) {
            }
        });
    }
};

// Dynamic loading of TipTap editor for page editing
window.loadEditor = async function() {
    if (window.TipTap) {
        return window.TipTap;
    }
    
    // Dynamically load TipTap bundle
    const script = document.createElement('script');
    script.src = '/assets/editor.js';
    document.head.appendChild(script);
    
    return new Promise((resolve) => {
        script.onload = () => {
            setTimeout(() => resolve(window.TipTap), 100);
        };
    });
};

// Initialize page editor
window.initPageEditor = async function() {
    console.log('Starting editor initialization...');
    
    let editor, content, editorContainer;
    
    try {
        await window.loadEditor();
        console.log('Editor loaded');
        
        const manager = await window.initTipTapManager();
        console.log('TipTap manager initialized:', manager);
        
        content = document.getElementById('thecontent');
        if (!content) {
            console.error('thecontent element not found');
            return;
        }
        console.log('Found thecontent element:', content);
        
        // Store original content for cancel
        const originalHTML = content.innerHTML;
        
        // Skip TipTap - use simple contenteditable (styling handled by setEditable)
        
        // Store original content for cancel functionality
        content.dataset.originalContent = originalHTML;
        
        // Simple editor object for compatibility
        editor = {
            element: content,
            getHTML: () => content.innerHTML,
            setContent: (html) => content.innerHTML = html,
            setEditable: (editable) => {
                content.contentEditable = editable;
                if (editable) {
                    content.style.border = '2px solid #007bff';
                    content.style.padding = '10px';
                    content.style.cursor = 'text';
                } else {
                    content.style.border = '';
                    content.style.padding = '';
                    content.style.cursor = '';
                }
            },
            destroy: () => {
                content.contentEditable = 'false';
                content.style.border = '';
                content.style.padding = '';
                content.style.cursor = '';
            }
        };
        
        console.log('Simple contenteditable editor initialized');
        
        // Keep save/cancel buttons hidden - toolbar will handle editing
        const saveButton = document.getElementById('savePageButton');
        const cancelButton = document.getElementById('cancelPageButton');
        
        // Set up global editor reference (simplified)
        window.currentEditor = editor;
        
        return editor;
    } catch (error) {
        console.error('Error in initPageEditor:', error);
        return null;
    }
};


// Initialize toasts for authenticated users
const toastElList = document.querySelectorAll('.toast');
const toastList = [...toastElList].map(toastEl => new Toast(toastEl));

// Auto-initialize roomservice cards if present
document.querySelectorAll('[id^="cardcol-"]').forEach(card => {
    const serviceId = card.id.replace('cardcol-', '');
    window.initRoomService(serviceId);
});

// Check if we're on a markdown page and show edit button
const theContent = document.getElementById('thecontent');
const editButton = document.getElementById('editPageButton');

console.log('theContent found:', theContent);
console.log('editButton found:', editButton);

if (theContent && editButton) {
    // Check if user is authenticated (button visibility is controlled by auth class toggling)
    const checkAuth = () => {
        const userButtons = document.getElementById('userbuttons');
        if (userButtons && !userButtons.classList.contains('d-none')) {
            // User is logged in, show edit button
            editButton.classList.remove('d-none');
        }
    };
    
    // Check immediately and after a short delay (for auth state to be set)
    checkAuth();
    setTimeout(checkAuth, 100);
    
    // Handle edit button click
    editButton.addEventListener('click', async () => {
        console.log('Edit button clicked!');
        
        try {
            if (!window.currentEditor) {
                // First time - initialize editor
                console.log('Initializing editor for first time...');
                await window.initPageEditor();
            }
            
            // Enable simple editing and show save/cancel buttons
            editButton.classList.add('d-none');
            const saveButton = document.getElementById('savePageButton');
            const cancelButton = document.getElementById('cancelPageButton');
            if (saveButton) saveButton.classList.remove('d-none');
            if (cancelButton) cancelButton.classList.remove('d-none');
            
            // Enable editing mode
            if (window.currentEditor) {
                window.currentEditor.setEditable(true);
                window.currentEditor.element.focus();
                console.log('Simple editor enabled and focused');
            }
        } catch (error) {
            console.error('Error in edit button handler:', error);
        }
    });
    console.log('Edit button click handler attached');
    
    // Set up global save/cancel handlers for memberbuttons
    const saveButton = document.getElementById('savePageButton');
    const cancelButton = document.getElementById('cancelPageButton');
    
    if (saveButton) {
        saveButton.addEventListener('click', () => {
            if (window.currentEditor) {
                // Disable editing and clean up styling
                window.currentEditor.setEditable(false);
                console.log('Content saved and editor disabled');
                
                // Hide save/cancel buttons
                saveButton.classList.add('d-none');
                cancelButton.classList.add('d-none');
                editButton.classList.remove('d-none');
                editButton.disabled = false;
            }
        });
    }
    
    if (cancelButton) {
        cancelButton.addEventListener('click', () => {
            if (window.currentEditor) {
                // Cancel editing - revert to original content
                const originalContent = window.currentEditor.element.dataset.originalContent;
                window.currentEditor.setContent(originalContent);
                window.currentEditor.setEditable(false);
                console.log('Edit cancelled, reverted to original content');
                
                // Hide save/cancel buttons
                saveButton.classList.add('d-none');
                cancelButton.classList.add('d-none');
                editButton.classList.remove('d-none');
                editButton.disabled = false;
            }
        });
    }
}