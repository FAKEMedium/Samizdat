let allPages = {};
let searchTimeout;

async function fetchPages(searchterm = '') {
  const params = searchterm ? `?searchterm=${encodeURIComponent(searchterm)}` : '';
  const request = {
    method: 'GET',
    headers: {Accept: 'application/json'}
  };
  
  try {
    const response = await fetch(window.location + params, request);
    if (response.ok) {
      const data = await response.json();
      return data.pages || {};
    }
  } catch (e) {
    console.error('Error fetching pages:', e);
  }
  return {};
}

function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  else if (bytes < 1048576) return Math.round(bytes / 1024) + ' KB';
  else return Math.round(bytes / 1048576) + ' MB';
}

function buildTree(pages) {
  const tree = {};
  
  // Build hierarchical structure
  Object.keys(pages).forEach(path => {
    const parts = path.split('/').filter(p => p);
    let current = tree;
    
    parts.forEach((part, index) => {
      if (!current[part]) {
        current[part] = {
          name: part,
          path: parts.slice(0, index + 1).join('/'),
          children: {},
          isFile: index === parts.length - 1,
          translations: index === parts.length - 1 ? pages[path] : {}
        };
      }
      if (index < parts.length - 1) {
        current = current[part].children;
      }
    });
  });
  
  return tree;
}

function renderTree(tree, level = 0) {
  let html = '';
  
  Object.keys(tree).sort().forEach(key => {
    const node = tree[key];
    const hasChildren = Object.keys(node.children).length > 0;
    const nodeId = `node-${node.path.replace(/[^a-zA-Z0-9]/g, '-')}`;
    
    html += '<li>';
    
    if (hasChildren) {
      const isExpanded = level === 0 ? '' : 'collapsed';
      const showClass = level === 0 ? 'show' : '';
      const ariaExpanded = level === 0 ? 'true' : 'false';
      
      html += `<button class="tree-toggle ${isExpanded}" type="button" data-bs-toggle="collapse" data-bs-target="#${nodeId}" aria-expanded="${ariaExpanded}">
        <svg class="tree-icon" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
        </svg>
        <span>${node.name}/</span>
      </button>`;
      html += `<ul class="tree-list collapse ${showClass}" id="${nodeId}">`;
      html += renderTree(node.children, level + 1);
      html += '</ul>';
    } else {
      const url = '/' + node.path.replace(/README\.md$/, '');
      
      // Build translation info for title attribute
      let translationInfo = [];
      if (node.translations && Object.keys(node.translations).length > 0) {
        Object.entries(node.translations).forEach(([lang, size]) => {
          translationInfo.push(`${lang}: ${formatFileSize(size)}`);
        });
      }
      const titleAttr = translationInfo.length > 0 ? `title="${translationInfo.join(', ')}"` : '';
      
      // Show language indicators
      const langBadges = Object.keys(node.translations || {}).map(lang => 
        `<small class="text-muted ms-1">[${lang}]</small>`
      ).join('');
      
      html += `<a href="${url}" class="text-decoration-none" ${titleAttr}>
        <svg class="tree-icon" style="width: 0.75em; height: 0.75em;" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h8a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"/>
        </svg>
        ${node.name}${langBadges}
      </a>`;
    }
    
    html += '</li>';
  });
  
  return html;
}

function displayPages(pages) {
  const pagesList = document.getElementById('pagesList');
  const noResults = document.getElementById('noResults');
  
  if (Object.keys(pages).length === 0) {
    pagesList.innerHTML = '';
    noResults.classList.remove('d-none');
  } else {
    noResults.classList.add('d-none');
    const tree = buildTree(pages);
    pagesList.innerHTML = renderTree(tree);
    
    // Add collapse toggle behavior
    document.querySelectorAll('.tree-toggle').forEach(button => {
      button.addEventListener('click', function() {
        this.classList.toggle('expanded');
        this.classList.toggle('collapsed');
      });
    });
  }
}

async function loadPages() {
  allPages = await fetchPages();
  displayPages(allPages);
}

// Search functionality
document.getElementById('searchterm').addEventListener('input', function(e) {
  clearTimeout(searchTimeout);
  const searchTerm = e.target.value.trim();
  
  searchTimeout = setTimeout(async () => {
    if (searchTerm) {
      const filteredPages = await fetchPages(searchTerm);
      displayPages(filteredPages);
    } else {
      displayPages(allPages);
    }
  }, 300);
});

// Initialize
loadPages();