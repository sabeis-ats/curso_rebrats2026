suppressPackageStartupMessages(library(data.table))

url_bps_base <- "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/BPS"
url_pagina_cmed <- "https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos"
url_obm_recursos <- "https://portal-obm.saude.gov.br/panel/crud/list/vmp-resources"
url_bps_api <- "https://apidadosabertos.saude.gov.br/v1/economia-da-saude/bps"

obter_tamanho_http <- function(url, timeout = 30L) {
  tryCatch({
    h <- curl::new_handle(nobody = TRUE, followlocation = TRUE, timeout = timeout)
    r <- curl::curl_fetch_memory(url, handle = h)
    cab <- rawToChar(r$headers)
    m <- regmatches(cab, regexpr("(?i)content-length:\\s*[0-9]+", cab, perl = TRUE))
    if (!length(m) || !nzchar(m)) NA_real_ else as.numeric(gsub("[^0-9]", "", m))
  }, error = function(e) NA_real_)
}

url_absoluta <- function(href, base) {
  if (grepl("^https?://", href, ignore.case = TRUE)) return(href)
  if (startsWith(href, "//")) return(paste0("https:", href))
  raiz <- sub("^(https?://[^/]+).*$", "\\1", base)
  if (startsWith(href, "/")) paste0(raiz, href) else paste0(sub("/[^/]*$", "/", base), href)
}

url_http_valida <- function(url, timeout = 30L) {
  tryCatch({
    h <- curl::new_handle(nobody = TRUE, followlocation = TRUE, timeout = timeout,
                          useragent = "datasus_navegador_R/14")
    curl::curl_fetch_memory(url, handle = h)$status_code < 400L
  }, error = function(e) FALSE)
}

descobrir_arquivos_cmed <- function() {
  paginas <- c(url_pagina_cmed, paste0(url_pagina_cmed, "/arquivos"))
  links <- character()
  for (pagina in paginas) {
    html <- tryCatch(rawToChar(curl::curl_fetch_memory(pagina,
      handle = curl::new_handle(followlocation = TRUE, timeout = 60L,
                                useragent = "datasus_navegador_R/14"))$content),
      error = function(e) "")
    if (!nzchar(html)) next
    hrefs <- regmatches(html, gregexpr("(?i)href=[\"'][^\"']+(?:xlsx?|ods)(?:/@@download/file)?[^\"']*[\"']",
                                     html, perl = TRUE))[[1L]]
    hrefs <- gsub("(?i)^href=[\"']|[\"']$", "", hrefs, perl = TRUE)
    links <- c(links, vapply(hrefs, url_absoluta, character(1), base = pagina))
  }
  links <- unique(gsub("&amp;", "&", links, fixed = TRUE))
  links <- links[vapply(links, url_http_valida, logical(1))]
  if (!length(links)) return(data.table())
  chave <- tolower(iconv(URLdecode(links), to = "ASCII//TRANSLIT"))
  tipo <- fifelse(grepl("conformidade[_-]?gov|pmvg|governo", chave), "PMVG",
          fifelse(grepl("conformidade[_-]?(site|consumidor)|pmc|consumidor", chave), "PMC", NA_character_))
  x <- data.table(ds_url = links, sg_subsistema = tipo)
  x <- x[!is.na(sg_subsistema)]
  if (!nrow(x)) return(x)
  x[, no_dbc_origem := basename(sub("/@@download/file.*$|[?#].*$", "", ds_url))]
  x[, ordem := fifelse(grepl("[0-9]{8}_[0-9]+", no_dbc_origem),
                       gsub(".*?([0-9]{8}_[0-9]+).*", "\\1", no_dbc_origem), no_dbc_origem)]
  setorder(x, sg_subsistema, -ordem)
  x[, .SD[1L], by = sg_subsistema][, ordem := NULL][]
}

