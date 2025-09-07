// Initialize pagination event handlers
function initializePagination() {
    const prevLink = document.getElementById('prevLink');
    const nextLink = document.getElementById('nextLink');
    
    if (prevLink) {
        prevLink.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(prevLink.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    }
    
    if (nextLink) {
        nextLink.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(nextLink.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    }
}

// Update pagination UI using static HTML structure
function updatePagination() {
    const paginationNav = document.getElementById('messagesPagination');
    const paginationList = document.getElementById('paginationList');
    const prevButton = document.getElementById('prevButton');
    const nextButton = document.getElementById('nextButton');
    const prevLink = document.getElementById('prevLink');
    const nextLink = document.getElementById('nextLink');
    
    if (totalPages <= 1) {
        paginationNav.style.display = 'none';
        return;
    }
    
    paginationNav.style.display = 'block';
    
    // Update prev button state
    if (currentPage === 1) {
        prevButton.classList.add('disabled');
        prevLink.removeAttribute('data-page');
    } else {
        prevButton.classList.remove('disabled');
        prevLink.setAttribute('data-page', currentPage - 1);
    }
    
    // Update next button state
    if (currentPage === totalPages) {
        nextButton.classList.add('disabled');
        nextLink.removeAttribute('data-page');
    } else {
        nextButton.classList.remove('disabled');
        nextLink.setAttribute('data-page', currentPage + 1);
    }
    
    // Clear all page number buttons (keep only prev/next)
    const pageButtons = paginationList.querySelectorAll('.page-item:not(#prevButton):not(#nextButton)');
    pageButtons.forEach(btn => btn.remove());
    
    // Generate page number buttons
    let pageNumbersHtml = '';
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);
    
    if (startPage > 1) {
        pageNumbersHtml += '<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>';
        if (startPage > 2) {
            pageNumbersHtml += '<li class="page-item disabled"><span class="page-link">...</span></li>';
        }
    }
    
    for (let i = startPage; i <= endPage; i++) {
        pageNumbersHtml += `<li class="page-item ${i === currentPage ? 'active' : ''}">
            <a class="page-link" href="#" data-page="${i}">${i}</a>
        </li>`;
    }
    
    if (endPage < totalPages) {
        if (endPage < totalPages - 1) {
            pageNumbersHtml += '<li class="page-item disabled"><span class="page-link">...</span></li>';
        }
        pageNumbersHtml += `<li class="page-item"><a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a></li>`;
    }
    
    // Insert page numbers before the next button
    nextButton.insertAdjacentHTML('beforebegin', pageNumbersHtml);
    
    // Add click handlers to all pagination links
    paginationList.querySelectorAll('a.page-link[data-page]').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const page = parseInt(link.getAttribute('data-page'));
            if (page && page !== currentPage) {
                loadMessages(page);
            }
        });
    });
}