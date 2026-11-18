suppressPackageStartupMessages(library(data.table))

endpoints_ckan_sus <- c("https://dadosabertos.saude.gov.br/api/3/action",
                        "https://ckan-dadosabertos.saude.gov.br/api/3/action")
url_diretorio_anvisa <- "https://dados.anvisa.gov.br/dados/"

obter_json <- function(url, timeout = 120L) {
  h <- curl::new_handle(timeout = timeout, followlocation = TRUE,
                        useragent = "datasus_navegador_R/14")
  r <- curl::curl_fetch_memory(url, handle = h)
  if (r$status_code >= 400L) stop("HTTP ", r$status_code, " em ", url)
  jsonlite::fromJSON(rawToChar(r$content), simplifyVector = FALSE)
}

acao_ckan <- function(acao, query = list(), endpoints = endpoints_ckan_sus) {
  qs <- if (length(query)) paste0("?", paste0(names(query), "=",
    vapply(query, function(x) curl::curl_escape(as.character(x)), character(1)), collapse = "&")) else ""
  erros <- character()
  for (base in endpoints) {
    url <- paste0(sub("/+$", "", base), "/", acao, qs)
    z <- tryCatch(obter_json(url), error = identity)
    if (!inherits(z, "error") && isTRUE(z$success)) return(z$result)
    erros <- c(erros, if (inherits(z, "error")) conditionMessage(z) else "resposta CKAN sem sucesso")
  }
  stop("Falha nos endpoints CKAN do SUS: ", paste(unique(erros), collapse = "; "))
}

listar_temas_dadosabertos_sus <- function() {
  z <- tryCatch(acao_ckan("group_list", list(all_fields = "true")), error = function(e) NULL)
  if (is.null(z)) return(data.table(
    id_tema = c("arboviroses", "assistencia-a-saude", "assistencia-farmaceutica", "atencao-primaria",
      "ciencia-tecnologia", "diagnosticos-e-tratamentos", "economia-da-saude", "educacao-em-saude",
      "indicadores-de-saude", "prevencao-e-promocao-da-saude", "saude-digital", "saude-indigena",
      "vacinacao", "vigilancia-e-meio-ambiente"),
    sg_tema = c("arboviroses", "assistencia-a-saude", "assistencia-farmaceutica", "atencao-primaria",
      "ciencia-tecnologia", "diagnosticos-e-tratamentos", "economia-da-saude", "educacao-em-saude",
      "indicadores-de-saude", "prevencao-e-promocao-da-saude", "saude-digital", "saude-indigena",
      "vacinacao", "vigilancia-e-meio-ambiente"),
    no_tema = c("Arboviroses", "Assistência à saúde", "Assistência Farmacêutica", "Atenção Primária",
      "Ciência & Tecnologia", "Diagnósticos e Tratamentos", "Economia da Saúde", "Educação em Saúde",
      "Indicadores de saúde", "Prevenção e Promoção da Saúde", "Saúde Digital", "Saúde Indígena",
      "Vacinação", "Vigilância e Meio Ambiente"),
    qt_conjuntos = c(4L,4L,1L,3L,4L,2L,3L,1L,19L,1L,1L,23L,9L,26L),
    ds_tema = "Catálogo temático oficial; contagem de referência da página inicial em 2026-08-16",
    st_catalogo_fallback = TRUE))
  rbindlist(lapply(z, function(g) data.table(
    id_tema = g$id %||% g$name, sg_tema = g$name,
    no_tema = normalizar_utf8(g$display_name %||% g$title %||% g$name),
    qt_conjuntos = as.integer(g$package_count %||% NA_integer_),
    ds_tema = normalizar_utf8(g$description %||% NA_character_))), fill = TRUE)
}

