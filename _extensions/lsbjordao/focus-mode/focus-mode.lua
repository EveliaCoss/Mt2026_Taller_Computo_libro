local function append_header_include(meta, raw_html)
  local block = pandoc.RawBlock("html", raw_html)
  local existing = meta["header-includes"]

  if existing == nil then
    meta["header-includes"] = pandoc.MetaBlocks({ block })
    return
  end

  if existing.t == "MetaBlocks" then
    existing[#existing + 1] = block
    meta["header-includes"] = existing
    return
  end

  if existing.t == "MetaList" then
    existing[#existing + 1] = pandoc.MetaBlocks({ block })
    meta["header-includes"] = existing
    return
  end

  meta["header-includes"] = pandoc.MetaList({
    existing,
    pandoc.MetaBlocks({ block }),
  })
end

function Meta(meta)
  if not quarto.doc.is_format("html") then
    return meta
  end

  append_header_include(meta, [[<script>
(function () {
  try {
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
    if (window.localStorage.getItem("quarto-focus-mode") === "1") {
      document.documentElement.classList.add("focus-mode-persisted");
    }
    if (window.localStorage.getItem("quarto-presentation-mode") === "1") {
      document.documentElement.classList.add("presentation-mode-preload");
    }
  } catch (e) {}
})();
</script>]])

  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local dir = pandoc.path.directory(source)

  quarto.doc.add_html_dependency({
    name = "focus-mode",
    version = "1.0.0",
    stylesheets = { pandoc.path.join({ dir, "focus-mode.css" }) },
    scripts    = { pandoc.path.join({ dir, "focus-mode.js"  }) },
  })

  return meta
end
