if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Instale o pacote 'quarto' e o Quarto CLI antes de compilar o livro.")
}

quarto::quarto_render(input = ".")
