var SpecRenderer = function() {};

function findVisibleElements(containerEl) {
  var els = [].slice.call(containerEl.childNodes, 0);
  var haystack = [];

  // Filter out comments, text nodes, ...
  var i = 0;
  while (i < els.length) {
    if (els[i].nodeType == Node.ELEMENT_NODE) {
      haystack.push([i, els[i]]);
      i++;
    }
    else {
      els.splice(i, 1);
    }
  }

  // No child nodes
  if (!els.length) return [];

  // Find fist visible element
  var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
  while (haystack.length > 1) {
    var i = Math.floor(haystack.length / 2);
    if (haystack[i][1].offsetTop <= scrollTop) {
      haystack.splice(0, i);
    }
    else {
      haystack.splice(i);
    }
  }

  if (!haystack.length) haystack.push([0, els[0]]);

  // Figure out the first and last visible element
  var offsetHeight = window.innerHeight;
  var firstIdx = haystack[0][0];
  var lastIdx = firstIdx;
  while (lastIdx < els.length) {
    if (els[lastIdx].offsetTop > scrollTop + offsetHeight) break;
    lastIdx++;
  }

  return els.slice(firstIdx, lastIdx);
}

SpecRenderer.prototype.jsonhtmlify
  = function(e){let n=document.createElement('div');const t=[[e,n]],s=[];for(;t.length;){const[e,l]=t.shift();let a,c,o=typeof e;if(null===e||'undefined'==o?o='null':Array.isArray(e)&&(o='array'),'array'==o)(c=(e=>e)).len=e.length,(a=document.createElement('div')).className='json-array '+(c.len?'has-items':'is-empty');else if('object'==o){const n=Object.keys(e).sort();(c=(e=>n[e])).len=n.length,(a=document.createElement('div')).className='json-object '+(c.len?'has-items':'is-empty')}else(a=document.createElement('span')).className='json-'+o,a.textContent='null'==o?'null':'boolean'!=o?e:e?'true':'false';if(c){const i=document.createElement('span');if(i.className='json-type',i.textContent=c.len?o+'['+c.len+']':'{}',l.appendChild(i),-1!=s.indexOf(e))n.classList.add('has-recursive-items'),a.classList.add('is-seen');else{for(let n=0;n<c.len;n++){const s=c(n),l=document.createElement('div'),o=document.createElement('span');o.className='json-key',o.textContent=s,l.appendChild(o),a.appendChild(l),t.push([e[s],l])}s.push(e)}}l.className='json-item '+a.className.replace(/^json-/,'contains-'),l.appendChild(a)}return n}

SpecRenderer.prototype.renderNav = function() {
  var i = 0;
  if (this.firstHeadingEl.offsetTop < this.scrollTop) {
    for (i = 0; i < this.headings.length; i++) {
      if (this.headings[i].offsetTop >= this.scrollTop + this.wh - this.headingOffsetTop) break;
    }
  }

  if (i > 0) i--;

  var id = this.headings[i] && this.headings[i].id || '';
  var aEl = document.querySelector('.openapi-nav a[href$="#' + id + '"]');
  for (i = 0; i < this.aEls.length; i++) {
    this.aEls[i].parentNode.classList[this.aEls[i] == aEl ? 'add' : 'remove']('is-active');
  }
};

SpecRenderer.prototype.renderPreTags = function() {
  var ki, pi;
  for (pi = 0; pi < this.visiblePreTags.length; pi++) {
    var preEl = this.visiblePreTags[pi];
    var jsonEl = this.jsonhtmlify(JSON.parse(preEl.innerText));
    jsonEl.classList.add('json-container');
    preEl.parentNode.replaceChild(jsonEl, preEl);

    var keyEls = jsonEl.querySelectorAll('.json-key');
    for (ki = 0; ki < keyEls.length; ki++) {
      if (keyEls[ki].textContent != '$ref') continue;
      var refEl = keyEls[ki].nextElementSibling;
      refEl.parentNode.replaceChild(this.renderRefLink(refEl), refEl);
    }
  }
};

SpecRenderer.prototype.renderRefLink = function(refEl) {
  var a = document.createElement('a');
  var href = refEl.textContent.replace(/'/g, '');
  a.textContent = refEl.textContent;
  a.href = href.match(/^#/) ? '#ref-' + href.replace(/\W/g, '-').substring(2).toLowerCase() : href;
  return a;
};

SpecRenderer.prototype.renderUpButton = function() {
  this.upButton.classList[this.scrollTop > 150 ? 'add' : 'remove']('is-visible');
};

SpecRenderer.prototype.render = function() {
  this.scrollTop = document.documentElement.scrollTop || document.body.scrollTop;

  var visiblePreTags = [];
  findVisibleElements(document.querySelector('.openapi-spec')).forEach(function(el) {
    findVisibleElements(el).forEach(function(el) {
      if (el.tagName.toLowerCase() == 'pre') visiblePreTags.push(el);
    });
  });

  this.visiblePreTags = visiblePreTags;
  this.renderNav();
  this.renderPreTags();
  this.renderUpButton();
};

SpecRenderer.prototype.scrollSpy = function(e) {
  // Do not run this method too often
  if (e && e.preventDefault) return this._scrollSpyTid || (this._scrollSpyTid = setTimeout(this.scrollSpy, 100));
  if (this._scrollSpyTid) clearTimeout(this._scrollSpyTid);
  delete this._scrollSpyTid;

  this.wh = window.innerHeight;
  this.headingOffsetTop = parseInt(this.wh / 2.3, 10);
  this.render();
}

SpecRenderer.prototype.setup = function() {
  this.aEls = document.querySelectorAll('.openapi-nav a');
  this.firstHeadingEl = document.querySelector('h2');
  this.headings = document.querySelectorAll('h3[id]');
  this.upButton = document.querySelector('.openapi-up-button');
  this.scrollSpy = this.scrollSpy.bind(this);
  this.render();

  var self = this;
  ['click', 'resize', 'scroll'].forEach(function(name) { window.addEventListener(name, self.scrollSpy) });
};