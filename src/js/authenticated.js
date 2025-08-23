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
    wrapper.className = 'border rounded';
    content.parentNode.insertBefore(wrapper, content);
    
    // Create editor container
    const editorContainer = document.createElement('div');
    editorContainer.id = 'tiptap-editor';
    editorContainer.className = 'p-3';
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
    
    // Set up save handler
    toolbar.onSave = function(htmlContent) {
        // TODO: Implement save to backend
        content.innerHTML = htmlContent;
        content.style.display = 'block';
        wrapper.remove();
    };
    
    // Set up cancel handler
    toolbar.onCancel = function() {
        content.style.display = 'block';
        wrapper.remove();
        editor.destroy();
    };
    
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
        editButton.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Loading editor...';
        
        try {
            await window.initPageEditor();
            editButton.style.display = 'none';
        } catch (error) {
            editButton.disabled = false;
            editButton.innerHTML = '<%== icon "pencil-square"; %> <span class="d-sm-inline d-none ms-1">Edit</span>';
        }
    });
}