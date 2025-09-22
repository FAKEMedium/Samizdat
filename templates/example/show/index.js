// Load and display example details
const exampleId = window.location.pathname.match(/\/(\d+)$/)[1];

loadExample();

async function loadExample() {
  const data = await window.authenticatedFetch(window.location.pathname, {
    method: 'GET'
  });

  if (data && data.example) {
    displayExample(data.example);
  }
}

function displayExample(example) {
  // Title
  document.getElementById('example-title').textContent = example.title || '';

  // Dates
  let dateText = `<%== __('Created') %>: ${example.created || ''}`;
  if (example.updated && example.updated !== example.created) {
    dateText += ` | <%== __('Updated') %>: ${example.updated}`;
  }
  document.getElementById('example-dates').textContent = dateText;

  // Status
  if (example.status) {
    const statusEl = document.getElementById('example-status');
    statusEl.className = `badge bg-${example.status === 'active' ? 'success' : 'secondary'}`;
    statusEl.textContent = example.status;
  }

  // Description
  if (example.description) {
    document.getElementById('example-description').textContent = example.description;
  } else {
    document.getElementById('example-description').style.display = 'none';
  }

  // Content
  document.getElementById('example-content').innerHTML = example.content || '';

  // Tags
  if (example.tags && example.tags.length > 0) {
    let tagsHtml = '<%== __("Tags") %>: ';
    example.tags.forEach(tag => {
      tagsHtml += `<span class="badge bg-secondary ms-1">${tag}</span>`;
    });
    document.getElementById('example-tags').innerHTML = tagsHtml;
  } else {
    document.getElementById('example-tags').style.display = 'none';
  }

  // Edit link
  document.getElementById('edit-link').href = `<%= url_for('admin_example_edit') %>/${example.id}/edit`;
}