catalogar_economia_saude <- function(anos = 2020L:as.integer(format(Sys.Date(), "%Y"))) {
  bps <- rbindlist(lapply(anos, function(ano) data.table(
    no_dbc_origem = paste0(ano, c("_csv.zip", "_json.zip")), qt_bytes_ftp = NA_real_,
    ds_url = paste0(url_bps_base, c("/csv/", "/json/")), sg_sistema = "BPS",
    sg_subsistema = c("COMPRA_CSV", "COMPRA_JSON"),
    sg_prefixo_arquivo = "BPS", sg_uf_processamento = NA_character_, sg_uf = NA_character_,
    st_uf_processamento_ignorada = FALSE, nu_competencia = ano * 100L + 12L,
    sg_versao = as.character(ano),
    no_subsistema = c("Compras e preços praticados (CSV)", "Compras e preços praticados (JSON)"))))
  cmed <- descobrir_arquivos_cmed()
  if (nrow(cmed)) cmed[, `:=`(qt_bytes_ftp = NA_real_, sg_sistema = "CMED",
    sg_prefixo_arquivo = "CMED", sg_uf_processamento = NA_character_, sg_uf = NA_character_,
    st_uf_processamento_ignorada = FALSE, nu_competencia = as.integer(format(Sys.Date(), "%Y%m")),
    sg_versao = NA_character_, no_subsistema = fifelse(sg_subsistema == "PMVG",
      "Preço Máximo de Venda ao Governo", "Preço Máximo ao Consumidor"))]
  faltantes <- setdiff(c("PMVG", "PMC"), cmed$sg_subsistema)
  if (length(faltantes)) warning("CMED: arquivo vigente não localizado/validado para: ", paste(faltantes, collapse = ", "))
  out <- rbindlist(list(bps, cmed), fill = TRUE)
  urls <- ifelse(out$sg_sistema == "CMED", out$ds_url,
                 paste0(normalizar_url_ftp(out$ds_url), out$no_dbc_origem))
  out[, qt_bytes_ftp := vapply(urls, obter_tamanho_http, numeric(1))]
  out[]
}

adicionar_dicionario_economia_saude <- function(dicionarios) {
  sis <- data.table(sg_sistema = c("BPS", "CMED"),
                    no_sistema = c("Banco de Preços em Saúde", "Câmara de Regulação do Mercado de Medicamentos"))
  dicionarios$sistema <- unique(rbindlist(list(dicionarios$sistema, sis), fill = TRUE), by = "sg_sistema")
  subs <- data.table(sg_sistema = c("BPS", "BPS", "CMED", "CMED"),
    sg_subsistema = c("COMPRA_CSV", "COMPRA_JSON", "PMVG", "PMC"),
    no_subsistema = c("Compras e preços praticados (CSV)", "Compras e preços praticados (JSON)",
                      "Preço Máximo de Venda ao Governo", "Preço Máximo ao Consumidor"),
    ds_url = c(paste0(url_bps_base, "/csv/"), paste0(url_bps_base, "/json/"),
               url_pagina_cmed, url_pagina_cmed))
  dicionarios$subsistema <- unique(rbindlist(list(dicionarios$subsistema, subs), fill = TRUE),
                                   by = c("sg_sistema", "sg_subsistema"))
  bps_campos <- c("ano_compra", "nome_instituicao", "esfera", "cnpj_instituicao",
    "municipio_instituicao", "uf", "compra", "insercao", "codigo_br", "descricao_catmat",
    "unidade_fornecimento", "generico", "anvisa", "modalidade_compra", "tipo_compra",
    "capacidade", "unidade_medida", "unidade_fornecimento_capacidade", "cnpj_fornecedor",
    "fornecedor", "cnpj_fabricante", "fabricante", "qtd_itens_comprados", "preco_unitario", "preco_total")
  atr <- CJ(sg_sistema = "BPS", sg_subsistema = c("COMPRA_CSV", "COMPRA_JSON"), no_atributo = bps_campos)
  atr[, `:=`(
    no_rotulo = gsub("_", " ", no_atributo),
    ds_atributo = gsub("_", " ", no_atributo))]
  atr[no_atributo == "codigo_br", `:=`(no_rotulo = "Código BR/CATMAT",
    ds_atributo = "Identificador do item no Catálogo de Materiais; não é código SIGTAP")]
  atr[no_atributo == "anvisa", `:=`(no_rotulo = "Registro Anvisa/CMED",
    ds_atributo = "Registro sanitário informado no BPS, usado para vínculo com CMED/OBM")]
  atr[no_atributo %chin% c("preco_unitario", "preco_total"), ds_atributo := "Valor monetário em reais (BRL)"]
  cmed_comuns <- c("substancia", "cnpj", "laboratorio", "codigo_ggrem", "registro",
    "ean_1", "ean_2", "ean_3", "produto", "apresentacao", "classe_terapeutica",
    "tipo_de_produto_status_do_produto", "regime_de_preco", "restricao_hospitalar",
    "cap", "confaz_87", "icms_0", "analise_recursal", "tarja")
  aliquotas <- c("sem_impostos", "0", "12", "12_alc", "17", "17_alc", "17_5",
                 "17_5_alc", "18", "18_alc", "19", "19_alc", "19_5", "19_5_alc",
                 "20", "20_alc", "20_5", "20_5_alc", "21", "21_alc", "22", "22_alc",
                 "22_5", "22_5_alc", "23", "23_alc")
  atr_cmed <- rbindlist(list(
    data.table(sg_sistema = "CMED", sg_subsistema = "PMVG",
               no_atributo = c(cmed_comuns, paste0("pf_", aliquotas), paste0("pmvg_", aliquotas))),
    data.table(sg_sistema = "CMED", sg_subsistema = "PMC",
               no_atributo = c(cmed_comuns, paste0("pf_", aliquotas), paste0("pmc_", aliquotas)))))
  atr_cmed[, `:=`(no_rotulo = gsub("_", " ", no_atributo),
                  ds_atributo = fifelse(grepl("^(pf|pmvg|pmc)_", no_atributo),
                    "Valor máximo regulatório em reais; observar alíquota e regras CMED",
                    gsub("_", " ", no_atributo)))]
  atr <- rbindlist(list(atr, atr_cmed), fill = TRUE)
  dicionarios$atributo <- unique(rbindlist(list(dicionarios$atributo, atr), fill = TRUE),
    by = c("sg_sistema", "sg_subsistema", "no_atributo"))
  dicionarios
}

