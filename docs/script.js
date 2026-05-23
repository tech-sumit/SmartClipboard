// Mockup tabs
document.querySelectorAll('.tabs').forEach(tabsEl => {
    const tabs = tabsEl.querySelectorAll('.tab');
    const panelGroup = document.querySelector(tabsEl.dataset.target);
    if (!panelGroup) return;
    const panels = panelGroup.querySelectorAll('.mockup-panel');

    tabs.forEach((tab, idx) => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('is-active'));
            panels.forEach(p => p.classList.remove('is-active'));
            tab.classList.add('is-active');
            panels[idx]?.classList.add('is-active');
        });
    });
});

// Copy buttons
document.querySelectorAll('.copyable').forEach(block => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-btn';
    btn.textContent = 'Copy';
    block.appendChild(btn);

    btn.addEventListener('click', async () => {
        const code = block.querySelector('code, pre')?.innerText
            ?? block.innerText.replace('Copy', '').trim();
        try {
            await navigator.clipboard.writeText(code);
            btn.textContent = 'Copied';
            btn.classList.add('is-copied');
            setTimeout(() => {
                btn.textContent = 'Copy';
                btn.classList.remove('is-copied');
            }, 1400);
        } catch {
            btn.textContent = 'Failed';
        }
    });
});

// Year in footer
const yearEl = document.getElementById('year');
if (yearEl) yearEl.textContent = new Date().getFullYear();

/* -----------------------------------------------------------
   Live release info from the GitHub Releases API.
   Updates everything that depends on the latest version so the
   page never goes stale after a new release is published.

   - <a data-download>        → href set to the DMG asset URL
   - <a data-source-zip>      → href set to the source-code zip URL
   - .dyn-version             → textContent set to the tag name (e.g. v0.1.1)
   - .dyn-asset-name          → textContent set to the DMG filename
   - .dyn-asset-size          → textContent set to a human-readable file size
   - .dyn-published           → textContent set to the published date (locale)
   - .dyn-release-url         → href set to the release HTML URL
   - .dyn-fallback (img/svg)  → graceful image error-fallback to .data-fallback
   ----------------------------------------------------------- */
(async () => {
    const REPO = 'tech-sumit/SmartClipboard';

    const setText = (sel, text) => {
        document.querySelectorAll(sel).forEach(el => { el.textContent = text; });
    };
    const setHref = (sel, url) => {
        document.querySelectorAll(sel).forEach(el => { el.href = url; });
    };
    const fmtBytes = n => {
        if (!n || n < 0) return '';
        const u = ['B', 'KB', 'MB', 'GB'];
        let i = 0; let v = n;
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
        return `${v.toFixed(v < 10 && i ? 1 : 0)} ${u[i]}`;
    };

    // Apply fallbacks early so the page never shows "…" if the network is slow.
    document.querySelectorAll('.dyn-version[data-version-fallback]').forEach(el => {
        if (el.textContent.trim() === '…') el.textContent = el.dataset.versionFallback;
    });

    let rel;
    try {
        const res = await fetch(
            `https://api.github.com/repos/${REPO}/releases/latest`,
            { headers: { Accept: 'application/vnd.github+json' } }
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        rel = await res.json();
    } catch (e) {
        console.warn('GitHub release fetch failed:', e);
        return;
    }

    const dmg = (rel.assets || []).find(a => a.name.endsWith('.dmg'));
    const version = rel.tag_name || rel.name || '';
    const publishedAt = rel.published_at
        ? new Date(rel.published_at).toLocaleDateString(undefined, {
            year: 'numeric', month: 'long', day: 'numeric'
        })
        : '';

    if (version) {
        setText('.dyn-version', version);
        document.title = `Smart Clipboard ${version} — Native macOS clipboard manager`;
    }
    if (rel.html_url) {
        setHref('.dyn-release-url', rel.html_url);
    }
    if (dmg) {
        setHref('a[data-download]', dmg.browser_download_url);
        setText('.dyn-asset-name', dmg.name);
        const sizeStr = fmtBytes(dmg.size);
        document.querySelectorAll('.dyn-asset-size').forEach(el => {
            el.textContent = sizeStr ? ` · ${sizeStr}` : '';
        });
    }
    document.querySelectorAll('.dyn-published').forEach(el => {
        el.textContent = publishedAt ? ` · ${publishedAt}` : '';
    });

    if (rel.zipball_url) {
        setHref('a[data-source-zip]', rel.zipball_url);
    }
})();