listar_recursos_dadosabertos_sus <- function(rows = 1000L) {
  inicio <- 0L; pacotes <- list()
  repeat {
    z <- acao_ckan("package_search", list(rows = rows, start = inicio))
    lote <- z$results %||% list()
    if (!length(lote)) break
    pacotes <- c(pacotes, lote)
    inicio <- inicio + length(lote)
    if (inicio >= as.integer(z$count %||% inicio)) break
  }
  out <- rbindlist(lapply(pacotes, function(p) {
    grupos <- p$groups %||% list()
    temas <- if (length(grupos)) vapply(grupos, function(g) g$display_name %||% g$title %||% g$name, character(1)) else NA_character_
    recursos <- p$resources %||% list()
    if (!length(recursos)) return(NULL)
    rbindlist(lapply(recursos, function(r) {
      formato <- toupper(trimws(r$format %||% tools::file_ext(r$url %||% "")))
      nome <- r$name %||% basename(sub("[?#].*$", "", r$url %||% "recurso"))
      extensao <- toupper(tools::file_ext(sub("[?#].*$", "", r$url %||% nome)))
      formato_leitura <- if (extensao %in% c("ZIP", "GZ")) extensao else formato
      data.table(
        sg_fonte = "DADOS_ABERTOS_SUS", no_tema = paste(unique(temas), collapse = "; "),
        id_conjunto = p$id, sg_conjunto = p$name, no_conjunto = normalizar_utf8(p$title %||% p$name),
        ds_conjunto = normalizar_utf8(p$notes %||% NA_character_),
        id_recurso = r$id, no_recurso = normalizar_utf8(nome), ds_formato = formato_leitura,
        no_dbc_origem = basename(sub("[?#].*$", "", r$url %||% nome)),
        ds_url = r$url, qt_bytes_ftp = as.numeric(r$size %||% NA_real_),
        dt_modificacao_recurso = r$last_modified %||% r$created %||% NA_character_,
        sg_sistema = "DADOS_ABERTOS_SUS", sg_subsistema = p$name,
        no_subsistema = normalizar_utf8(p$title %||% p$name),
        nu_competencia = NA_integer_, sg_uf = NA_character_, sg_uf_processamento = NA_character_,
        st_uf_processamento_ignorada = FALSE, st_url_direta = TRUE,
        st_processavel = formato_leitura %in% c("CSV", "JSON", "XLS", "XLSX", "ZIP", "GZ", "PARQUET", "RDS"))
    }), fill = TRUE)
  }), fill = TRUE)
  unique(out, by = c("id_conjunto", "id_recurso"))
}

listar_recursos_dadosabertos_html <- function(paginas = 1L:10L) {
  base <- "https://dadosabertos.saude.gov.br"
  baixar_html <- function(url) tryCatch(rawToChar(curl::curl_fetch_memory(url,
    handle = curl::new_handle(timeout = 120L, followlocation = TRUE,
                              useragent = "datasus_navegador_R/14"))$content),
    error = function(e) "")
  indices <- vapply(paginas, function(p) baixar_html(paste0(base, "/dataset?page=", p, "&rows=20")), character(1))
  hrefs <- unique(unlist(lapply(indices, function(html) {
    m <- regmatches(html, gregexpr("(?i)href=[\"']/dataset/[A-Za-z0-9_-]+[\"']", html, perl = TRUE))[[1L]]
    gsub("(?i)^href=[\"']|[\"']$", "", m, perl = TRUE)
  }), use.names = FALSE))
  hrefs <- hrefs[!is.na(hrefs) & nzchar(hrefs)]
  if (!length(hrefs)) return(data.table())
  saida <- lapply(hrefs, function(href) {
    slug <- sub(".*/", "", href); html <- baixar_html(paste0(base, href))
    if (!nzchar(html)) return(NULL)
    titulo <- regmatches(html, regexpr("(?is)<h1[^>]*>.*?</h1>", html, perl = TRUE))
    titulo <- trimws(gsub("<[^>]+>", " ", titulo)); titulo <- gsub("\\s+", " ", titulo)
    recursos <- regmatches(html, gregexpr("(?i)href=[\"'](?:https?:)?//[^\"']+|href=[\"']/[^\"']+", html, perl = TRUE))[[1L]]
    recursos <- gsub("(?i)^href=[\"']|[\"']$", "", recursos, perl = TRUE)
    recursos <- recursos[grepl("(?i)\\.(csv|json|xml|zip|xlsx?|ods|pdf|parquet|gz)(?:[/?#]|$)", recursos, perl = TRUE)]
    if (!length(recursos)) return(NULL)
    recursos <- unique(vapply(recursos, url_absoluta, character(1), base = paste0(base, href)))
    nomes <- basename(sub("[?#].*$", "", recursos)); formatos <- toupper(tools::file_ext(nomes))
    data.table(sg_fonte = "DADOS_ABERTOS_SUS", no_tema = NA_character_, id_conjunto = slug,
      sg_conjunto = slug, no_conjunto = normalizar_utf8(titulo %||% slug), ds_conjunto = NA_character_,
      id_recurso = NA_character_, no_recurso = normalizar_utf8(nomes), ds_formato = formatos,
      no_dbc_origem = nomes, ds_url = recursos, qt_bytes_ftp = NA_real_,
      dt_modificacao_recurso = NA_character_, sg_sistema = "DADOS_ABERTOS_SUS",
      sg_subsistema = slug, no_subsistema = normalizar_utf8(titulo %||% slug),
      nu_competencia = NA_integer_, sg_uf = NA_character_, sg_uf_processamento = NA_character_,
      st_uf_processamento_ignorada = FALSE, st_url_direta = TRUE,
      st_processavel = formatos %in% c("CSV", "JSON", "XLS", "XLSX", "ZIP", "GZ", "PARQUET", "RDS"),
      st_catalogo_fallback = TRUE)
  })
  unique(rbindlist(saida, fill = TRUE), by = c("sg_conjunto", "ds_url"))
}

