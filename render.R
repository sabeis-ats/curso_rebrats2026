if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Instale o pacote 'quarto' e o Quarto CLI antes de compilar o livro.")
}
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Instale o pacote 'rmarkdown' antes de compilar a aula.")
}

quarto::quarto_render(input = ".")

dir.create("_book/curso", recursive = TRUE, showWarnings = FALSE)
rmarkdown::render(
  "curso_rebrats2026.Rmd",
  output_file = "index.html",
  output_dir = "_book/curso",
  params = list(
    tentar_sftp = FALSE,
    baixar_dicionario = FALSE,
    instalar_pacotes = FALSE,
    limite_registros = 20000
  ),
  envir = new.env(parent = globalenv()),
  clean = TRUE
)

message("Livro e aula gerados em _book/.")
