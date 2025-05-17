import { setCookie } from './cookies.js'

// List of RTL languages
const rtlLanguages = ['ar', 'he', 'fa'];

// Function to check if a language is RTL
export function isRTL(lang) {
    return rtlLanguages.includes(lang);
}

export function setlanguage(event, el) {
    const ref = el || event.relatedTarget;
    const newlang = ref.dataset.language;
    setCookie('language', newlang, 30);
    
    // Set the document direction based on the language
    document.documentElement.setAttribute('dir', isRTL(newlang) ? 'rtl' : 'ltr');
    
    window.location.reload();
}

window.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('#languagedropdown a').forEach(el => {
        el.addEventListener('click', (e) => {
            e.preventDefault();
            setlanguage(e, el);
        })
    })
})