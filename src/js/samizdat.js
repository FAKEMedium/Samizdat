console.log('samizdat.js is loading...');
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

console.log('Username check:', username);
if (username !== '') {
  console.log('User is authenticated, loading authenticated assets...');
  // Load authenticated CSS if not already loaded
  if (!document.querySelector('link[href*="authenticated.css"]')) {
    const authCSS = document.createElement('link');
    authCSS.rel = 'stylesheet';
    authCSS.href = '/assets/authenticated.css';
    document.head.appendChild(authCSS);
    console.log('Loading authenticated.css');
  }

  // Load authenticated JS if not already loaded
  if (!document.querySelector('script[src*="authenticated.js"]')) {
    const authJS = document.createElement('script');
    authJS.src = '/assets/authenticated.js';
    authJS.defer = true;
    authJS.onload = () => console.log('authenticated.js loaded successfully');
    authJS.onerror = (e) => console.error('Failed to load authenticated.js:', e);
    document.head.appendChild(authJS);
    console.log('Loading authenticated.js');
  }
} else {
  console.log('User is not authenticated, skipping authenticated assets');
}