consultar_bps_api <- function(codigoCatmat = NULL, cnpjInstituicao = NULL,
                              ..., tamanhoPagina = 500L, max_paginas = Inf,
                              progresso = message) {
  if (is.null(codigoCatmat) && is.null(cnpjInstituicao))
    stop("Informe codigoCatmat ou cnpjInstituicao, conforme exigido pela API BPS.")
  filtros <- c(list(codigoCatmat = codigoCatmat, cnpjInstituicao = cnpjInstituicao), list(...))
  filtros <- filtros[!vapply(filtros, is.null, logical(1))]
  saida <- list(); pagina <- 1L
  repeat {
    query <- c(list(pagina = pagina, tamanhoPagina = min(as.integer(tamanhoPagina), 500L)), filtros)
    url <- paste0(url_bps_api, "?", paste0(names(query), "=",
      vapply(query, function(z) curl::curl_escape(as.character(z)), character(1)), collapse = "&"))
    progresso(sprintf("BPS API: página %d", pagina))
    resposta <- jsonlite::fromJSON(rawToChar(curl::curl_fetch_memory(url)$content), simplifyDataFrame = TRUE)
    registros <- resposta$conteudo %||% resposta$content %||% resposta$dados %||% resposta$items %||% resposta$resultados
    if (is.null(registros) || !NROW(registros)) break
    saida[[pagina]] <- as.data.table(registros)
    total_paginas <- resposta$totalPaginas %||% resposta$total_pages %||% NA_integer_
    if (pagina >= max_paginas || (is.finite(total_paginas) && pagina >= total_paginas) || NROW(registros) < tamanhoPagina) break
    pagina <- pagina + 1L
  }
  x <- rbindlist(saida, fill = TRUE, use.names = TRUE)
  if (nrow(x)) setnames(x, normalizar_nomes(names(x)))
  x[]
}

normalizar_id_numerico <- function(x) {
  y <- gsub("[^0-9]", "", as.character(x))
  y[!nzchar(y)] <- NA_character_
  y
}

normalizar_registro_anvisa_raiz <- function(x) {
  y <- normalizar_id_numerico(x)
  ifelse(!is.na(y) & nchar(y) >= 9L, substr(y, 1L, 9L), y)
}