listar_arquivos_anvisa <- function(url = url_diretorio_anvisa) {
  h <- curl::new_handle(timeout = 180L, followlocation = TRUE,
                        useragent = "datasus_navegador_R/14")
  html <- rawToChar(curl::curl_fetch_memory(url, handle = h)$content)
  candidatos <- unique(c(
    regmatches(html, gregexpr("(?i)href=[\"'][^\"']+\\.(?:csv|json|xml|zip|xlsx?|ods|pdf|parquet|gz)[^\"']*[\"']", html, perl = TRUE))[[1L]],
    regmatches(html, gregexpr("(?i)[A-Za-z0-9_./%+() -]+\\.(?:csv|json|xml|zip|xlsx?|ods|pdf|parquet|gz)", html, perl = TRUE))[[1L]]))
  candidatos <- gsub("(?i)^href=[\"']|[\"']$", "", candidatos, perl = TRUE)
  candidatos <- candidatos[!is.na(candidatos) & nzchar(candidatos)]
  if (!length(candidatos)) {
    warning("O índice público da Anvisa não expôs links no HTML. O catálogo manterá apenas recursos Anvisa configurados.")
    return(data.table())
  }
  absolutos <- ifelse(grepl("^https?://", candidatos), candidatos,
                      paste0(sub("/+$", "", url), "/", sub("^/+", "", candidatos)))
  nomes <- basename(sub("[?#].*$", "", candidatos))
  formatos <- toupper(tools::file_ext(nomes))
  data.table(
    sg_fonte = "ANVISA", no_tema = "Vigilância sanitária", id_conjunto = NA_character_,
    sg_conjunto = "arquivos_publicos_anvisa", no_conjunto = "Arquivos públicos da Anvisa",
    ds_conjunto = "Índice público mantido pela Agência Nacional de Vigilância Sanitária",
    id_recurso = NA_character_, no_recurso = normalizar_utf8(nomes), ds_formato = formatos,
    no_dbc_origem = nomes, ds_url = absolutos, qt_bytes_ftp = NA_real_,
    dt_modificacao_recurso = NA_character_, sg_sistema = "ANVISA",
    sg_subsistema = "ARQUIVOS_PUBLICOS", no_subsistema = "Arquivos públicos da Anvisa",
    nu_competencia = NA_integer_, sg_uf = NA_character_, sg_uf_processamento = NA_character_,
    st_uf_processamento_ignorada = FALSE, st_url_direta = TRUE,
    st_processavel = formatos %in% c("CSV", "JSON", "XLS", "XLSX", "ZIP", "GZ", "PARQUET", "RDS"))
}

