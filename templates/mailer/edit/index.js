(async function () {
  const mailid = <%= $mailid || 0 %>;
  const isNew = !mailid;

  let languages = [];
  let contents = {};
  let editors = new Map(); // Store toast-ui editors by languageid

  async function fetchData() {
    const url = isNew
      ? '<%== url_for("Mailer.new") %>'
      : `<%== url_for('Mailer.edit', mailid => '_ID_') %>`.replace('_ID_', mailid);
    const data = await window.authenticatedFetch(url);
    if (data) {
      populate(data);
    }
  }

  function populate(data) {
    const m = data.mail || {};
    languages = data.languages || [];
    const contentList = data.contents || [];

    document.querySelector('#name').value = m.name || '';

    contentList.forEach(c => {
      contents[c.languageid] = c;
    });

    if (!isNew) {
      document.querySelector('#contentSection').style.display = 'block';
      buildContentTabs();
    }
  }

  function buildContentTabs() {
    let tabsHtml = '';
    let contentHtml = '';

    languages.forEach((lang, i) => {
      const active = i === 0 ? 'active' : '';
      const show = i === 0 ? 'show active' : '';
      const content = contents[lang.languageid] || {};
      const langCode = lang.code?.toUpperCase() || lang.languageid;

      tabsHtml += '<li class="nav-item" role="presentation">'
        + '<button class="nav-link ' + active + '" id="tab-' + lang.languageid + '" data-bs-toggle="tab"'
        + ' data-bs-target="#content-' + lang.languageid + '" type="button" role="tab">'
        + langCode
        + '</button>'
        + '</li>';

      contentHtml += '<div class="tab-pane fade ' + show + '" id="content-' + lang.languageid + '" role="tabpanel">'
        + '<div class="mb-3">'
        + '<div class="d-flex justify-content-between align-items-center mb-1">'
        + '<label class="form-label mb-0"><%== __("Subject") %></label>'
        + '<button type="button" class="btn btn-sm btn-outline-secondary translate-subject" data-lang="' + lang.languageid + '" data-code="' + lang.code + '" title="<%== __("Translate") %>">'
        + '<%== icon("translate", {}) %>'
        + '</button>'
        + '</div>'
        + '<input type="text" class="form-control content-subject" data-lang="' + lang.languageid + '"'
        + ' value="' + (content.subject || '').replace(/"/g, '&quot;') + '">'
        + '</div>'
        + '<div class="mb-3">'
        + '<div class="d-flex justify-content-between align-items-center mb-1">'
        + '<label class="form-label mb-0"><%== __("Body (Markdown)") %></label>'
        + '<button type="button" class="btn btn-sm btn-outline-secondary translate-body" data-lang="' + lang.languageid + '" data-code="' + lang.code + '" title="<%== __("Translate") %>">'
        + '<%== icon("translate", {}) %>'
        + '</button>'
        + '</div>'
        + '<div class="editor-container" data-lang="' + lang.languageid + '"></div>'
        + '<textarea class="form-control content-body d-none" data-lang="' + lang.languageid + '" rows="8">' + (content.body_md || '') + '</textarea>'
        + '</div>'
        + '<button type="button" class="btn btn-sm btn-outline-primary save-content" data-lang="' + lang.languageid + '">'
        + '<%== __("Save content") %>'
        + '</button>'
        + '</div>';
    });

    document.querySelector('#langTabs').innerHTML = tabsHtml;
    document.querySelector('#langTabContent').innerHTML = contentHtml;

    // Initialize toast-ui editors
    initEditors();

    // Save content handlers
    document.querySelectorAll('.save-content').forEach(btn => {
      btn.onclick = async () => {
        const langId = parseInt(btn.dataset.lang);
        const subject = document.querySelector('.content-subject[data-lang="' + langId + '"]').value;
        const body_md = getEditorContent(langId);

        const result = await window.authenticatedFetch(
          '<%== url_for("Mailer.content.upsert", mailid => "_ID_") %>'.replace('_ID_', mailid),
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ languageid: langId, subject, body_md })
          }
        );

        if (result?.success) {
          window.showToast(result.toast, 'success');
        }
      };
    });

    // Translation handlers
    document.querySelectorAll('.translate-subject').forEach(btn => {
      btn.onclick = () => translateField('subject', btn.dataset.lang, btn.dataset.code);
    });

    document.querySelectorAll('.translate-body').forEach(btn => {
      btn.onclick = () => translateField('body', btn.dataset.lang, btn.dataset.code);
    });
  }

  function initEditors() {
    const EditorClass = window.toastui?.Editor;
    if (!EditorClass) {
      // Fallback: show textareas
      document.querySelectorAll('.content-body').forEach(ta => ta.classList.remove('d-none'));
      document.querySelectorAll('.editor-container').forEach(el => el.remove());
      return;
    }

    languages.forEach(lang => {
      const container = document.querySelector('.editor-container[data-lang="' + lang.languageid + '"]');
      const textarea = document.querySelector('.content-body[data-lang="' + lang.languageid + '"]');
      if (!container || !textarea) return;

      const editor = new EditorClass({
        el: container,
        height: '250px',
        initialEditType: 'wysiwyg',
        previewStyle: 'tab',
        usageStatistics: false,
        toolbarItems: [
          ['heading', 'bold', 'italic', 'strike'],
          ['ul', 'ol'],
          ['link'],
          ['hr']
        ],
        initialValue: textarea.value || ''
      });

      editors.set(lang.languageid, editor);
    });
  }

  function getEditorContent(langId) {
    const editor = editors.get(langId);
    if (editor) {
      return editor.getMarkdown();
    }
    // Fallback to textarea
    const textarea = document.querySelector('.content-body[data-lang="' + langId + '"]');
    return textarea ? textarea.value : '';
  }

  function setEditorContent(langId, content) {
    const editor = editors.get(langId);
    if (editor) {
      editor.setMarkdown(content);
    } else {
      const textarea = document.querySelector('.content-body[data-lang="' + langId + '"]');
      if (textarea) textarea.value = content;
    }
  }

  async function translateField(field, targetLangId, targetLangCode) {
    // Find source content from first language with content
    let sourceText = '';
    let sourceLangCode = '';

    for (const lang of languages) {
      if (lang.languageid === parseInt(targetLangId)) continue;

      if (field === 'subject') {
        const input = document.querySelector('.content-subject[data-lang="' + lang.languageid + '"]');
        if (input?.value?.trim()) {
          sourceText = input.value;
          sourceLangCode = lang.code;
          break;
        }
      } else {
        const content = getEditorContent(lang.languageid);
        if (content?.trim()) {
          sourceText = content;
          sourceLangCode = lang.code;
          break;
        }
      }
    }

    if (!sourceText) {
      window.showToast('<%== __("No source content to translate") %>', 'warning');
      return;
    }

    // Show loading state
    const btn = document.querySelector('.translate-' + field + '[data-lang="' + targetLangId + '"]');
    const originalHtml = btn.innerHTML;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
    btn.disabled = true;

    try {
      const response = await window.authenticatedFetch('<%== url_for("Mailer.translate") %>', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: sourceText,
          source_language: sourceLangCode,
          target_language: targetLangCode
        })
      });

      if (response?.success && response.translated) {
        if (field === 'subject') {
          document.querySelector('.content-subject[data-lang="' + targetLangId + '"]').value = response.translated;
        } else {
          setEditorContent(parseInt(targetLangId), response.translated);
        }
        window.showToast('<%== __("Translation complete") %>', 'success');
      } else {
        window.showToast(response?.error || '<%== __("Translation failed") %>', 'danger');
      }
    } catch (error) {
      console.error('Translation error:', error);
      window.showToast('<%== __("Translation failed") %>', 'danger');
    } finally {
      btn.innerHTML = originalHtml;
      btn.disabled = false;
    }
  }

  document.querySelector('#mailForm').onsubmit = async (e) => {
    e.preventDefault();

    const name = document.querySelector('#name').value;
    const method = isNew ? 'POST' : 'PUT';
    const url = isNew
      ? '<%== url_for("Mailer.create") %>'
      : '<%== url_for("Mailer.update", mailid => "_ID_") %>'.replace('_ID_', mailid);

    const result = await window.authenticatedFetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name })
    });

    if (result?.success) {
      window.showToast(result.toast, 'success');
      bootstrap.Modal.getInstance(document.querySelector('#universalmodal'))?.hide();

      if (isNew && result.mail?.mailid) {
        window.location.href = '<%== url_for("mailer_show", mailid => "_ID_") %>'.replace('_ID_', result.mail.mailid);
      } else {
        window.location.reload();
      }
    }
  };

  fetchData();
})();
