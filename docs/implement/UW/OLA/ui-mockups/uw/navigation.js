// Navigation Helper for OLA Portal Mockups

// Add navigation to all pages
document.addEventListener('DOMContentLoaded', function() {
    addNavigationWidget();
    addProgressIndicator();
});

function addNavigationWidget() {
    // Create floating navigation widget
    const nav = document.createElement('div');
    nav.className = 'fixed bottom-8 left-8 bg-white rounded-full shadow-lg px-6 py-3 z-50 flex items-center space-x-4';
    nav.innerHTML = `
        <a href="index.html" class="text-gray-600 hover:text-purple-600 transition" title="Home">
            <i class="fas fa-home text-xl"></i>
        </a>
        <div class="w-px h-6 bg-gray-300"></div>
        <select onchange="navigateToPage(this.value)" class="text-sm border-0 outline-none cursor-pointer">
            <option value="">Quick Jump...</option>
            <option value="01-landing-page.html">Landing Page</option>
            <option value="06-registration.html">Registration</option>
            <option value="02-conversational-application.html">Application</option>
            <option value="03-document-upload.html">Document Upload</option>
            <option value="07-best-offer.html">Best Offer</option>
            <option value="04-applicant-dashboard.html">Dashboard</option>
            <option value="09-approval-success.html">Success</option>
            <option value="10-admin-portal.html">Admin Portal</option>
            <option value="05-mobile-optimized.html">Mobile View</option>
        </select>
    `;
    document.body.appendChild(nav);
}

function addProgressIndicator() {
    // Add progress indicator based on current page
    const currentPage = getCurrentPage();
    const totalPages = 10;
    const currentPageNumber = getPageNumber(currentPage);

    if (currentPageNumber > 0) {
        const progress = document.createElement('div');
        progress.className = 'fixed top-20 right-8 bg-white rounded-lg shadow-lg p-4 z-40';
        progress.innerHTML = `
            <p class="text-sm text-gray-600 mb-2">Progress</p>
            <div class="flex items-center space-x-2">
                <div class="flex-1 bg-gray-200 rounded-full h-2">
                    <div class="bg-purple-600 h-2 rounded-full transition-all duration-500" style="width: ${(currentPageNumber / totalPages) * 100}%"></div>
                </div>
                <span class="text-sm font-semibold text-gray-800">${currentPageNumber}/${totalPages}</span>
            </div>
        `;
        document.body.appendChild(progress);
    }
}

function navigateToPage(page) {
    if (page) {
        window.location.href = page;
    }
}

function getCurrentPage() {
    const path = window.location.pathname;
    return path.split('/').pop() || 'index.html';
}

function getPageNumber(pageName) {
    const pageMap = {
        'index.html': 0,
        '01-landing-page.html': 1,
        '06-registration.html': 2,
        '02-conversational-application.html': 3,
        '03-document-upload.html': 4,
        '07-best-offer.html': 5,
        '04-applicant-dashboard.html': 6,
        '09-approval-success.html': 7,
        '10-admin-portal.html': 8,
        '05-mobile-optimized.html': 9,
        '08-underwriting-review.html': 8.5
    };
    return pageMap[pageName] || 0;
}

// Keyboard navigation
document.addEventListener('keydown', function(e) {
    // Arrow keys for navigation
    if (e.key === 'ArrowLeft') {
        navigateToPrevious();
    } else if (e.key === 'ArrowRight') {
        navigateToNext();
    }
});

function navigateToPrevious() {
    const currentPage = getCurrentPage();
    const pages = [
        'index.html',
        '01-landing-page.html',
        '06-registration.html',
        '02-conversational-application.html',
        '03-document-upload.html',
        '07-best-offer.html',
        '04-applicant-dashboard.html',
        '09-approval-success.html',
        '10-admin-portal.html',
        '05-mobile-optimized.html',
        '08-underwriting-review.html'
    ];
    const currentIndex = pages.indexOf(currentPage);
    if (currentIndex > 0) {
        window.location.href = pages[currentIndex - 1];
    }
}

function navigateToNext() {
    const currentPage = getCurrentPage();
    const pages = [
        'index.html',
        '01-landing-page.html',
        '06-registration.html',
        '02-conversational-application.html',
        '03-document-upload.html',
        '07-best-offer.html',
        '04-applicant-dashboard.html',
        '09-approval-success.html',
        '10-admin-portal.html',
        '05-mobile-optimized.html',
        '08-underwriting-review.html'
    ];
    const currentIndex = pages.indexOf(currentPage);
    if (currentIndex < pages.length - 1) {
        window.location.href = pages[currentIndex + 1];
    }
}