ler_bps_zip <- function(path, progresso = message) {
  ex <- tempfile("bps_"); dir.create(ex); on.exit(unlink(ex, recursive = TRUE, force = TRUE), add = TRUE)
  membros <- utils::unzip(path, list = TRUE)$Name
  alvo <- membros[grepl("\\.csv$", membros, ignore.case = TRUE)][1L]
  if (is.na(alvo)) stop("ZIP BPS não contém CSV.")
  utils::unzip(path, files = alvo, exdir = ex, overwrite = TRUE)
  progresso(paste("BPS: lendo", alvo, "com separador ponto e vírgula"))
  x <- fread(file.path(ex, alvo), sep = ";", encoding = "UTF-8", na.strings = c("", "NA"),
             colClasses = list(character = c("codigo_br", "anvisa", "cnpj_instituicao",
                                             "cnpj_fornecedor", "cnpj_fabricante")), showProgress = FALSE)
  setnames(x, normalizar_nomes(names(x)))
  for (j in intersect(c("preco_unitario", "preco_total", "qtd_itens_comprados", "capacidade"), names(x)))
    set(x, j = j, value = suppressWarnings(as.numeric(gsub(",", ".", x[[j]], fixed = TRUE))))
  for (j in intersect(c("compra", "insercao"), names(x)))
    set(x, j = j, value = as.IDate(x[[j]], format = "%d/%m/%Y"))
  if ("codigo_br" %in% names(x)) x[, codigo_br := normalizar_id_numerico(codigo_br)]
  if ("anvisa" %in% names(x)) x[, anvisa := normalizar_id_numerico(anvisa)]
  x[]
}

ler_bps_json_zip <- function(path, progresso = message) {
  ex <- tempfile("bps_json_"); dir.create(ex); on.exit(unlink(ex, recursive = TRUE, force = TRUE), add = TRUE)
  membros <- utils::unzip(path, list = TRUE)$Name
  alvo <- membros[grepl("\\.json$", membros, ignore.case = TRUE)][1L]
  if (is.na(alvo)) stop("ZIP BPS não contém JSON.")
  utils::unzip(path, files = alvo, exdir = ex, overwrite = TRUE)
  progresso(paste("BPS: lendo JSON integral", alvo, "(maior consumo de memória que CSV)"))
  obj <- jsonlite::fromJSON(file.path(ex, alvo), simplifyDataFrame = TRUE)
  x <- as.data.table(obj$data %||% obj)
  setnames(x, normalizar_nomes(names(x)))
  for (j in intersect(c("preco_unitario", "preco_total", "qtd_itens_comprados", "capacidade"), names(x)))
    set(x, j = j, value = suppressWarnings(as.numeric(x[[j]])))
  for (j in intersect(c("compra", "insercao"), names(x))) set(x, j = j, value = as.IDate(x[[j]]))
  if ("codigo_br" %in% names(x)) x[, codigo_br := normalizar_id_numerico(codigo_br)]
  if ("anvisa" %in% names(x)) x[, anvisa := normalizar_id_numerico(anvisa)]
  x[]
}

localizar_cabecalho_cmed <- function(path) {
  z <- readxl::read_excel(path, col_names = FALSE, n_max = 100, .name_repair = "minimal")
  i <- which(vapply(z[[1L]], function(v) identical(normalizar_nomes(v), "substancia"), logical(1)))[1L]
  if (is.na(i)) stop("Cabeçalho CMED não localizado.")
  i
}

ler_cmed_xlsx <- function(path, tipo = c("PMVG", "PMC"), progresso = message) {
  tipo <- match.arg(tipo); cab <- localizar_cabecalho_cmed(path)
  progresso(sprintf("CMED %s: lendo a partir da linha %d", tipo, cab))
  x <- as.data.table(readxl::read_excel(path, skip = cab - 1L, .name_repair = "unique"))
  setnames(x, normalizar_nomes(names(x)))
  x <- x[!is.na(substancia) & nzchar(trimws(as.character(substancia)))]
  if ("registro" %in% names(x)) x[, registro := normalizar_id_numerico(registro)]
  monetarias <- names(x)[grepl("^(pf|pmvg|pmc)(_|$)", names(x))]
  for (j in monetarias) set(x, j = j, value = suppressWarnings(as.numeric(gsub(",", ".", as.character(x[[j]]), fixed = TRUE))))
  attr(x, "tipo_preco_cmed") <- tipo
  x[]
}

