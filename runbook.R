# traducir libros
babelquarto::quarto_multilingual_book(
  parent_dir = ".",
  project_dir = "draft",
  main_language = "en",
  further_languages = c("es", "pt")
)



babelquarto::render_book(".")
babelquarto::render_book(site_url= "https://eveliacoss.github.io/Workshop2026_scRNAseq_CITEseq_libro/")
 

babelquarto::render_book(
  project_path = ".",
  site_url = "https://eveliacoss.github.io/Workshop2026_scRNAseq_CITEseq_libro/",
  profile = NULL,
  preview = servr::httw("docs")
)

# For a multilingual book
servr::httw("_book")
servr::httw("docs")

