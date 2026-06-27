# traducir libros
babelquarto::quarto_multilingual_book(
  parent_dir = ".",
  project_dir = "draft",
  main_language = "en",
  further_languages = c("es", "pt")
)

# Correr los archivos con el enlace del sitio web
babelquarto::render_book(
  project_path = ".",
  site_url = "https://eveliacoss.github.io/Workshop2026_scRNAseq_CITEseq_libro",
  preview = servr::httw("docs") # Revisualizar # For a multilingual book
)


