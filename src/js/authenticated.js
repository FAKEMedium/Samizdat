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
    script.src = '/assets/tiptap.js';
    document.head.appendChild(script);
    
    return new Promise((resolve) => {
        script.onload = () => {
            setTimeout(() => resolve(window.TipTap), 100);
        };
    });
};

// Initialize page editor
window.initPageEditor = async function() {
    const content = document.getElementById('thecontent');
    if (!content) return;
    
    const TipTap = await window.loadEditor();
    if (!TipTap || !TipTap.Editor) return;
    
    // Create wrapper for editor
    const wrapper = document.createElement('div');
    wrapper.id = 'editor-wrapper';
    wrapper.className = content.className;
    content.parentNode.insertBefore(wrapper, content);
    
    // Create editor container
    const editorContainer = document.createElement('div');
    editorContainer.id = 'tiptap-editor';
    editorContainer.style.minHeight = '400px';
    wrapper.appendChild(editorContainer);
    
    // Hide original content
    content.style.display = 'none';
    
    // Initialize TipTap editor
    const editor = new TipTap.Editor({
        element: editorContainer,
        extensions: [
            TipTap.StarterKit,
            TipTap.Link.configure({
                openOnClick: false,
                HTMLAttributes: {
                    class: 'text-primary text-decoration-underline'
                }
            }),
            TipTap.Image.configure({
                HTMLAttributes: {
                    class: 'img-fluid'
                }
            })
        ],
        content: content.innerHTML,
        editorProps: {
            attributes: {
                class: 'prose prose-sm sm:prose lg:prose-lg xl:prose-2xl mx-auto focus:outline-none',
            }
        }
    });
    
    // Create Bootstrap toolbar
    const toolbar = new TipTap.BootstrapTipTapToolbar(editor, wrapper);
    
    // Show save and cancel buttons
    const saveButton = document.getElementById('savePageButton');
    const cancelButton = document.getElementById('cancelPageButton');
    const editButton = document.getElementById('editPageButton');
    
    if (saveButton) saveButton.classList.remove('d-none');
    if (cancelButton) cancelButton.classList.remove('d-none');
    
    // Set up save handler
    const handleSave = function() {
        // TODO: Implement save to backend
        const htmlContent = editor.getHTML();
        content.innerHTML = htmlContent;
        content.style.display = 'block';
        wrapper.remove();
        
        // Hide save/cancel buttons, show edit button
        if (saveButton) saveButton.classList.add('d-none');
        if (cancelButton) cancelButton.classList.add('d-none');
        if (editButton) {
            editButton.classList.remove('d-none');
            editButton.disabled = false;
        }
    };
    
    // Set up cancel handler
    const handleCancel = function() {
        content.style.display = 'block';
        wrapper.remove();
        editor.destroy();
        
        // Hide save/cancel buttons, show edit button
        if (saveButton) saveButton.classList.add('d-none');
        if (cancelButton) cancelButton.classList.add('d-none');
        if (editButton) {
            editButton.classList.remove('d-none');
            editButton.disabled = false;
        }
    };
    
    // Attach event listeners
    if (saveButton) saveButton.addEventListener('click', handleSave);
    if (cancelButton) cancelButton.addEventListener('click', handleCancel);
    
    return editor;
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
        editButton.disabled = true;
        
        try {
            await window.initPageEditor();
            editButton.classList.add('d-none');
        } catch (error) {
            editButton.disabled = false;
        }
    });
}