const modalContent = document.querySelector('.modal-content');
const modalTitle = document.getElementById('modalTitle');
const modalBody = document.getElementById('modalBody');
const modalFooter = document.getElementById('modalFooter');

// Get dynamic data from sessionStorage (set by createLanguageVersion in src/index.js)
const contentPath = sessionStorage.getItem('newLangPath') || '';
const targetLang = sessionStorage.getItem('newLangCode') || '';
const isFallback = contentPath !== '' && targetLang !== '';

// Static config from data attributes (cacheable)
const defaultLang = modalContent.dataset.defaultLang || 'en';
const hasAnthropic = modalContent.dataset.hasAnthropic === '1';
const translateUrl = modalContent.dataset.translateUrl;
const languagesUrl = modalContent.dataset.languagesUrl;
const filetreeUrl = modalContent.dataset.filetreeUrl;
const srcUrl = modalContent.dataset.srcUrl?.replace(/\/+$/, '');
const sourceUrl = modalContent.dataset.sourceUrl?.replace(/\/+$/, '');

// State
let currentPath = '';
let selectedItem = null;

// Encode path for URL (convert / to %2F)
function encodePath(path) {
  return path.split('/').map(encodeURIComponent).join('%2F');
}

// Get directory path from content path
function getDirPath(path) {
  return path.replace(/\/?(README|[^/]+)$/, '');
}

// Clear sessionStorage for new language creation
function clearNewLangSession() {
  sessionStorage.removeItem('newLangPath');
  sessionStorage.removeItem('newLangCode');
  sessionStorage.removeItem('newLangDir');
}

