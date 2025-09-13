// Account settings form handler with AJAX/JSON pattern

const profileForm = document.getElementById('profileForm');
const saveStatus = document.getElementById('saveStatus');
const currentImagePreview = document.getElementById('currentImagePreview');

// Load current profile data
async function loadProfile() {
    try {
        const response = await fetch(window.location.pathname, {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
        });
        
        const result = await response.json();
        if (result.success && result.profile) {
            populateForm(result.profile);
        }
    } catch (error) {
        console.error('Failed to load profile:', error);
    }
}

// Populate form with profile data
function populateForm(profile) {
    // Basic information
    if (profile.basic) {
        document.getElementById('displayname').value = profile.basic.displayname || '';
        document.getElementById('email').value = profile.basic.email || '';
    }
    
    // Contacts
    if (profile.contacts) {
        document.getElementById('phone').value = profile.contacts.phone || '';
        document.getElementById('website').value = profile.contacts.website || '';
        document.getElementById('bio').value = profile.contacts.bio || '';
    }
    
    // Presentations
    if (profile.presentations) {
        document.getElementById('theme').value = profile.presentations.theme || 'default';
        document.getElementById('language').value = profile.presentations.language || 'en';
    }
    
    // Show current profile image if exists
    if (profile.images && profile.images.avatar) {
        showCurrentImage(profile.images.avatar);
    }
}

// Show current profile image
function showCurrentImage(imagePath) {
    currentImagePreview.innerHTML = `
        <div class="current-image">
            <p class="mb-2"><strong>Current Profile Image:</strong></p>
            <img src="${imagePath}" alt="Profile Image" class="img-thumbnail" style="max-width: 150px;">
        </div>
    `;
}

// Handle form submission
profileForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = new FormData(profileForm);
    const profileData = {
        basic: {},
        contacts: {},
        presentations: {},
        images: {}
    };
    
    // Parse form data into sections
    for (let [name, value] of formData.entries()) {
        if (name.includes('[')) {
            const match = name.match(/^(\w+)\[(\w+)\]$/);
            if (match) {
                const [, section, key] = match;
                profileData[section][key] = value;
            }
        }
    }
    
    // Handle profile image upload
    const profileImageFile = document.getElementById('profileImage').files[0];
    if (profileImageFile) {
        try {
            const imageResult = await uploadProfileImage(profileImageFile);
            if (imageResult.success) {
                profileData.images.avatar = imageResult.imagePath;
            } else {
                showStatus('error', imageResult.error);
                return;
            }
        } catch (error) {
            showStatus('error', 'Failed to upload image');
            return;
        }
    }
    
    // Save profile data
    try {
        const response = await fetch(window.location.pathname, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(profileData)
        });
        
        const result = await response.json();
        if (result.success) {
            showStatus('success', result.message || 'Profile updated successfully');
            // Reload to show updated data
            setTimeout(() => loadProfile(), 1000);
        } else {
            showStatus('error', result.error || 'Failed to update profile');
        }
    } catch (error) {
        console.error('Save error:', error);
        showStatus('error', 'Failed to save profile');
    }
});

// Handle profile image upload
async function uploadProfileImage(file) {
    const formData = new FormData();
    formData.append('image', file);
    
    try {
        const response = await fetch('/account/upload-image', {
            method: 'POST',
            body: formData
        });
        
        return await response.json();
    } catch (error) {
        throw new Error('Upload failed');
    }
}

// Show status message
function showStatus(type, message) {
    const alertDiv = saveStatus.querySelector('.alert');
    alertDiv.className = `alert alert-${type === 'success' ? 'success' : 'danger'}`;
    alertDiv.textContent = message;
    saveStatus.classList.remove('d-none');
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        saveStatus.classList.add('d-none');
    }, 5000);
}

// Cancel button handler
document.getElementById('cancelSettings').addEventListener('click', () => {
    if (confirm('Discard changes?')) {
        loadProfile(); // Reload original data
    }
});

// Load profile data on page load
loadProfile();