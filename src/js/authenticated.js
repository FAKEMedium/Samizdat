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

// Simple toolbar setup for contenteditable
window.setupSimpleToolbar = async function() {
    try {
        // Check if toolbar already exists and is visible
        let toolbarElement = document.getElementById('simpleToolbar');
        if (toolbarElement) {
            toolbarElement.style.display = 'block';
            console.log('Simple toolbar already exists, showing it');
            return;
        }
        
        const theContent = document.querySelector('#thecontent');
        const toolbarUrl = theContent?.dataset.toolbar || '/web/editor/toolbar/';
        const response = await fetch(toolbarUrl, {
            method: 'GET',
            headers: { 'Accept': 'text/html' }
        });
        
        if (!response.ok) {
            console.error(`Failed to load toolbar: ${response.status}`);
            return;
        }
        
        const toolbarHTML = await response.text();
        const tempContainer = document.createElement('div');
        tempContainer.innerHTML = toolbarHTML;
        
        // Add simple toolbar to page
        toolbarElement = tempContainer.querySelector('#simpleToolbar');
        if (toolbarElement) {
            document.body.appendChild(toolbarElement);
            
            // Move toolbar SVG symbols to main document defs (no duplicates)
            const mainDefs = document.querySelector('#topdefs');
            const toolbarSVG = tempContainer.querySelector('svg');
            const toolbarDefs = tempContainer.querySelector('#toolbardefs');
            
            if (mainDefs && toolbarDefs) {
                // Move unique symbols from toolbar to main defs
                const toolbarSymbols = toolbarDefs.querySelectorAll('symbol');
                let movedCount = 0;
                toolbarSymbols.forEach(symbol => {
                    const symbolId = symbol.id;
                    if (symbolId && !mainDefs.querySelector(`#${symbolId}`)) {
                        mainDefs.appendChild(symbol.cloneNode(true));
                        movedCount++;
                    }
                });
                console.log(`Moved ${movedCount} unique SVG symbols to main defs`);
            }
            
            // Setup toolbar button handlers
            toolbarElement.addEventListener('click', (e) => {
                const button = e.target.closest('[data-cmd]');
                if (button) {
                    handleToolbarCommand(button);
                }
            });
            
            // Setup dropdown handler
            toolbarElement.addEventListener('change', (e) => {
                if (e.target.dataset.cmd) {
                    handleToolbarCommand(e.target);
                }
            });
            
            // Setup close button
            const closeBtn = toolbarElement.querySelector('#closeToolbar');
            if (closeBtn) {
                closeBtn.addEventListener('click', () => {
                    toolbarElement.style.display = 'none';
                });
            }
            
            // Make toolbar draggable
            makeDraggable(toolbarElement, toolbarElement.querySelector('#toolbarHandle'));
            
            window.simpleToolbar = { element: toolbarElement };
            console.log('Simple toolbar loaded and shown');
        }
    } catch (error) {
        console.error('Failed to setup simple toolbar:', error);
    }
};

// Make element draggable by handle
function makeDraggable(element, handle) {
    let isDragging = false;
    let currentX;
    let currentY;
    let initialX;
    let initialY;
    let xOffset = 0;
    let yOffset = 0;

    handle.addEventListener('mousedown', (e) => {
        initialX = e.clientX - xOffset;
        initialY = e.clientY - yOffset;
        
        if (e.target === handle || handle.contains(e.target)) {
            // Don't start drag if clicking the close button
            if (!e.target.classList.contains('btn-close')) {
                isDragging = true;
                element.style.userSelect = 'none';
            }
        }
    });

    document.addEventListener('mousemove', (e) => {
        if (isDragging) {
            e.preventDefault();
            currentX = e.clientX - initialX;
            currentY = e.clientY - initialY;
            xOffset = currentX;
            yOffset = currentY;
            
            element.style.transform = `translate(${currentX}px, ${currentY}px)`;
        }
    });

    document.addEventListener('mouseup', () => {
        if (isDragging) {
            initialX = currentX;
            initialY = currentY;
            isDragging = false;
            element.style.userSelect = '';
        }
    });
}

// Handle toolbar commands using document.execCommand
function handleToolbarCommand(element) {
    const cmd = element.dataset.cmd;
    const value = element.dataset.value || element.value || null;
    
    // Focus the editor first
    window.currentEditor?.element.focus();
    
    switch (cmd) {
        case 'bold':
        case 'italic':
        case 'underline':
        case 'insertUnorderedList':
        case 'insertOrderedList':
            document.execCommand(cmd, false, null);
            break;
        case 'formatBlock':
            if (value) {
                document.execCommand('formatBlock', false, value);
                element.value = ''; // Reset dropdown
            }
            break;
        case 'createLink':
            const url = prompt('Enter URL:');
            if (url) {
                document.execCommand('createLink', false, url);
            }
            break;
        case 'insertHTML':
            if (value) {
                document.execCommand('insertHTML', false, value);
            }
            break;
        default:
            console.log('Unknown command:', cmd);
    }
    
    // Keep focus on editor
    window.currentEditor?.element.focus();
}

// Initialize page editor
window.initPageEditor = async function() {
    console.log('Starting editor initialization...');
    
    let editor, content, editorContainer;
    
    try {
        console.log('Setting up simple contenteditable editor...');
        
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
            
            // Enable editing mode and setup toolbar
            if (window.currentEditor) {
                window.currentEditor.setEditable(true);
                window.currentEditor.element.focus();
                
                // Load and setup simple toolbar
                window.setupSimpleToolbar();
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
                
                // Hide toolbar
                const toolbarElement = document.getElementById('simpleToolbar');
                if (toolbarElement) {
                    toolbarElement.style.display = 'none';
                    console.log('Toolbar hidden');
                }
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
                
                // Hide toolbar
                const toolbarElement = document.getElementById('simpleToolbar');
                if (toolbarElement) {
                    toolbarElement.style.display = 'none';
                    console.log('Toolbar hidden');
                }
            }
        });
    }
}