// Create language version and navigate to edit
async function createAndNavigate(path, lang, content = '') {
  const name = path.split('/').pop();
  const type = name === 'README' ? 'file' : 'sidecard';
  const dirPath = getDirPath(path);

  const encodedPath = '/' + (path ? encodePath(path) : '_');
  try {
    const response = await fetch(`${srcUrl}${encodedPath}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ path, type, language: lang, target: 'file', content })
    });
    const data = await response.json();
    if (data.success) {
      // Clear session data
      clearNewLangSession();
      // Set editlanguage cookie and navigate with edit mode
      document.cookie = `editlanguage=${lang}; path=/manager/web; SameSite=Lax`;
      // Close modal first
      const modalEl = document.querySelector('#universalmodal');
      const modal = bootstrap.Modal.getInstance(modalEl);
      if (modal) modal.hide();
      // Navigate to page
      window.location.href = '/' + dirPath + '?edit=1';
    } else {
      alert(data.error || 'Failed to create language version');
    }
  } catch (err) {
    alert('Error creating language version: ' + err.message);
  }
}

// Fetch source content for a language using the source endpoint
async function fetchSourceContent(path, lang) {
  // path is like "documentation/README" - we need the directory part for the source endpoint
  const docpath = getDirPath(path) || '/';

  // Source endpoint returns the page content for a given path and language
  // URL: /manager/web/source/documentation?language=en
  const url = `${sourceUrl}/${docpath}?language=${encodeURIComponent(lang)}`;

  try {
    const response = await fetch(url, {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin'
    });
    const data = await response.json();

    if (data.success && data.content) {
      // content.main contains the markdown with frontmatter
      const main = data.content.main;
      if (main) {
        // Reconstruct the full markdown with title
        let markdown = '';
        if (main.frontmatter) {
          markdown += '---\n' + main.frontmatter + '\n---\n\n';
        }
        if (main.title) {
          markdown += '# ' + main.title + '\n\n';
        }
        if (main.content) {
          markdown += main.content;
        }
        return markdown;
      }
    }
    console.error('Source content not found:', data);
    return '';
  } catch (err) {
    console.error('Failed to fetch source content:', err);
    return '';
  }
}

if (isFallback) {
  // Fallback/translation mode
  modalTitle.textContent = `No ${targetLang.toUpperCase()} translation found`;
  modalBody.innerHTML = `
    <p>This page doesn't have a ${targetLang.toUpperCase()} version yet. How would you like to proceed?</p>
    <div class="d-grid gap-2">
      <button type="button" class="btn btn-outline-secondary w-100 mb-2" id="fallbackEmpty">Start with empty content</button>
      <button type="button" class="btn btn-primary w-100 mb-2" id="fallbackCopy">Copy content from ${defaultLang.toUpperCase()} version</button>
      ${hasAnthropic ? `<button type="button" class="btn btn-success w-100 mb-2" id="fallbackTranslate">Translate from ${defaultLang.toUpperCase()} to ${targetLang.toUpperCase()}</button>` : ''}
    </div>
    <div id="translationProgress" class="mt-3 d-none">
      <div class="d-flex align-items-center">
        <div class="spinner-border spinner-border-sm me-2" role="status"></div>
        <span>Translating content...</span>
      </div>
    </div>
  `;

  // Setup fallback button handlers
  document.getElementById('fallbackEmpty')?.addEventListener('click', () => {
    createAndNavigate(contentPath, targetLang, '');
  });

  document.getElementById('fallbackCopy')?.addEventListener('click', async () => {
    const sourceContent = await fetchSourceContent(contentPath, defaultLang);
    createAndNavigate(contentPath, targetLang, sourceContent);
  });

  document.getElementById('fallbackTranslate')?.addEventListener('click', async () => {
    const progressEl = document.getElementById('translationProgress');
    progressEl?.classList.remove('d-none');

    try {
      // Fetch source content
      const sourceContent = await fetchSourceContent(contentPath, defaultLang);
      if (!sourceContent) {
        alert('Could not fetch source content for translation');
        progressEl?.classList.add('d-none');
        return;
      }

      // Call translation API
      const response = await fetch(translateUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          markdown: sourceContent,
          target_language: targetLang
        })
      });
      const data = await response.json();

      if (data.success && data.translated) {
        createAndNavigate(contentPath, targetLang, data.translated);
      } else {
        alert(data.error || 'Translation failed');
        progressEl?.classList.add('d-none');
      }
    } catch (err) {
      alert('Translation error: ' + err.message);
      progressEl?.classList.add('d-none');
    }
  });
} else {
  // New content mode with file tree - clear any stale session data
  clearNewLangSession();
  modalTitle.textContent = 'Add new content';
  modalBody.innerHTML = `
    <div class="row">
      <div class="col-12">
        <!-- Breadcrumb navigation -->
        <nav aria-label="breadcrumb" class="mb-2">
          <ol class="breadcrumb mb-0" id="pathBreadcrumb">
            <li class="breadcrumb-item"><a href="#" data-path="">src/public</a></li>
          </ol>
        </nav>

        <!-- Toolbar -->
        <div class="btn-toolbar mb-2" role="toolbar">
          <div class="btn-group btn-group-sm me-2">
            <button type="button" class="btn btn-outline-primary" id="newFolderBtn" title="New folder">
              <svg width="16" height="16" fill="currentColor" class="bi"><use href="#folder-plus"/></svg>
            </button>
            <button type="button" class="btn btn-outline-primary" id="newFileBtn" title="New content">
              <svg width="16" height="16" fill="currentColor" class="bi"><use href="#file-earmark-plus"/></svg>
            </button>
            <button type="button" class="btn btn-outline-secondary" id="newSidecardBtn" title="Add side content" disabled>
              <svg width="16" height="16" fill="currentColor" class="bi"><use href="#file-earmark-richtext"/></svg>
            </button>
          </div>
          <div class="btn-group btn-group-sm">
            <button type="button" class="btn btn-outline-secondary" id="renameBtn" title="Rename" disabled>
              <svg width="16" height="16" fill="currentColor" class="bi"><use href="#pencil"/></svg>
            </button>
            <button type="button" class="btn btn-outline-danger" id="deleteBtn" title="Delete" disabled>
              <svg width="16" height="16" fill="currentColor" class="bi"><use href="#trash"/></svg>
            </button>
          </div>
        </div>

        <!-- File tree -->
        <div class="border rounded" style="height: 250px; overflow-y: auto;">
          <div class="list-group list-group-flush" id="fileTree">
            <div class="list-group-item text-muted">Loading...</div>
          </div>
        </div>

        <!-- Selected path display -->
        <div class="mt-2">
          <small class="text-muted">Selected: </small>
          <code id="selectedPath">-</code>
        </div>
      </div>
    </div>

    <!-- New item form (hidden by default) -->
    <div id="newItemForm" class="mt-3 d-none">
      <hr>
      <div class="mb-3" id="newItemNameGroup">
        <label for="newItemName" class="form-label" id="newItemLabel">Name</label>
        <input type="text" class="form-control" id="newItemName" placeholder="my-folder">
      </div>
      <div class="mb-3 d-none" id="sidecardNameGroup">
        <label for="sidecardName" class="form-label">Sidecard name</label>
        <input type="text" class="form-control" id="sidecardName" placeholder="01-intro">
      </div>
      <div class="mb-3 d-none" id="languageSelectGroup">
        <label for="newItemLang" class="form-label">Language</label>
        <select class="form-select" id="newItemLang"></select>
      </div>
      <div class="mb-3 d-none" id="storageTargetGroup">
        <label class="form-label">Storage</label>
        <div class="btn-group w-100" role="group" aria-label="Storage target">
          <input type="radio" class="btn-check" name="storageTarget" id="storageFile" value="file" checked>
          <label class="btn btn-outline-primary" for="storageFile">
            <svg width="16" height="16" fill="currentColor" class="bi me-1"><use href="#file-earmark-text"/></svg>
            File
          </label>
          <input type="radio" class="btn-check" name="storageTarget" id="storageDatabase" value="database">
          <label class="btn btn-outline-primary" for="storageDatabase">
            <svg width="16" height="16" fill="currentColor" class="bi me-1"><use href="#database"/></svg>
            Database
          </label>
        </div>
      </div>
      <div class="d-flex gap-2">
        <button type="button" class="btn btn-primary btn-sm" id="confirmNewItem">Create</button>
        <button type="button" class="btn btn-secondary btn-sm" id="cancelNewItem">Cancel</button>
      </div>
    </div>
  `;

  modalFooter.innerHTML = `
    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
    <button type="button" class="btn btn-primary" id="openSelectedBtn" disabled>Open</button>
  `;

  // Initialize
  loadFileTree('');
  loadLanguages();
  setupEventHandlers();
}

function loadFileTree(path) {
  currentPath = path;
  const fileTree = document.getElementById('fileTree');
  fileTree.innerHTML = '<div class="list-group-item text-muted">Loading...</div>';

  fetch(`${filetreeUrl}?path=${encodeURIComponent(path)}`, {
    headers: { 'Accept': 'application/json' },
    credentials: 'same-origin'
  })
  .then(r => r.json())
  .then(data => {
    if (!data.success) {
      fileTree.innerHTML = `<div class="list-group-item text-danger">${data.error}</div>`;
      return;
    }

    updateBreadcrumb(path);
    renderFileTree(data.items);
  })
  .catch(err => {
    fileTree.innerHTML = `<div class="list-group-item text-danger">Error: ${err.message}</div>`;
  });
}

// Track existing README languages in current folder
let existingReadmeLanguages = [];

function renderFileTree(items) {
  const fileTree = document.getElementById('fileTree');
  const sidecardBtn = document.getElementById('newSidecardBtn');

  // Check which README languages exist
  existingReadmeLanguages = items
    .filter(item => item.name && item.name.match(/^README_[a-z]{2}\.md$/))
    .map(item => item.name.match(/README_([a-z]{2})\.md$/)[1]);

  const hasMainContent = existingReadmeLanguages.length > 0;
  if (sidecardBtn) {
    sidecardBtn.disabled = !hasMainContent;
  }

  if (items.length === 0) {
    fileTree.innerHTML = '<div class="list-group-item text-muted fst-italic">Empty directory</div>';
    return;
  }

  fileTree.innerHTML = items.map(item => {
    const icon = item.type === 'directory' ? 'folder-fill' : 'file-earmark-text';
    const langBadges = item.languages ? item.languages.map(l =>
      `<span class="badge bg-secondary ms-1">${l}</span>`
    ).join('') : '';

    return `
      <a href="#" class="list-group-item list-group-item-action d-flex align-items-center"
         data-path="${item.path}" data-type="${item.type}" data-name="${item.name}">
        <svg width="16" height="16" fill="currentColor" class="bi me-2 ${item.type === 'directory' ? 'text-warning' : 'text-primary'}">
          <use href="#${icon}"/>
        </svg>
        <span class="flex-grow-1">${item.name}</span>
        ${langBadges}
        ${item.type === 'directory' && item.hasChildren ? '<svg width="16" height="16" fill="currentColor" class="bi text-muted"><use href="#chevron-right"/></svg>' : ''}
      </a>
    `;
  }).join('');

  // Add click handlers
  fileTree.querySelectorAll('.list-group-item').forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      const path = el.dataset.path;
      const type = el.dataset.type;

      if (type === 'directory') {
        // Double-click to enter directory
        if (selectedItem === el) {
          loadFileTree(path);
          selectedItem = null;
          return;
        }
      }

      // Select item
      fileTree.querySelectorAll('.list-group-item').forEach(i => i.classList.remove('active'));
      el.classList.add('active');
      selectedItem = el;

      document.getElementById('selectedPath').textContent = path;
      document.getElementById('renameBtn').disabled = false;
      document.getElementById('deleteBtn').disabled = false;
      document.getElementById('openSelectedBtn').disabled = type !== 'directory';
    });

    // Double-click to enter directory
    el.addEventListener('dblclick', (e) => {
      e.preventDefault();
      if (el.dataset.type === 'directory') {
        loadFileTree(el.dataset.path);
      }
    });
  });
}

function updateBreadcrumb(path) {
  const breadcrumb = document.getElementById('pathBreadcrumb');
  const parts = path ? path.split('/') : [];

  let html = '<li class="breadcrumb-item"><a href="#" data-path="">src/public</a></li>';
  let accumulated = '';

  parts.forEach((part, i) => {
    accumulated += (accumulated ? '/' : '') + part;
    const isLast = i === parts.length - 1;
    if (isLast) {
      html += `<li class="breadcrumb-item active">${part}</li>`;
    } else {
      html += `<li class="breadcrumb-item"><a href="#" data-path="${accumulated}">${part}</a></li>`;
    }
  });

  breadcrumb.innerHTML = html;

  // Add click handlers
  breadcrumb.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      loadFileTree(a.dataset.path);
    });
  });
}

// Store all languages
let allLanguages = [];

function loadLanguages() {
  fetch(languagesUrl, { headers: { 'Accept': 'application/json' }, credentials: 'same-origin' })
    .then(r => r.json())
    .then(data => {
      if (data.languages) {
        allLanguages = data.languages;
        updateLanguageSelect();
      }
    });
}

function updateLanguageSelect(excludeExisting = false) {
  const select = document.getElementById('newItemLang');
  if (!select) return;

  const langs = excludeExisting
    ? allLanguages.filter(l => !existingReadmeLanguages.includes(l.code))
    : allLanguages;

  select.innerHTML = langs.map(l =>
    `<option value="${l.code}"${l.code === defaultLang ? ' selected' : ''}>${l.title} (${l.code})</option>`
  ).join('');

  // Disable new content button if all languages exist
  const newFileBtn = document.getElementById('newFileBtn');
  if (newFileBtn && excludeExisting) {
    newFileBtn.disabled = langs.length === 0;
  }
}

function setupEventHandlers() {
  let newItemType = 'directory';

  // New folder button
  document.getElementById('newFolderBtn')?.addEventListener('click', () => {
    newItemType = 'directory';
    document.getElementById('newItemLabel').textContent = 'Folder name';
    document.getElementById('newItemNameGroup').classList.remove('d-none');
    document.getElementById('sidecardNameGroup')?.classList.add('d-none');
    document.getElementById('languageSelectGroup').classList.add('d-none');
    document.getElementById('storageTargetGroup').classList.add('d-none');
    document.getElementById('newItemForm').classList.remove('d-none');
    document.getElementById('newItemName').focus();
  });

  // New content button (README_xx.md in current folder)
  document.getElementById('newFileBtn')?.addEventListener('click', () => {
    newItemType = 'file';
    document.getElementById('newItemNameGroup').classList.add('d-none');
    document.getElementById('sidecardNameGroup')?.classList.add('d-none');
    document.getElementById('languageSelectGroup').classList.remove('d-none');
    document.getElementById('storageTargetGroup').classList.remove('d-none');
    document.getElementById('newItemForm').classList.remove('d-none');
    updateLanguageSelect(true);  // Only show missing languages
    document.getElementById('newItemLang')?.focus();
  });

  // New sidecard button (uses same storage as main content)
  document.getElementById('newSidecardBtn')?.addEventListener('click', () => {
    newItemType = 'sidecard';
    document.getElementById('newItemNameGroup').classList.add('d-none');
    document.getElementById('sidecardNameGroup')?.classList.remove('d-none');
    document.getElementById('languageSelectGroup').classList.remove('d-none');
    document.getElementById('storageTargetGroup').classList.add('d-none');
    document.getElementById('newItemForm').classList.remove('d-none');
    updateLanguageSelect(false);  // Show all languages for sidecards
    document.getElementById('sidecardName').focus();
  });

  // Cancel new item
  document.getElementById('cancelNewItem')?.addEventListener('click', () => {
    document.getElementById('newItemForm').classList.add('d-none');
    document.getElementById('newItemName').value = '';
    document.getElementById('sidecardName').value = '';
  });

  // Confirm new item
  document.getElementById('confirmNewItem')?.addEventListener('click', () => {
    let path, name;

    if (newItemType === 'sidecard') {
      name = document.getElementById('sidecardName').value.trim();
      if (!name) {
        alert('Please enter a sidecard name');
        return;
      }
      // Strip any existing suffix patterns
      name = name.replace(/(_[a-z]{2})?\.md$/, '').replace(/_[a-z]{2}$/, '');
      path = currentPath ? `${currentPath}/${name}` : name;
    } else if (newItemType === 'file') {
      // New content uses current path directly (creates README_xx.md)
      path = currentPath || '';
    } else {
      // Directory needs a name
      name = document.getElementById('newItemName').value.trim();
      if (!name) {
        alert('Please enter a name');
        return;
      }
      path = currentPath ? `${currentPath}/${name}` : name;
    }

    const language = (newItemType === 'file' || newItemType === 'sidecard') ?
      document.getElementById('newItemLang').value : null;
    // Sidecard uses 'file' storage (same as main content), new content offers choice
    const storageTarget = newItemType === 'file' ?
      document.querySelector('input[name="storageTarget"]:checked')?.value || 'file' :
      newItemType === 'sidecard' ? 'file' : null;

    fetch(filetreeUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ path, type: newItemType, language, target: storageTarget })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        document.getElementById('newItemForm').classList.add('d-none');
        document.getElementById('newItemName').value = '';
        document.getElementById('sidecardName').value = '';
        loadFileTree(currentPath);

        // If content was created, navigate to it
        if ((newItemType === 'file' || newItemType === 'sidecard') && data.path) {
          const urlPath = data.path.replace(/README_[a-z]{2}\.md$/, '').replace(/_[a-z]{2}\.md$/, '');
          setTimeout(() => {
            window.location.href = '/' + urlPath;
          }, 500);
        }
      } else {
        alert(data.error || 'Failed to create');
      }
    });
  });

  // Rename button
  document.getElementById('renameBtn')?.addEventListener('click', () => {
    if (!selectedItem) return;

    const oldPath = selectedItem.dataset.path;
    const oldName = selectedItem.dataset.name;
    const newName = prompt('Enter new name:', oldName);

    if (!newName || newName === oldName) return;

    const pathParts = oldPath.split('/');
    pathParts[pathParts.length - 1] = newName;
    const newPath = pathParts.join('/');

    fetch(filetreeUrl.replace('/filetree', '/filetree/rename'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ oldPath, newPath })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        loadFileTree(currentPath);
      } else {
        alert(data.error || 'Failed to rename');
      }
    });
  });

  // Delete button
  document.getElementById('deleteBtn')?.addEventListener('click', () => {
    if (!selectedItem) return;

    const path = selectedItem.dataset.path;
    const type = selectedItem.dataset.type;

    if (!confirm(`Delete ${type} "${path}"?`)) return;

    fetch(filetreeUrl.replace('/filetree', '/filetree/delete'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ path })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        selectedItem = null;
        document.getElementById('selectedPath').textContent = '-';
        document.getElementById('renameBtn').disabled = true;
        document.getElementById('deleteBtn').disabled = true;
        loadFileTree(currentPath);
      } else {
        alert(data.error || 'Failed to delete');
      }
    });
  });

  // Open selected button
  document.getElementById('openSelectedBtn')?.addEventListener('click', () => {
    if (!selectedItem) return;
    const path = selectedItem.dataset.path;
    window.location.href = '/' + path + '/';
  });
}