catalogar_fontes_abertas <- function() {
  sus <- tryCatch(listar_recursos_dadosabertos_sus(), error = function(e) {
    warning("Dados Abertos SUS/CKAN: ", conditionMessage(e), "; tentando catálogo HTML.")
    tryCatch(listar_recursos_dadosabertos_html(), error = function(e2) {
      warning("Dados Abertos SUS/HTML: ", conditionMessage(e2)); data.table()
    })
  })
  anvisa <- tryCatch(listar_arquivos_anvisa(), error = function(e) {
    warning("Anvisa: ", conditionMessage(e)); data.table()
  })
  rbindlist(list(sus, anvisa), fill = TRUE, use.names = TRUE)
}

ler_recurso_aberto <- function(path, formato = NULL) {
  formato <- toupper(formato %||% tools::file_ext(path))
  if (formato == "CSV") return(fread(path, encoding = "UTF-8", showProgress = FALSE))
  if (formato == "JSON") {
    z <- jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
    return(as.data.table(z$data %||% z$result %||% z))
  }
  if (formato %in% c("XLS", "XLSX")) return(as.data.table(readxl::read_excel(path)))
  if (formato == "RDS") return(as.data.table(readRDS(path)))
  if (formato == "PARQUET") {
    if (!requireNamespace("arrow", quietly = TRUE)) stop("Instale arrow para ler Parquet.")
    return(as.data.table(arrow::read_parquet(path)))
  }
  if (formato %in% c("ZIP", "GZ")) {
    ex <- tempfile("recurso_aberto_"); dir.create(ex); on.exit(unlink(ex, recursive = TRUE, force = TRUE), add = TRUE)
    if (formato == "ZIP") utils::unzip(path, exdir = ex) else {
      destino <- file.path(ex, sub("\\.gz$", "", basename(path), ignore.case = TRUE))
      entrada <- gzfile(path, "rb"); saida <- file(destino, "wb")
      repeat { bloco <- readBin(entrada, "raw", n = 1024L^2L); if (!length(bloco)) break; writeBin(bloco, saida) }
      close(entrada); close(saida)
    }
    arquivos <- list.files(ex, recursive = TRUE, full.names = TRUE)
    suportados <- arquivos[toupper(tools::file_ext(arquivos)) %in% c("CSV", "JSON", "XLS", "XLSX", "RDS", "PARQUET")]
    if (length(suportados) != 1L) stop("Arquivo compactado deve conter exatamente um recurso tabular suportado; encontrados: ", length(suportados))
    return(ler_recurso_aberto(suportados[1L]))
  }
  stop("Formato disponível apenas para download bruto, não para concatenação: ", formato)
}

baixar_consolidar_recursos_abertos <- function(selecao, diretorio, sobrescrever = FALSE, progresso = message) {
  if (any(!selecao$st_processavel %in% TRUE))
    stop("A seleção contém recurso não tabular. Use o download bruto em vez de concatenar.")
  partes <- vector("list", nrow(selecao))
  for (i in seq_len(nrow(selecao))) {
    r <- selecao[i]
    progresso(sprintf("[%s %d/%d] %s", r$sg_fonte, i, nrow(selecao), r$no_recurso %||% r$no_dbc_origem))
    prefixo <- if (!is.na(r$id_recurso %||% NA_character_) && nzchar(r$id_recurso))
      paste0(gsub("[^A-Za-z0-9_-]", "_", r$id_recurso), "__") else ""
    nome_cache <- paste0(prefixo, gsub("[\\/:*?\"<>|]", "_", r$no_dbc_origem))
    path <- baixar_arquivo(r$ds_url, file.path(path.expand(diretorio), nome_cache), sobrescrever)
    x <- ler_recurso_aberto(path, r$ds_formato)
    setnames(x, normalizar_nomes(names(x)))
    x[, `:=`(.arquivo_origem = r$no_dbc_origem, .url_origem = r$ds_url,
             .fonte = r$sg_fonte, .conjunto = r$sg_conjunto, .recurso = r$id_recurso)]
    partes[[i]] <- x
  }
  rbindlist(partes, fill = TRUE, use.names = TRUE)
}
