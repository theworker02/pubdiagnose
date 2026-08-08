(function () {
  const root = document.documentElement;
  const stored = localStorage.getItem('pd-theme');
  if (stored) root.setAttribute('data-theme', stored);
  document.getElementById('themeToggle')?.addEventListener('click', () => {
    const next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    localStorage.setItem('pd-theme', next);
  });
  document.querySelectorAll('.copy').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-copy');
      const el = id ? document.getElementById(id) : null;
      if (!el) return;
      await navigator.clipboard.writeText(el.innerText);
      btn.textContent = 'Copied';
      setTimeout(() => { btn.textContent = 'Copy'; }, 1200);
    });
  });
})();
