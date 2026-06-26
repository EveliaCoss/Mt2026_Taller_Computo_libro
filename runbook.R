# traducir libros
babelquarto::quarto_multilingual_book(
  parent_dir = ".",
  project_dir = "draft",
  main_language = "en",
  further_languages = c("es", "pt")
)



babelquarto::render_book(".")
# For a multilingual book
servr::httw("docs")


