import '../scss/samizdat.scss';
import Modal from 'bootstrap/js/dist/modal';
import Collapse from 'bootstrap/js/dist/collapse';
import Dropdown from 'bootstrap/js/dist/dropdown';
window.bootstrap = { Modal, Collapse, Dropdown };
import './user.js';
import './sortby.js';
import './tablesorter.js';
// import './sendform.js';
import './local.js';
import './serviceworker.js';
import './language.js';
import { displayname, username, superadmin, messages, email, cartcount, userid } from './user.js';

if (username !== '') {
  // Load authenticated CSS if not already loaded
  if (!document.querySelector('link[href*="authenticated.css"]')) {
    const authCSS = document.createElement('link');
    authCSS.rel = 'stylesheet';
    authCSS.href = '/assets/authenticated.css';
    document.head.appendChild(authCSS);
  }

  // Load authenticated JS if not already loaded
  if (!document.querySelector('script[src*="authenticated.js"]')) {
    const authJS = document.createElement('script');
    authJS.src = '/assets/authenticated.js';
    authJS.defer = true;
    document.head.appendChild(authJS);
  }
}