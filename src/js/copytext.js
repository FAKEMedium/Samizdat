/**
 * https://stackoverflow.com/questions/12982156/select-copy-text-using-javascript-or-jquery
 * https://rawcdn.githack.com/sitepoint-editors/clipboardapi/a8dfad6a1355bbb79381e61a2ae68394af144cc2/demotext.html
 */
async function copy_text(element) {
    if (!navigator.clipboard) return;
    var text = document.querySelector(element).innerText;
    if (navigator.clipboard.writeText) {
        await navigator.clipboard.writeText( text );
    }
}