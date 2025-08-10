import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import Image from '@tiptap/extension-image'

// Bootstrap-based TipTap toolbar
class BootstrapTipTapToolbar {
  constructor(editor, container) {
    this.editor = editor;
    this.container = container;
    this.createToolbar();
    this.bindEvents();
  }

  createToolbar() {
    const toolbar = document.createElement('div');
    toolbar.className = 'btn-toolbar mb-3 p-2 border-bottom bg-light';
    toolbar.innerHTML = `
      <div class="btn-group me-2" role="group">
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="bold" title="Bold">
          <i class="bi bi-type-bold"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="italic" title="Italic">
          <i class="bi bi-type-italic"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="underline" title="Underline">
          <i class="bi bi-type-underline"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="strike" title="Strikethrough">
          <i class="bi bi-type-strikethrough"></i>
        </button>
      </div>
      
      <div class="btn-group me-2" role="group">
        <select class="form-select form-select-sm" data-action="heading" style="width: 120px;">
          <option value="">Normal</option>
          <option value="1">Heading 1</option>
          <option value="2">Heading 2</option>
          <option value="3">Heading 3</option>
        </select>
      </div>
      
      <div class="btn-group me-2" role="group">
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="bulletList" title="Bullet List">
          <i class="bi bi-list-ul"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="orderedList" title="Numbered List">
          <i class="bi bi-list-ol"></i>
        </button>
      </div>
      
      <div class="btn-group me-2" role="group">
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="blockquote" title="Quote">
          <i class="bi bi-quote"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="codeBlock" title="Code Block">
          <i class="bi bi-code"></i>
        </button>
      </div>
      
      <div class="btn-group me-2" role="group">
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="link" title="Link">
          <i class="bi bi-link-45deg"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="image" title="Image">
          <i class="bi bi-image"></i>
        </button>
      </div>
      
      <div class="btn-group ms-auto" role="group">
        <button type="button" class="btn btn-sm btn-success" data-action="save" title="Save">
          <i class="bi bi-check-lg"></i> Save
        </button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="cancel" title="Cancel">
          <i class="bi bi-x-lg"></i> Cancel
        </button>
      </div>
    `;
    
    this.container.insertBefore(toolbar, this.container.firstChild);
    this.toolbar = toolbar;
  }

  bindEvents() {
    this.toolbar.addEventListener('click', (e) => {
      const button = e.target.closest('[data-action]');
      if (!button) return;
      
      const action = button.dataset.action;
      this.handleAction(action, button);
    });

    this.toolbar.addEventListener('change', (e) => {
      if (e.target.dataset.action === 'heading') {
        const level = e.target.value;
        if (level) {
          this.editor.chain().focus().toggleHeading({ level: parseInt(level) }).run();
        } else {
          this.editor.chain().focus().setParagraph().run();
        }
      }
    });

    // Update button states on selection change
    this.editor.on('selectionUpdate', () => {
      this.updateButtonStates();
    });
  }

  handleAction(action, button) {
    const editor = this.editor;
    
    switch(action) {
      case 'bold':
        editor.chain().focus().toggleBold().run();
        break;
      case 'italic':
        editor.chain().focus().toggleItalic().run();
        break;
      case 'underline':
        editor.chain().focus().toggleUnderline().run();
        break;
      case 'strike':
        editor.chain().focus().toggleStrike().run();
        break;
      case 'bulletList':
        editor.chain().focus().toggleBulletList().run();
        break;
      case 'orderedList':
        editor.chain().focus().toggleOrderedList().run();
        break;
      case 'blockquote':
        editor.chain().focus().toggleBlockquote().run();
        break;
      case 'codeBlock':
        editor.chain().focus().toggleCodeBlock().run();
        break;
      case 'link':
        const url = prompt('Enter URL:');
        if (url) {
          editor.chain().focus().setLink({ href: url }).run();
        }
        break;
      case 'image':
        const src = prompt('Enter image URL:');
        if (src) {
          editor.chain().focus().setImage({ src }).run();
        }
        break;
      case 'save':
        this.onSave && this.onSave(editor.getHTML());
        break;
      case 'cancel':
        this.onCancel && this.onCancel();
        break;
    }
  }

  updateButtonStates() {
    const editor = this.editor;
    
    // Update button active states
    this.toolbar.querySelector('[data-action="bold"]').classList.toggle('active', editor.isActive('bold'));
    this.toolbar.querySelector('[data-action="italic"]').classList.toggle('active', editor.isActive('italic'));
    this.toolbar.querySelector('[data-action="underline"]').classList.toggle('active', editor.isActive('underline'));
    this.toolbar.querySelector('[data-action="strike"]').classList.toggle('active', editor.isActive('strike'));
    this.toolbar.querySelector('[data-action="bulletList"]').classList.toggle('active', editor.isActive('bulletList'));
    this.toolbar.querySelector('[data-action="orderedList"]').classList.toggle('active', editor.isActive('orderedList'));
    this.toolbar.querySelector('[data-action="blockquote"]').classList.toggle('active', editor.isActive('blockquote'));
    this.toolbar.querySelector('[data-action="codeBlock"]').classList.toggle('active', editor.isActive('codeBlock'));

    // Update heading dropdown
    const headingSelect = this.toolbar.querySelector('[data-action="heading"]');
    for (let i = 1; i <= 6; i++) {
      if (editor.isActive('heading', { level: i })) {
        headingSelect.value = i.toString();
        return;
      }
    }
    headingSelect.value = '';
  }
}

// Export TipTap globally for dynamic loading
window.TipTap = {
  Editor,
  StarterKit,
  Link,
  Image,
  BootstrapTipTapToolbar
};