(function () {
  // Apply persisted focus state as early as possible to prevent layout flash.
  try {
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
    if (window.localStorage.getItem("quarto-focus-mode") !== "1") return;
    document.documentElement.classList.add("focus-mode-persisted");
    if (document.body) document.body.classList.add("focus-mode");
  } catch (e) {}
})();

document.addEventListener("DOMContentLoaded", function () {

  /* ── Create DOM elements ── */
  var button = document.createElement("button");
  button.id = "focus-toggle";
  button.setAttribute("aria-label", "Focus Mode");
  button.setAttribute("type", "button");

  var icon = document.createElement("span");
  icon.id = "focus-icon";
  icon.setAttribute("aria-hidden", "true");
  icon.textContent = "⛶";

  var label = document.createElement("span");
  label.id = "focus-label";
  label.textContent = "Focus Mode";

  button.appendChild(icon);
  button.appendChild(label);
  document.body.appendChild(button);

  var progressBar = document.createElement("div");
  progressBar.id = "pres-progress";
  document.body.appendChild(progressBar);

  var indicator = document.createElement("div");
  indicator.id = "pres-indicator";
  indicator.setAttribute("aria-live", "polite");

  var counter = document.createElement("span");
  counter.id = "pres-counter";
  indicator.appendChild(counter);
  document.body.appendChild(indicator);

  /* ── Desktop-only guard ── */
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    document.documentElement.classList.remove("focus-mode-persisted");
    document.documentElement.classList.remove("presentation-mode-preload");
    document.body.classList.remove("focus-mode");
    button.style.display = "none";
    return;
  }

  /* ── Sidebar detection (Quarto outputs with sidebar) ── */
  var hasSidebar = document.querySelector("#quarto-sidebar") !== null;
  if (!hasSidebar) {
    document.documentElement.classList.remove("focus-mode-persisted");
    document.documentElement.classList.remove("presentation-mode-preload");
    document.body.classList.remove("focus-mode");
    button.style.display = "none";
    return;
  }

  var hasSequentialLinks = !!document.head.querySelector('link[rel="next"], link[rel="prev"]');
  var storageKey = "quarto-focus-mode";

  function setFocusMode(enabled) {
    document.body.classList.toggle("focus-mode", enabled);
    document.documentElement.classList.toggle("focus-mode-persisted", enabled);
    if (enabled) {
      icon.textContent  = "☰";
      label.textContent = "TOC";
      button.setAttribute("aria-label", "Show TOC");
    } else {
      icon.textContent  = "⛶";
      label.textContent = "Focus Mode";
      button.setAttribute("aria-label", "Focus Mode");
    }
    try { window.localStorage.setItem(storageKey, enabled ? "1" : "0"); } catch (e) {}
  }

  var saved = "0";
  try { saved = window.localStorage.getItem(storageKey) || "0"; } catch (e) {}
  setFocusMode(saved === "1");

  button.addEventListener("click", function () {
    setFocusMode(!document.body.classList.contains("focus-mode"));
  });

  /* ── Block 'f' on both keydown and keyup at window capture ── */
  /* Quarto's search shortcut listens on keyup; blocking only keydown is not  */
  /* enough — the keyup still fires and opens search. Both events are         */
  /* intercepted here at window capture (above document in the event path).   */
  function onFocusKey(e) {
    /* Ignore when a modifier is held so Ctrl/Cmd+F (browser find) etc. work. */
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var tag = document.activeElement ? document.activeElement.tagName : "";
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" ||
        (document.activeElement && document.activeElement.isContentEditable)) return;
    if (e.key === "f" || e.key === "F") {
      e.preventDefault();
      e.stopImmediatePropagation();
      if (e.type === "keydown") setFocusMode(true);
    }
  }
  window.addEventListener("keydown", onFocusKey, true);
  window.addEventListener("keyup",   onFocusKey, true);

  /* ── Presentation Mode ── */
  var contentRoot = document.getElementById("quarto-document-content");
  if (!contentRoot) {
    document.documentElement.classList.remove("presentation-mode-preload");
    return;
  }

  // Collect all sections in document (DFS) order
  var slides = [];
  (function collect(el) {
    for (var i = 0; i < el.children.length; i++) {
      var child = el.children[i];
      if (child.matches('section[class*="level"]')) {
        slides.push(child);
        collect(child);
      }
    }
  })(contentRoot);

  // Detect prelude: any non-section direct child (e.g. title header, intro paragraphs)
  var hasPrelude = false;
  for (var i = 0; i < contentRoot.children.length; i++) {
    if (!contentRoot.children[i].matches('section[class*="level"]')) {
      hasPrelude = true;
      break;
    }
  }

  var currentIdx = -1;
  var presActive  = false;

  /* ── Color scheme tracking ── */
  var schemeToggle = document.querySelector(".quarto-color-scheme-toggle");

  function isDarkColorScheme() {
    if (document.body && document.body.classList.contains("quarto-dark")) return true;
    if (document.body && document.body.classList.contains("quarto-light")) return false;

    var activeBootstrap = document.querySelector('link#quarto-bootstrap:not([rel="disabled-stylesheet"])');
    if (activeBootstrap && activeBootstrap.getAttribute("data-mode") === "dark") return true;
    if (activeBootstrap && activeBootstrap.getAttribute("data-mode") === "light") return false;

    if (document.documentElement.getAttribute("data-bs-theme") === "dark") return true;
    if (document.documentElement.getAttribute("data-bs-theme") === "light") return false;

    return false;
  }

  var total = slides.length + (hasPrelude ? 1 : 0);

  function normalizePath(path) {
    if (!path) return "/";
    path = String(path).trim().toLowerCase();
    if (path === "") return "/";
    if (path !== "/") path = path.replace(/\/+$/, "");
    return path || "/";
  }

  function pageKey(path) {
    path = normalizePath(path);
    return path
      .replace(/\/index\.html$/, "")
      .replace(/\/index\.qmd$/, "")
      .replace(/\/index$/, "") || "/";
  }

  var currentPath = pageKey(window.location.pathname || "/");

  function hasPreludeIn(root) {
    if (!root) return false;
    for (var i = 0; i < root.children.length; i++) {
      if (!root.children[i].matches('section[class*="level"]')) return true;
    }
    return false;
  }

  function countSectionsIn(root) {
    var count = 0;
    (function walk(el) {
      if (!el) return;
      for (var i = 0; i < el.children.length; i++) {
        var child = el.children[i];
        if (child.matches('section[class*="level"]')) {
          count++;
          walk(child);
        }
      }
    })(root);
    return count;
  }

  function countPassagesInDocument(doc) {
    var root = doc ? doc.getElementById("quarto-document-content") : null;
    if (!root) return 0;
    return countSectionsIn(root) + (hasPreludeIn(root) ? 1 : 0);
  }

  function pageUrlFromHref(href) {
    try {
      var url = new URL(href, window.location.href);
      if (url.origin !== window.location.origin) return null;
      url.hash = "";
      return url;
    } catch (e) {
      return null;
    }
  }

  function pageFromDocument(doc, url, count) {
    return {
      key: pageKey(url.pathname || "/"),
      url: url.href,
      count: typeof count === "number" ? count : countPassagesInDocument(doc),
      doc: doc
    };
  }

  function linkedPageUrl(doc, baseUrl, rel) {
    var link = doc.querySelector('link[rel~="' + rel + '"]');
    if (!link) return null;
    return pageUrlFromHref(new URL(link.getAttribute("href") || "", baseUrl).href);
  }

  function fetchPage(url) {
    var parser = new DOMParser();
    return fetch(url.href, { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) throw new Error("Unable to load " + url.href);
        return response.text();
      })
      .then(function (html) {
        var doc = parser.parseFromString(html, "text/html");
        return pageFromDocument(doc, url);
      });
  }

  var presentationProgress = {
    ready: false,
    failed: false,
    pages: [],
    currentPageIndex: -1,
    currentPageStart: 0,
    totalPassages: 0
  };
  var progressStorageKey = "quarto-presentation-progress";

  function setProgressWidth(percent, animate) {
    if (!progressBar) return;

    percent = Math.max(0, Math.min(percent, 100));
    if (animate === false) {
      var previousTransition = progressBar.style.transition;
      progressBar.style.transition = "none";
      progressBar.style.width = percent + "%";
      progressBar.offsetHeight;
      progressBar.style.transition = previousTransition;
    } else {
      progressBar.style.width = percent + "%";
    }
  }

  function saveProgressWidth(percent) {
    try { localStorage.setItem(progressStorageKey, String(percent)); } catch (e) {}
  }

  function restoreProgressWidth() {
    try {
      if (localStorage.getItem("quarto-presentation-mode") !== "1") return;
      var savedProgress = parseFloat(localStorage.getItem(progressStorageKey) || "");
      if (!isNaN(savedProgress)) setProgressWidth(savedProgress, false);
    } catch (e) {}
  }

  restoreProgressWidth();

  function finishProgressSetup() {
    presentationProgress.totalPassages = 0;
    presentationProgress.currentPageStart = 0;
    presentationProgress.currentPageIndex = -1;

    for (var i = 0; i < presentationProgress.pages.length; i++) {
      if (presentationProgress.pages[i].key === currentPath) {
        presentationProgress.currentPageIndex = i;
        presentationProgress.currentPageStart = presentationProgress.totalPassages;
      }
      presentationProgress.totalPassages += presentationProgress.pages[i].count;
    }

    presentationProgress.ready = !presentationProgress.failed &&
      presentationProgress.totalPassages > 0 &&
      presentationProgress.currentPageIndex >= 0;
  }

  /* ── Sidebar page list (quarto-website navigation) ── */
  function buildSidebarPages() {
    var seen = {};
    var pages = [];
    // .sidebar-item-section items are collapsible group headers, not pages — exclude them
    var links = document.querySelectorAll("#quarto-sidebar .sidebar-item:not(.sidebar-item-section) a[href]");
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var href = a.getAttribute("href") || "";
      if (!href || href.charAt(0) === "#") continue;
      try {
        var url = new URL(a.href);
        if (url.origin !== window.location.origin) continue;
        url.hash = "";
        var key = pageKey(url.pathname);
        if (!seen[key]) {
          seen[key] = true;
          pages.push({ key: key, url: url.href, count: 1, doc: null });
        }
      } catch (ex) {}
    }
    return pages;
  }

  function navigateSidebarPage(direction) {
    var pages = buildSidebarPages();
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].key === currentPath) {
        var target = pages[i + direction];
        if (target) window.location.href = target.url;
        return;
      }
    }
  }

  function setupProgress() {
    var currentUrl = pageUrlFromHref(window.location.href);
    if (!currentUrl) return;

    var currentPage = pageFromDocument(document, currentUrl, total);
    var updatePos = function () {
      updateProgress(currentIdx < 0 ? 1 : currentIdx + 1 + (hasPrelude ? 1 : 0));
    };

    if (!hasSequentialLinks) {
      // Website: fetch all sidebar pages in parallel to get their section counts,
      // so PageDown/PageUp progress within a page is globally consistent.
      var sidebarPages = buildSidebarPages();
      if (sidebarPages.length === 0) { presentationProgress.failed = true; updatePos(); return; }

      var fetches = sidebarPages.map(function (page) {
        if (page.key === currentPage.key) { page.count = total; return Promise.resolve(); }
        var url = pageUrlFromHref(page.url);
        if (!url) return Promise.resolve();
        return fetchPage(url).then(function (fetched) { page.count = fetched.count; }).catch(function () {});
      });

      Promise.all(fetches).then(function () {
        presentationProgress.pages = sidebarPages;
        finishProgressSetup();
        updatePos();
      }).catch(function () { presentationProgress.failed = true; updatePos(); });
      return;
    }

    // Sequential output: walk the link[rel="prev/next"] chain sequentially.
    var seen = {};
    var before = [];
    var after = [];
    seen[currentPage.key] = true;

    function collectPrevious(fromPage) {
      var prevUrl = linkedPageUrl(fromPage.doc, fromPage.url, "prev");
      if (!prevUrl) return Promise.resolve();
      var key = pageKey(prevUrl.pathname || "/");
      if (seen[key]) return Promise.resolve();
      seen[key] = true;
      return fetchPage(prevUrl).then(function (page) { before.unshift(page); return collectPrevious(page); });
    }

    function collectNext(fromPage) {
      var nextUrl = linkedPageUrl(fromPage.doc, fromPage.url, "next");
      if (!nextUrl) return Promise.resolve();
      var key = pageKey(nextUrl.pathname || "/");
      if (seen[key]) return Promise.resolve();
      seen[key] = true;
      return fetchPage(nextUrl).then(function (page) { after.push(page); return collectNext(page); });
    }

    Promise.all([collectPrevious(currentPage), collectNext(currentPage)]).then(function () {
      presentationProgress.pages = before.concat([currentPage], after);
      finishProgressSetup();
      updatePos();
    }).catch(function () { presentationProgress.failed = true; updatePos(); });
  }

  setupProgress();

  // One progress step per presentation passage across the whole output.
  // position: 1 = prelude (or first slide when no prelude), up to total.
  function updateProgress(position) {
    if (!progressBar || total === 0) return;

    position = Math.max(1, Math.min(position, total));

    if (presentationProgress.ready) {
      var globalIndex = presentationProgress.currentPageStart + position - 1;
      var denominator = Math.max(presentationProgress.totalPassages - 1, 1);
      var percent = presentationProgress.totalPassages === 1 ? 100 : (globalIndex / denominator) * 100;
      setProgressWidth(percent, true);
      saveProgressWidth(percent);
      return;
    }

    if (presentationProgress.failed) {
      var localDenominator = Math.max(total - 1, 1);
      var localPercent = total === 1 ? 100 : ((position - 1) / localDenominator) * 100;
      setProgressWidth(localPercent, true);
    }
  }

  function clearPresClasses() {
    document.body.classList.remove('pres-prelude');
    for (var i = 0; i < slides.length; i++) {
      slides[i].classList.remove('pres-current', 'pres-ancestor');
    }
  }

  /* ── TOC highlight sync for presentation mode ── */
  // Quarto's scroll handler (quarto.js) calls updateActiveLink() on every scroll
  // event and resets the active class based on offsetTop — which is unreliable in
  // presentation mode (hidden sections collapse to offsetTop≈0). A MutationObserver
  // guards the desired active state and immediately restores it whenever Quarto
  // overwrites it. The needsUpdate check prevents infinite observer loops.
  var tocGuard = null;

  function updateTocHighlight(sectionId) {
    var toc = document.getElementById("TOC");
    if (tocGuard) { tocGuard.disconnect(); tocGuard = null; }
    if (!toc) return;

    var links = toc.querySelectorAll("a[data-scroll-target]");
    var targetLink = null;

    for (var i = 0; i < links.length; i++) {
      var isTarget = !!sectionId && links[i].getAttribute("href") === "#" + sectionId;
      links[i].classList.toggle("active", isTarget);
      if (isTarget) {
        targetLink = links[i];
        links[i].scrollIntoView({ block: "nearest", behavior: "smooth" });
      }
    }

    if (!sectionId || !presActive || !targetLink) return;

    tocGuard = new MutationObserver(function () {
      if (!presActive) return;
      var needsUpdate = false;
      for (var i = 0; i < links.length; i++) {
        if (links[i].classList.contains("active") !== (links[i] === targetLink)) {
          needsUpdate = true; break;
        }
      }
      if (!needsUpdate) return;
      for (var i = 0; i < links.length; i++) {
        links[i].classList.toggle("active", links[i] === targetLink);
      }
    });
    tocGuard.observe(toc, { attributes: true, attributeFilter: ["class"], subtree: true });
  }

  function showPrelude() {
    clearPresClasses();
    currentIdx = -1;
    document.body.classList.add('pres-prelude');
    counter.textContent = "1 / " + total;
    updateProgress(1);
    updateTocHighlight(null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function showSlide(idx) {
    clearPresClasses();

    currentIdx = idx;
    var section = slides[idx];
    section.classList.add('pres-current');

    // Walk up the DOM marking ancestor sections so nested slides are reachable
    var parent = section.parentElement;
    while (parent && parent !== contentRoot) {
      if (parent.matches('section[class*="level"]')) {
        parent.classList.add('pres-ancestor');
      }
      parent = parent.parentElement;
    }

    var offset = hasPrelude ? 1 : 0;
    var position = idx + 1 + offset;
    counter.textContent = position + " / " + total;
    updateProgress(position);
    updateTocHighlight(section.id || null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  var presStorageKey = "quarto-presentation-mode";

  function clearPresentationPreload() {
    document.documentElement.classList.remove("presentation-mode-preload");
  }

  function setPresentationMode(enabled) {
    if (enabled && total === 0) return;
    presActive = enabled;
    document.body.classList.toggle("presentation-mode", enabled);
    if (enabled) {
      if (hasPrelude) { showPrelude(); } else { showSlide(0); }
      // Release visibility lock on the next frame after slide classes are set.
      requestAnimationFrame(clearPresentationPreload);
    } else {
      clearPresClasses();
      updateTocHighlight(null);
      clearPresentationPreload();
      // Re-trigger Quarto's scrollspy so TOC reverts to scroll-based highlight
      window.dispatchEvent(new Event("scroll"));
    }
    try { localStorage.setItem(presStorageKey, enabled ? "1" : "0"); } catch (e) {}
  }

  try {
    if (localStorage.getItem(presStorageKey) === "1") setPresentationMode(true);
  } catch (e) {}

  if (!presActive) clearPresentationPreload();

  function findSlideForElement(el) {
    if (!el) return -1;
    for (var si = 0; si < slides.length; si++) {
      if (slides[si] === el) return si;
    }
    for (var si = slides.length - 1; si >= 0; si--) {
      if (slides[si].contains(el)) return si;
    }
    return -1;
  }

  function jumpToHash() {
    if (!presActive || !window.location.hash) return;
    var idx = findSlideForElement(document.getElementById(window.location.hash.slice(1)));
    if (idx >= 0) showSlide(idx);
  }

  // On page load with hash (cross-page navigation)
  jumpToHash();

  // On anchor click — handles "#id", "page.html#id", and repeated clicks on same hash
  document.addEventListener("click", function (e) {
    if (!presActive) return;
    var anchor = e.target.closest("a[href]");
    if (!anchor) return;
    var href = anchor.getAttribute("href") || "";
    var hashIdx = href.indexOf("#");
    if (hashIdx < 0) return;

    // Skip links pointing to a different page
    var pagePart = href.slice(0, hashIdx);
    if (pagePart) {
      try {
        var linkUrl = new URL(href, window.location.href);
        if (linkUrl.pathname !== window.location.pathname) return;
      } catch (ex) { return; }
    }

    var targetId = href.slice(hashIdx + 1);
    if (!targetId) return;
    var idx = findSlideForElement(document.getElementById(targetId));
    if (idx >= 0) {
      e.preventDefault();
      history.pushState(null, "", "#" + targetId);
      showSlide(idx);
    }
  });

  // Fallback for programmatic hash changes
  window.addEventListener("hashchange", jumpToHash);

  document.addEventListener("keydown", function (e) {
    /* Ignore when a modifier is held so browser shortcuts (Ctrl/Cmd+P, +D,    */
    /* +L, +T, etc.) keep working instead of triggering our plain-key actions. */
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var tag = document.activeElement ? document.activeElement.tagName : "";
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" ||
        (document.activeElement && document.activeElement.isContentEditable)) return;

    if (e.key === "t" || e.key === "T") {
      e.preventDefault();
      setFocusMode(false);
      return;
    }

    if (e.key === "d" || e.key === "D" || e.key === "l" || e.key === "L") {
      e.preventDefault();
      if (!schemeToggle) return;
      var wantDark = (e.key === "d" || e.key === "D");
      var isDark = isDarkColorScheme();
      if (wantDark !== isDark) schemeToggle.click();
      return;
    }

    if (e.key === "p" || e.key === "P") {
      e.preventDefault();
      setPresentationMode(!presActive);
      return;
    }

    if (e.key === "ArrowRight") {
      e.preventDefault();
      navigateSidebarPage(1);
      return;
    }

    if (e.key === "ArrowLeft") {
      e.preventDefault();
      navigateSidebarPage(-1);
      return;
    }

    if (!presActive || total === 0) return;

    if (e.key === "PageDown") {
      e.preventDefault();
      if (currentIdx === -1 && slides.length > 0) { showSlide(0); }
      else if (currentIdx < slides.length - 1) { showSlide(currentIdx + 1); }
    } else if (e.key === "PageUp") {
      e.preventDefault();
      if (currentIdx > 0) { showSlide(currentIdx - 1); }
      else if (currentIdx === 0 && hasPrelude) { showPrelude(); }
    }
  });

});
