document.addEventListener('DOMContentLoaded', function() {
    const cookieConsentBanner = document.getElementById('cookie-consent-banner');
    const acceptCookieBtn = document.getElementById('accept-cookie-btn');
    const declineCookieBtn = document.getElementById('decline-cookie-btn');
    const vimeoPlaceholder = document.querySelector('.vimeo-placeholder');

    // Check if user has already made a choice
    if (!getCookie('cookie_consent')) {
        cookieConsentBanner.style.display = 'block';
    } else if (getCookie('cookie_consent') === 'accepted') {
        loadVimeoPlayer();
    }

    // Event listeners for buttons
    acceptCookieBtn.addEventListener('click', function() {
        setCookie('cookie_consent', 'accepted', 365);
        cookieConsentBanner.style.display = 'none';
        loadVimeoPlayer();
    });

    declineCookieBtn.addEventListener('click', function() {
        setCookie('cookie_consent', 'declined', 365);
        cookieConsentBanner.style.display = 'none';
    });

    function loadVimeoPlayer() {
        if (vimeoPlaceholder && vimeoPlaceholder.dataset.src) {
            // Apply the styles that create the space for the video
            vimeoPlaceholder.style.padding = '56.25% 0 0 0';
            vimeoPlaceholder.style.position = 'relative';

            const iframe = document.createElement('iframe');
            iframe.src = vimeoPlaceholder.dataset.src;
            iframe.style.position = 'absolute';
            iframe.style.top = '0';
            iframe.style.left = '0';
            iframe.style.width = '100%';
            iframe.style.height = '100%';
            iframe.frameBorder = '0';
            iframe.allow = 'autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share';
            iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');

            vimeoPlaceholder.appendChild(iframe);
        }
    }

    // Helper functions for cookies
    function setCookie(name, value, days) {
        let expires = '';
        if (days) {
            const date = new Date();
            date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = '; expires=' + date.toUTCString();
        }
        document.cookie = name + '=' + (value || '') + expires + '; path=/';
    }

    function getCookie(name) {
        const nameEQ = name + '=';
        const ca = document.cookie.split(';');
        for (let i = 0; i < ca.length; i++) {
            let c = ca[i];
            while (c.charAt(0) === ' ') c = c.substring(1, c.length);
            if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
        }
        return null;
    }
});