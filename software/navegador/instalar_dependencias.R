repositorio <- "https://cloud.r-project.org"
pacotes <- c("data.table", "curl", "stringr", "foreign", "shiny", "DT", "callr", "readxl", "jsonlite")
faltantes <- setdiff(pacotes, rownames(installed.packages()))
if (length(faltantes)) install.packages(faltantes, repos = repositorio)

mensagem_erro <- function(e) {
  if (inherits(e, "condition")) conditionMessage(e) else "sem mensagem de erro"
}

# read.dbc não está disponível no CRAN para algumas versões do R.
if (!requireNamespace("read.dbc", quietly = TRUE)) {
  message("Instalando read.dbc a partir de danicat/read.dbc...")
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes", repos = repositorio)
  }
  erro_remotes <- tryCatch({
    remotes::install_github("danicat/read.dbc", upgrade = "never")
    NULL
  }, error = identity)

  if (!requireNamespace("read.dbc", quietly = TRUE)) {
    message("Fallback: tentando instalação com pak...")
    if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak", repos = repositorio)
    erro_pak <- tryCatch({ pak::pak("danicat/read.dbc"); NULL }, error = identity)
  } else erro_pak <- NULL

  if (!requireNamespace("read.dbc", quietly = TRUE)) {
    stop("Não foi possível instalar read.dbc. remotes: ", mensagem_erro(erro_remotes),
         "; pak: ", mensagem_erro(erro_pak))
  }
}

message("Dependências instaladas; read.dbc ", as.character(packageVersion("read.dbc")), " disponível.")
message("O pacote arrow é opcional para exportar Parquet.")
