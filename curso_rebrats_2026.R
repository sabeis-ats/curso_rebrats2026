# ==============================================================================
# Curso RebrATS 2025 - Acesso aos Dados da SABEIS via FTP utilizando R
# ==============================================================================
# Objetivo: Conexão à SABEIS por FTP, download, estruturação, leitura e
# análise de dados (Demanda aferida e Avaliação pós-incorporação).
# Formato: Script comentado para execução passo a passo em aula.
# ==============================================================================

# 1. Instalação e Carregamento de Pacotes
# ------------------------------------------------------------------------------
pacotes <- c("readr", "dplyr", "stringr", "tidyr", "curl",
             "data.table", "DT", "lubridate", "ggplot2", "shiny", "R.utils")

faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes) > 0) {
  install.packages(faltantes)
}

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(curl)
library(data.table)
library(lubridate)
library(ggplot2)


# 2. Conexão e Listagem de Arquivos (Com Fallback de Segurança)
# ------------------------------------------------------------------------------
url_sftp <- "sftp://45.231.133.29:7891/srv/ftp/dadosabertos/"
url_http <- "https://dados.labx.ia.br/files/sabeis/"
userpwd  <- "livre:12345"

usar_http <- FALSE # Flag que será ativada caso o SFTP falhe

arquivos <- tryCatch({
  cat("Tentando conexão primária via SFTP...\n")
  h_list <- curl::new_handle(
    userpwd = userpwd, 
    dirlistonly = TRUE, 
    timeout = 15,         # Tempo menor no list para falhar rápido se houver bloqueio
    noproxy = "*"
  )
  curl::handle_setopt(h_list, ssl_verifypeer = FALSE, ssl_verifyhost = FALSE)
  
  con <- curl::curl(url_sftp, handle = h_list)
  linhas <- readLines(con, warn = FALSE)
  close(con)
  
  linhas[nzchar(linhas)]
  
}, error = function(e) {
  cat("Falha no SFTP detectada. Acessando espelho HTTP...\n")
  usar_http <<- TRUE
  
  # Lê o código fonte (HTML) da página de arquivos abertos
  linhas_html <- readLines(url_http, warn = FALSE)
  html_completo <- paste(linhas_html, collapse = " ")
  
  # Usa regex para encontrar todos os nomes de arquivos que terminam em .csv.gz
  matches <- stringr::str_extract_all(html_completo, "[a-zA-Z0-9_.-]+\\.csv\\.gz")
  unique(unlist(matches))
})

print(head(arquivos))


# 3. Filtragem e Seleção do Arquivo de Interesse
# ------------------------------------------------------------------------------
arquivos_csv <- arquivos[grepl("\\.csv\\.gz$", arquivos)]
n_reg <- as.integer(sub(".*\\.([0-9]+)\\.csv\\.gz$", "\\1", arquivos_csv))

idx <- which(n_reg < 20000)[1]
arquivo_escolhido <- arquivos_csv[idx]

cat("\nArquivo escolhido para a prática:", arquivo_escolhido, "\n")


# 4. Download do Arquivo (Roteamento Dinâmico)
# ------------------------------------------------------------------------------
destino <- arquivo_escolhido

if (usar_http) {
  # Download via HTTP (Plano B)
  url_download <- paste0(url_http, arquivo_escolhido)
  cat("Baixando via HTTP...\n")
  download.file(url_download, destfile = destino, mode = "wb", quiet = FALSE)
  
} else {
  # Download via SFTP (Plano A)
  url_download <- paste0(url_sftp, arquivo_escolhido)
  cat("Baixando via SFTP...\n")
  h_down <- curl::new_handle(userpwd = userpwd, timeout = 180, noproxy = "*")
  curl::handle_setopt(h_down, ssl_verifypeer = FALSE, ssl_verifyhost = FALSE)
  curl::curl_download(url_download, destfile = destino, mode = "wb", handle = h_down)
}

cat("Arquivo salvo localmente em:", destino, "\n")


# 5. Leitura do Arquivo (data.table)
# ------------------------------------------------------------------------------
df <- fread(destino)
names(df) <- tolower(names(df))

cat("\nEstrutura do dataframe:\n")
print(dim(df))
print(df[1:3, 9:11])


# 6. Carga de Tabelas de Domínio (Enriquecimento) do GitHub
# ------------------------------------------------------------------------------
cat("\nCarregando tabelas de domínio...\n")
td_diretriz_cnv <- read_csv("https://raw.githubusercontent.com/sabeis-ats/bd_geral/refs/heads/main/td_diretriz_cnv.csv", show_col_types = FALSE)
td_doenca_cid10 <- read_csv("https://raw.githubusercontent.com/sabeis-ats/bd_geral/refs/heads/main/td_doenca_cid10.csv", show_col_types = FALSE)
td_sigtap       <- read_csv("https://raw.githubusercontent.com/sabeis-ats/bd_geral/refs/heads/main/td_sigtap.csv", show_col_types = FALSE)
td_municipio    <- read_csv("https://raw.githubusercontent.com/sabeis-ats/bd_geral/refs/heads/main/municipio_regiao_saude_amazonia_legal_ips.csv", show_col_types = FALSE)


