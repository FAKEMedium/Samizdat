// RealtimeRegister contacts list
const contactsTable = document.getElementById('contacts');
const searchButton = document.getElementById('searchButton');
const searchterm = document.getElementById('searchterm');

function loadContacts(search = '') {
  const url = new URL('<%= url_for('rtr_contacts') %>', window.location.origin);
  if (search) url.searchParams.set('search', search);

  fetch(url, {
    headers: { 'Accept': 'application/json' }
  })
  .then(response => response.json())
  .then(data => {
    const tbody = contactsTable.querySelector('tbody');
    tbody.innerHTML = '';

    if (!data.contacts || data.contacts.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center"><%== __('No contacts found') %></td></tr>';
      return;
    }

    data.contacts.forEach(contact => {
      const row = document.createElement('tr');
      const name = `${contact.firstName || ''} ${contact.lastName || ''}`.trim() || 'N/A';
      row.innerHTML = `
        <td><a href="<%= url_for('rtr_contact', handle => '') %>${contact.handle}">${contact.handle}</a></td>
        <td>${name}</td>
        <td>${contact.organization || 'N/A'}</td>
        <td>${contact.email || 'N/A'}</td>
        <td class="text-end">
          <a href="<%= url_for('rtr_contact', handle => '') %>${contact.handle}" class="btn btn-sm btn-primary"><%== __('View') %></a>
        </td>
      `;
      tbody.appendChild(row);
    });
  })
  .catch(error => {
    console.error('Error loading contacts:', error);
    const tbody = contactsTable.querySelector('tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger"><%== __('Error loading contacts') %></td></tr>';
  });
}

searchButton.addEventListener('click', () => loadContacts(searchterm.value));
searchterm.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') loadContacts(searchterm.value);
});

// Load contacts on page load
loadContacts();
