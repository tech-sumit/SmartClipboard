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

// Fetch latest-release version + DMG link from GitHub API; replace download button.
(async () => {
    try {
        const res = await fetch(
            'https://api.github.com/repos/tech-sumit/SmartClipboard/releases/latest',
            { headers: { 'Accept': 'application/vnd.github+json' } }
        );
        if (!res.ok) return;
        const rel = await res.json();
        const dmg = (rel.assets || []).find(a => a.name.endsWith('.dmg'));
        const version = rel.tag_name || rel.name || '';
        if (dmg) {
            document.querySelectorAll('a[data-download]').forEach(a => {
                a.href = dmg.browser_download_url;
                if (version) a.dataset.version = version;
            });
        }
        const verEl = document.getElementById('latest-version');
        if (verEl && version) verEl.textContent = version;
    } catch { /* offline / rate-limited — keep defaults */ }
})();