# 7. Manipulação de Texto e Cruzamento (Join)
# ------------------------------------------------------------------------------
codigos_arquivos <- tibble(no_arquivo = arquivos_csv) %>%
  mutate(
    quinta_parte = str_split(no_arquivo, "_", simplify = TRUE)[, 5],
    codigo       = str_extract(quinta_parte, "^[0-9]{3}"),
    qt_registro  = str_extract(no_arquivo, "(?<=\\.)[0-9]+")
  ) %>%
  filter(!is.na(codigo))

if (is.numeric(td_diretriz_cnv$nu_diretriz)) {
  tdc <- td_diretriz_cnv %>%
    mutate(nu_diretriz_chr = sprintf("%03d", as.integer(nu_diretriz)))
} else {
  tdc <- td_diretriz_cnv %>%
    mutate(nu_diretriz_chr = str_pad(str_extract(nu_diretriz, "\\d+"), 3, pad = "0"))
}

pcdt <- codigos_arquivos %>%
  inner_join(tdc, by = c("codigo" = "nu_diretriz_chr")) %>%
  mutate(co_cid = str_replace_all(co_cid, ",", ", ")) %>%
  select(nu_diretriz, no_diretriz, co_cid, sg_pcdt, no_diretriz10, sg_tipo, no_arquivo, qt_registro)

print(head(pcdt, 3))


# 8. Análise com dplyr: Demanda Aferida e Avaliação Pós-incorporação
# ------------------------------------------------------------------------------
if ("nu_cnspcn" %in% names(df) & "nu_competencia" %in% names(df)) {
  demanda_aferida <- df %>%
    filter(!is.na(nu_cnspcn)) %>%
    mutate(mes = ymd(paste0(sprintf("%06d", as.integer(nu_competencia)), "01"))) %>%
    group_by(mes) %>%
    summarise(usuarios = n_distinct(nu_cnspcn), .groups = "drop")
  
  cat("\n--- Demanda Aferida ---\n")
  print(head(demanda_aferida))
}

if ("qt_aprovada" %in% names(df)) {
  avaliacao_pos <- df %>%
    filter(!is.na(nu_cnspcn), qt_aprovada > 0) %>%
    mutate(mes = ymd(paste0(sprintf("%06d", as.integer(nu_competencia)), "01"))) %>%
    group_by(mes) %>%
    summarise(
      usuarios    = n_distinct(nu_cnspcn),
      qt_aprovada = sum(qt_aprovada, na.rm = TRUE),
      .groups = "drop"
    )
  
  cat("\n--- Avaliação Pós-incorporação ---\n")
  print(head(avaliacao_pos))
}


# 9. Visualizações (ggplot2) para a Aula
# ------------------------------------------------------------------------------
if (exists("demanda_aferida") && nrow(demanda_aferida) > 0) {
  g1 <- ggplot(demanda_aferida, aes(x = mes, y = usuarios)) +
    geom_line(linewidth = 0.5, color = "#005a9c") +
    geom_point(size = 1.6, color = "#003b66") +
    labs(title = "Demanda Aferida", x = "Mês", y = "Usuários distintos") +
    scale_x_date(date_breaks = "1 month", labels = function(x) ifelse(month(x) == 1, format(x, "%Y"), ""), expand = c(0.01, 0.01)) +
    theme_minimal() + theme(axis.text.x = element_text(angle = 90, hjust = 1))
  print(g1)
}

if (exists("avaliacao_pos") && nrow(avaliacao_pos) > 0) {
  max_u <- max(avaliacao_pos$usuarios, na.rm = TRUE)
  max_qt <- max(avaliacao_pos$qt_aprovada, na.rm = TRUE)
  k <- ifelse(is.finite(max_u) && is.finite(max_qt) && max_qt > 0, max_u / max_qt, 1)
  
  g2 <- ggplot(avaliacao_pos, aes(x = mes)) +
    geom_line(aes(y = usuarios), color = "#d95f02") +
    geom_point(aes(y = usuarios), color = "#d95f02") +
    geom_line(aes(y = qt_aprovada * k), linetype = "dashed", color = "#1b9e77") +
    labs(title = "Avaliação Pós-incorporação", x = "Mês", y = "Usuários distintos") +
    scale_y_continuous(sec.axis = sec_axis(~ . / k, name = "Qtd. aprovada")) +
    scale_x_date(date_breaks = "1 month", labels = function(x) ifelse(month(x) == 1, format(x, "%Y"), ""), expand = c(0.01, 0.01)) +
    theme_minimal() + theme(axis.text.x = element_text(angle = 90, hjust = 1))
  print(g2)
}