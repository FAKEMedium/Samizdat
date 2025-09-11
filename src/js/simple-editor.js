// Simple contenteditable editor - lightweight alternative to TipTap
// This file contains only the simple editor functionality without TipTap

// Simple editor creation function for contenteditable elements
window.createSimpleEditor = function(content, index) {
    // Store original content for cancel
    const originalHTML = content.innerHTML;
    content.dataset.originalContent = originalHTML;
    
    // Simple editor object for compatibility
    const editor = {
        element: content,
        index: index,
        getHTML: () => content.innerHTML,
        setContent: (html) => content.innerHTML = html,
        setEditable: (editable) => {
            content.contentEditable = editable;
            if (editable) {
                // Convert picture elements to simple img tags for editing
                editor.convertPicturesToImg(content);
                
                // Set up text-only mode for heading elements
                if (content.tagName && content.tagName.match(/^H[1-6]$/i)) {
                    editor.setupTextOnlyMode(content);
                }
                
                content.style.border = '2px solid #007bff';
                content.style.padding = '10px';
                content.style.cursor = 'text';
            } else {
                content.style.border = '';
                content.style.padding = '';
                content.style.cursor = '';
            }
        },
        convertPicturesToImg: (container) => {
            const pictures = container.querySelectorAll('picture');
            pictures.forEach(picture => {
                const img = picture.querySelector('img');
                if (img) {
                    // Clone the img and insert it before the picture element
                    const newImg = img.cloneNode(true);
                    picture.parentNode.insertBefore(newImg, picture);
                    // Remove the picture element
                    picture.remove();
                }
            });
        },
        setupTextOnlyMode: (element) => {
            // Strip any existing HTML and keep only text content
            element.textContent = element.textContent;
            
            // Prevent paste of formatted content
            element.addEventListener('paste', (e) => {
                e.preventDefault();
                const text = (e.clipboardData || window.clipboardData).getData('text/plain');
                document.execCommand('insertText', false, text);
            });
            
            // Prevent drag/drop of formatted content
            element.addEventListener('drop', (e) => {
                e.preventDefault();
                const text = e.dataTransfer.getData('text/plain');
                if (text) {
                    document.execCommand('insertText', false, text);
                }
            });
            
            // Block formatting keyboard shortcuts
            element.addEventListener('keydown', (e) => {
                // Block Ctrl+B, Ctrl+I, Ctrl+U, etc.
                if (e.ctrlKey || e.metaKey) {
                    const blockedKeys = ['b', 'i', 'u', 'k']; // bold, italic, underline, link
                    if (blockedKeys.includes(e.key.toLowerCase())) {
                        e.preventDefault();
                    }
                }
                
                // Block Enter key to prevent new lines in headings
                if (e.key === 'Enter') {
                    e.preventDefault();
                }
            });
            
            // Clean up any HTML that might get inserted
            element.addEventListener('input', (e) => {
                // If innerHTML differs from textContent, clean it up
                const textOnly = element.textContent;
                if (element.innerHTML !== textOnly) {
                    const selection = window.getSelection();
                    const range = selection.getRangeAt(0);
                    const startOffset = range.startOffset;
                    
                    element.textContent = textOnly;
                    
                    // Restore cursor position
                    if (element.firstChild) {
                        range.setStart(element.firstChild, Math.min(startOffset, textOnly.length));
                        range.collapse(true);
                        selection.removeAllRanges();
                        selection.addRange(range);
                    }
                }
            });
        },
        destroy: () => {
            content.contentEditable = 'false';
            content.style.border = '';
            content.style.padding = '';
            content.style.cursor = '';
        }
    };
    
    // Add click handler to focus this editor and set as current
    content.addEventListener('click', () => {
        if (content.contentEditable === 'true') {
            window.currentEditor = editor;
            console.log(`Switched to editor for element ${index}`);
        }
    });
    
    return editor;
};

// Initialize simple editors for all .editable elements
window.initSimpleEditors = function() {
    console.log('Starting simple editor initialization...');
    
    try {
        const theContent = document.getElementById('thecontent');
        if (!theContent) {
            console.error('thecontent element not found');
            return null;
        }
        
        // Check if #thecontent is editable - if not, don't initialize any editors
        if (!theContent.classList.contains('editable')) {
            console.log('#thecontent is not editable, skipping editor initialization');
            return null;
        }
        
        // #thecontent is editable, so find all .editable elements to make them editable too
        const editableElements = document.querySelectorAll('.editable');
        console.log(`#thecontent is editable, found ${editableElements.length} total .editable elements:`, editableElements);
        
        const editors = [];
        
        // Create editor objects for each editable element
        editableElements.forEach((content, index) => {
            const editor = window.createSimpleEditor(content, index);
            editors.push(editor);
        });
        
        console.log(`${editors.length} simple contenteditable editors initialized`);
        
        // Set up global editor reference (first one by default)
        window.currentEditor = editors[0];
        window.allEditors = editors;
        
        return editors;
    } catch (error) {
        console.error('Error in initSimpleEditors:', error);
        return null;
    }
};