import { getCookie, setCookie, deleteCookie, decodeBase64 } from "./cookies.js";

export let userid = 0;
export let username = "";
export let displayname = "";
export let messages = 0;
export let superadmin = 0;
export let email = "";
export let cartcount = 0;

export function checkUsername() {
    let userdata = getCookie('samizdata');
    if ('logout' === userdata) return "";
    if (userdata) {
        userdata = decodeBase64(userdata);
        let u = JSON.parse(userdata);
        userid = u.i;
        messages = u.m;
        username = u.n;
        email = u.e;
        displayname = u.d ? u.d : username;
        superadmin = u.s;
        cartcount = parseInt(u.b);
        if ("" !== username) {
            document.querySelectorAll(".auth").forEach(el => { el.classList.toggle("d-none") });
            document.querySelectorAll("#userdropdown a.pp").forEach(el => { el.href = '/' });
            document.querySelectorAll(".username").forEach(el => { el.innerHTML = username });
            document.querySelectorAll(".displayname").forEach(el => { el.innerHTML = displayname });
        }
        if (superadmin) {
            const childlist = document.querySelector("#memberpanel").children;
            for (let i = 0; i < childlist.length; i++) {
                childlist.item(i).classList.add("superadmin");
            }
        }
    }
}

checkUsername();