baixar_consolidar_economia_saude <- function(selecao, diretorio, sobrescrever = FALSE, progresso = message) {
  partes <- vector("list", nrow(selecao))
  for (i in seq_len(nrow(selecao))) {
    r <- selecao[i]
    url <- if (r$sg_sistema == "CMED") r$ds_url else paste0(normalizar_url_ftp(r$ds_url), r$no_dbc_origem)
    destino <- file.path(path.expand(diretorio), r$no_dbc_origem)
    progresso(sprintf("[%s %d/%d] %s", r$sg_sistema, i, nrow(selecao), r$no_dbc_origem))
    path <- baixar_arquivo(url, destino, sobrescrever)
    x <- if (r$sg_sistema == "BPS" && r$sg_subsistema == "COMPRA_JSON")
      ler_bps_json_zip(path, progresso) else if (r$sg_sistema == "BPS")
      ler_bps_zip(path, progresso) else ler_cmed_xlsx(path, r$sg_subsistema, progresso)
    x[, `:=`(.arquivo_origem = r$no_dbc_origem, .url_origem = r$ds_url,
             .sistema = r$sg_sistema, .subsistema = r$sg_subsistema,
             .competencia = r$nu_competencia)]
    partes[[i]] <- x
  }
  rbindlist(partes, fill = TRUE, use.names = TRUE)
}

