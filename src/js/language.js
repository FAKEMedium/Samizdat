import { setCookie } from './cookies.js'

export function setlanguage(event, el) {
    const ref = el || event.relatedTarget;
    const newlang = ref.dataset.language;
    setCookie('language', newlang, 30);
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