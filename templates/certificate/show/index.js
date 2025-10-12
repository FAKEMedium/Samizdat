// Certificate show page handler
const deleteBtn = document.getElementById('deleteBtn');
const certificateId = window.location.pathname.split('/').pop();

// Handle delete button
deleteBtn.addEventListener('click', async () => {
  if (!confirm('<%== __("Are you sure you want to delete this certificate?") %>')) {
    return;
  }

  const result = await window.authenticatedFetch(`<%== url_for('certificate_index') %>/${certificateId}`, {
    method: 'DELETE'
  });

  if (result && result.success) {
    alert('<%== __("Certificate deleted successfully") %>');
    window.location.href = '<%== url_for('certificate_index') %>';
  } else {
    alert('<%== __("Failed to delete certificate") %>: ' + (result?.error || 'Unknown error'));
  }
});