normalizar_texto_medicamento <- function(x) {
  x <- tolower(iconv(as.character(x), from = "", to = "ASCII//TRANSLIT"))
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

chave_busca_medicamento <- function(descricao, ingrediente = NULL) {
  desc <- normalizar_texto_medicamento(descricao)
  if (is.null(ingrediente)) ingrediente <- rep(NA_character_, length(desc))
  base <- ifelse(!is.na(ingrediente) & nzchar(trimws(ingrediente)),
                 normalizar_texto_medicamento(ingrediente), sub(" .*", "", desc))
  dose <- vapply(desc, function(z) {
    m <- unlist(stringr::str_extract_all(z, "[0-9]+(?: [0-9]+)? *(?:mcg|mg|ml|ui|g)(?: ml)?"))
    paste(unique(m), collapse = " ")
  }, character(1))
  trimws(paste(base, dose))
}

ler_csv_zip_obm <- function(zip, nome, colunas = NULL) {
  membro <- utils::unzip(zip, list = TRUE)$Name
  membro <- membro[tolower(basename(membro)) == tolower(nome)][1L]
  if (is.na(membro)) return(data.table())
  cmd <- if (.Platform$OS.type == "windows") NULL else sprintf("unzip -p %s %s", shQuote(zip), shQuote(membro))
  x <- if (is.null(cmd)) {
    ex <- tempfile("obm_"); dir.create(ex); on.exit(unlink(ex, recursive = TRUE, force = TRUE), add = TRUE)
    utils::unzip(zip, files = membro, exdir = ex); fread(file.path(ex, membro), encoding = "UTF-8", select = colunas)
  } else fread(cmd = cmd, encoding = "UTF-8", select = colunas, showProgress = FALSE)
  setnames(x, tolower(names(x))); x[]
}

mapa_registro_obm <- function(zip_obm) {
  amp <- ler_csv_zip_obm(zip_obm, "tb_amp.csv",
    c("CO_SEQ_ID", "CO_VPID", "NU_NREG", "NO_NM", "ST_REGISTRO_ATIVO"))
  vmp <- ler_csv_zip_obm(zip_obm, "tb_vmp.csv",
    c("CO_SEQ_ID", "CO_VTMID", "NO_NM", "ST_REGISTRO_ATIVO"))
  vtm <- ler_csv_zip_obm(zip_obm, "tb_vtm.csv", c("CO_SEQ_ID", "NO_NM", "ST_REGISTRO_ATIVO"))
  setnames(amp, c("co_seq_id", "co_vpid", "nu_nreg", "no_nm", "st_registro_ativo"),
                 c("co_amp", "co_vmp", "registro_anvisa", "no_amp", "st_amp"))
  setnames(vmp, c("co_seq_id", "co_vtmid", "no_nm", "st_registro_ativo"),
                 c("co_vmp", "co_vtm", "no_vmp", "st_vmp"))
  setnames(vtm, c("co_seq_id", "no_nm", "st_registro_ativo"), c("co_vtm", "no_vtm", "st_vtm"))
  amp[, registro_anvisa := normalizar_id_numerico(registro_anvisa)]
  amp[, registro_anvisa_raiz := normalizar_registro_anvisa_raiz(registro_anvisa)]
  unique(merge(merge(amp[!is.na(registro_anvisa)], vmp, by = "co_vmp", all.x = TRUE),
               vtm, by = "co_vtm", all.x = TRUE), by = c("registro_anvisa_raiz", "co_amp"))
}

mapear_bps_obm <- function(bps, zip_obm, somente_univoco = FALSE) {
  mapa <- mapa_registro_obm(zip_obm)
  if (isTRUE(somente_univoco))
    mapa <- unique(mapa)[, if (uniqueN(na.omit(no_vtm)) == 1L) .SD[1L] else NULL,
                         by = registro_anvisa_raiz]
  x <- copy(bps)
  if (!"anvisa" %in% names(x)) stop("BPS sem campo anvisa.")
  x[, anvisa := normalizar_id_numerico(anvisa)]
  x[, registro_anvisa_raiz := normalizar_registro_anvisa_raiz(anvisa)]
  merge(x, mapa, by = "registro_anvisa_raiz", all.x = TRUE, allow.cartesian = TRUE)
}

ler_rename_xlsx <- function(path) {
  x <- as.data.table(readxl::read_excel(path, skip = 2L, .name_repair = "unique"))
  setnames(x, normalizar_nomes(names(x)))
  dcb <- grep("denominacao_comum_brasileira", names(x), value = TRUE)[1L]
  if (!is.na(dcb)) {
    for (i in seq_len(nrow(x))) if ((is.na(x[[dcb]][i]) || !nzchar(trimws(x[[dcb]][i]))) && i > 1L)
      set(x, i = i, j = dcb, value = x[[dcb]][i - 1L])
    setnames(x, dcb, "no_dcb")
  }
  atc <- grep("codigo_atc", names(x), value = TRUE)[1L]
  if (!is.na(atc)) setnames(x, atc, "co_atc")
  x[]
}

ler_mapa_historico_bps_sigtap <- function(path) {
  x <- as.data.table(readxl::read_excel(path, sheet = "valor_medicamento"))
  setnames(x, normalizar_nomes(names(x)))
  validar <- c("co_procedimento", "co_bps")
  if (!all(validar %in% names(x))) stop("Mapa histórico sem colunas: ", paste(setdiff(validar, names(x)), collapse = ", "))
  x[, codigo_br := normalizar_id_numerico(co_bps)]
  z <- x[, .(co_procedimento_sigtap = unlist(stringr::str_extract_all(
    format(co_procedimento, scientific = FALSE, trim = TRUE), "[0-9]{9,10}"))),
    by = .(codigo_br, no_procedimento)]
  z[, co_procedimento_sigtap := normalizar_codigo_procedimento(co_procedimento_sigtap)]
  unique(z[!is.na(codigo_br) & !is.na(co_procedimento_sigtap),
    .(codigo_br, co_procedimento_sigtap,
      no_procedimento_sigtap = no_procedimento,
      tp_vinculo_sigtap = "mapa_historico_manual_2021",
      vl_score_sigtap = 1)])
}

mapear_bps_sigtap <- function(bps, sigtap, cmed = NULL, mapa_historico = NULL) {
  stopifnot("codigo_br" %in% names(bps), "co_procedimento" %in% names(sigtap))
  s <- copy(sigtap[substr(co_procedimento, 1L, 2L) == "06"])
  s[, chave_nome := normalizar_texto_medicamento(paste(no_procedimento, ds_procedimento))]
  b <- copy(bps)
  b[, .linha_bps := .I]
  ingrediente <- if ("no_vtm" %in% names(b)) b$no_vtm else NULL
  b[, chave_nome := chave_busca_medicamento(descricao_catmat, ingrediente)]
  if (!is.null(mapa_historico) && nrow(mapa_historico)) {
    mh <- unique(as.data.table(mapa_historico))[, if (.N == 1L) .SD else NULL, by = codigo_br]
    b <- merge(b, mh, by = "codigo_br", all.x = TRUE)
  }
  if (!is.null(cmed) && all(c("anvisa", "registro") %in% c(names(b), names(cmed)))) {
    cm <- unique(cmed[!is.na(registro), .(anvisa = registro, substancia, produto, apresentacao)])
    b <- merge(b, cm, by = "anvisa", all.x = TRUE, allow.cartesian = TRUE)
    b[!is.na(substancia), chave_nome := normalizar_texto_medicamento(paste(substancia, apresentacao))]
  }
  # Somente vínculos unívocos por inclusão textual; resultados ambíguos permanecem separados.
  itens <- unique(b[, .(codigo_br, chave_nome)])
  candidatos <- rbindlist(lapply(seq_len(nrow(itens)), function(ii) {
    termos <- unique(strsplit(itens$chave_nome[ii], " ", fixed = TRUE)[[1L]])
    termos <- termos[nchar(termos) >= 4L & !grepl("^[0-9]+$", termos)]
    if (!length(termos)) return(NULL)
    hit <- s[vapply(chave_nome, function(z) all(termos %in% strsplit(z, " ", fixed = TRUE)[[1L]]), logical(1))]
    if (!nrow(hit)) return(NULL)
    hit[, .(codigo_br = itens$codigo_br[ii], chave_nome = itens$chave_nome[ii],
            co_procedimento_sigtap = co_procedimento,
            no_procedimento_sigtap = no_procedimento,
            tp_vinculo_sigtap = "candidato_textual_grupo_06",
            vl_score_sigtap = length(termos) /
              length(unique(strsplit(chave_nome, " ", fixed = TRUE)[[1L]])))]
  }), fill = TRUE)
  if (nrow(candidatos)) {
    unico <- candidatos[, if (.N == 1L) .SD else NULL, by = .(codigo_br, chave_nome)]
    setnames(unico, c("co_procedimento_sigtap", "no_procedimento_sigtap", "tp_vinculo_sigtap", "vl_score_sigtap"),
             paste0(c("co_procedimento_sigtap", "no_procedimento_sigtap", "tp_vinculo_sigtap", "vl_score_sigtap"), "_texto"))
    b <- merge(b, unico, by = c("codigo_br", "chave_nome"), all.x = TRUE)
    for (j in c("co_procedimento_sigtap", "no_procedimento_sigtap", "tp_vinculo_sigtap", "vl_score_sigtap")) {
      jt <- paste0(j, "_texto")
      if (!j %in% names(b)) setnames(b, jt, j) else {
        b[, (j) := coalescer_vetores(get(j), get(jt))]
        b[, (jt) := NULL]
      }
    }
  }
  setorder(b, .linha_bps)
  b[, c(".linha_bps", "chave_nome") := NULL]
  attr(b, "mapa_candidatos_sigtap") <- candidatos
  b[]
}

acrescentar_sigtap_ao_bps <- function(bps, catalogo, diretorio, sobrescrever = FALSE,
                                      progresso = message) {
  meta <- as.data.table(catalogo)[sg_sistema == "SIGTAP" & sg_subsistema == "PROCEDIMENTO"]
  if (!nrow(meta)) stop("SIGTAP ausente do catálogo; execute atualizar_catalogo.R.")
  setorder(meta, nu_competencia, sg_versao)
  meta <- meta[.N]
  progresso(paste("BPS: preparando vínculo candidato com SIGTAP", meta$nu_competencia))
  sigtap <- baixar_consolidar_sigtap(meta, diretorio, sobrescrever, progresso)
  path_mapa <- file.path("config", "preco_medicamento_20211117_atual.xlsx")
  mapa <- if (file.exists(path_mapa)) ler_mapa_historico_bps_sigtap(path_mapa) else NULL
  candidatos_obm <- list.files("config", pattern = "^obm_.*\\.zip$", full.names = TRUE, ignore.case = TRUE)
  if (length(candidatos_obm)) {
    candidatos_obm <- candidatos_obm[order(file.info(candidatos_obm)$mtime, decreasing = TRUE)]
    progresso(paste("BPS: enriquecendo registros Anvisa com OBM", basename(candidatos_obm[1L])))
    bps <- mapear_bps_obm(bps, candidatos_obm[1L], somente_univoco = TRUE)
  }
  if (!is.null(mapa)) progresso("BPS: aplicando mapa histórico manual CATMAT→SIGTAP antes do candidato textual")
  mapear_bps_sigtap(bps, sigtap, mapa_historico = mapa)
}
