if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Instale rmarkdown: install.packages('rmarkdown')", call. = FALSE)
}

dir.create("docs", showWarnings = FALSE)

rmarkdown::render(
  "curso_rebrats2026.Rmd",
  output_format = "html_document",
  output_file = "index.html",
  output_dir = "docs",
  clean = TRUE,
  envir = new.env(parent = globalenv())
)

rmarkdown::render(
  "curso_rebrats2026.Rmd",
  output_format = "pdf_document",
  output_file = "Curso_REBRATS_2026_SABEIS_R.pdf",
  output_dir = "docs",
  clean = TRUE,
  envir = new.env(parent = globalenv())
)

message("Arquivos gerados em docs/.")
