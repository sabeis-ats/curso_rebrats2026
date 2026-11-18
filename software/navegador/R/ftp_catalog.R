suppressPackageStartupMessages({
  library(data.table)
  library(curl)
  library(stringr)
})

normalizar_url_ftp <- function(url) paste0(sub("/+$", "", trimws(url)), "/")

listar_arquivos_ftp <- function(url, timeout = 120L) {
  url <- normalizar_url_ftp(url)
  h <- curl::new_handle(dirlistonly = FALSE, timeout = timeout)
  txt <- tryCatch(rawToChar(curl::curl_fetch_memory(url, handle = h)$content),
                  error = function(e) {
                    warning("Erro ao listar ", url, ": ", conditionMessage(e))
                    return(NA_character_)
                  })
  if (is.na(txt)) return(data.table())
  linhas <- str_split(txt, "\\r?\\n", simplify = FALSE)[[1L]]
  linhas <- linhas[str_detect(linhas, regex("\\.(dbc|dbf)$", ignore_case = TRUE))]
  if (!length(linhas)) return(data.table())
  nomes <- str_extract(linhas, "[^[:space:]]+\\.(?:dbc|dbf)$")
  # LIST Unix: permissões, links, dono, grupo, bytes, data, nome.
  bytes <- suppressWarnings(as.numeric(str_match(linhas, "^[^ ]+\\s+\\d+\\s+\\S+\\s+\\S+\\s+(\\d+)")[, 2L]))
  data.table(no_dbc_origem = nomes, qt_bytes_ftp = bytes, ds_url = url)[!is.na(no_dbc_origem)]
}

listar_arquivos_sigtap <- function(url = url_ftp_sigtap, timeout = 180L) {
  url <- normalizar_url_ftp(url)
  h <- curl::new_handle(dirlistonly = FALSE, timeout = timeout)
  txt <- tryCatch(rawToChar(curl::curl_fetch_memory(url, handle = h)$content),
                  error = function(e) {
                    warning("Erro ao listar SIGTAP em ", url, ": ", conditionMessage(e))
                    return(NA_character_)
                  })
  if (is.na(txt)) return(data.table())
  linhas <- str_split(txt, "\\r?\\n", simplify = FALSE)[[1L]]
  linhas <- linhas[str_detect(linhas, regex("TabelaUnificada_[0-9]{6}_.*\\.zip$", ignore_case = TRUE))]
  if (!length(linhas)) return(data.table())
  nomes <- str_extract(linhas, "TabelaUnificada_[0-9]{6}_[^[:space:]]*\\.zip")
  bytes <- suppressWarnings(as.numeric(str_match(linhas, "^[^ ]+\\s+\\d+\\s+\\S+\\s+\\S+\\s+(\\d+)")[, 2L]))
  competencia <- as.integer(str_match(nomes, "TabelaUnificada_([0-9]{6})_")[, 2L])
  versao <- str_match(nomes, "_v([0-9]+)\\.zip$")[, 2L]
  out <- data.table(no_dbc_origem = nomes, qt_bytes_ftp = bytes, ds_url = url,
             sg_sistema = "SIGTAP", sg_subsistema = "PROCEDIMENTO",
             sg_prefixo_arquivo = "TABELAUNIFICADA", sg_uf_processamento = NA_character_,
             sg_uf = NA_character_, st_uf_processamento_ignorada = FALSE,
             nu_competencia = competencia, sg_versao = versao,
             no_subsistema = "Tabela unificada por procedimento")[!is.na(no_dbc_origem)]
  # O FTP pode manter revisões da mesma competência; utiliza a versão de maior timestamp.
  setorder(out, nu_competencia, sg_versao)
  out[, .SD[.N], by = nu_competencia]
}

extrair_identidade_arquivo <- function(nome, prefixos = NULL) {
  base <- tolower(str_remove(basename(nome), regex("\\.(dbc|dbf)$", ignore_case = TRUE)))
  if (is.null(prefixos)) {
    m <- str_match(base, "^([a-z_]+?)([a-z]{2}|ig)?(\\d{2}|\\d{4}|\\d{6})?$")
    prefixo <- toupper(m[, 2L]); uf <- toupper(m[, 3L]); digitos <- m[, 4L]
  } else {
    prefixos <- unique(toupper(na.omit(prefixos)))
    escolher <- function(x) {
      candidatos <- prefixos[startsWith(toupper(x), prefixos)]
      if (!length(candidatos)) return(NA_character_)
      candidatos[which.max(nchar(candidatos))]
    }
    prefixo <- vapply(base, escolher, character(1))
    resto <- ifelse(is.na(prefixo), toupper(base), substring(toupper(base), nchar(prefixo) + 1L))
    m <- str_match(resto, "^([A-Z]{2}|IG)?(\\d{6}|\\d{4}|\\d{2})?")
    uf <- m[, 2L]; digitos <- m[, 3L]
  }
  yy_to_year <- function(x) ifelse(as.integer(x) >= 79L, 1900L + as.integer(x), 2000L + as.integer(x))
  competencia <- rep(NA_integer_, length(digitos))
  i2 <- !is.na(digitos) & nchar(digitos) == 2L
  i4 <- !is.na(digitos) & nchar(digitos) == 4L
  i6 <- !is.na(digitos) & nchar(digitos) == 6L
  competencia[i2] <- yy_to_year(digitos[i2]) * 100L + 12L
  competencia[i4] <- yy_to_year(substr(digitos[i4], 1L, 2L)) * 100L + as.integer(substr(digitos[i4], 3L, 4L))
  competencia[i6] <- as.integer(digitos[i6])
  uf_processamento <- fifelse(uf == "IG", NA_character_, uf)
  data.table(sg_prefixo_arquivo = prefixo,
             sg_uf_processamento = uf_processamento,
             sg_uf = uf_processamento,
             st_uf_processamento_ignorada = uf == "IG", nu_competencia = competencia)
}

classificar_por_dicionario <- function(catalogo, dicionarios) {
  x <- copy(catalogo)
  subs <- copy(dicionarios$subsistema)
  if (!"sg_prefixo" %in% names(subs) && "prefixo" %in% names(subs)) setnames(subs, "prefixo", "sg_prefixo")
  if (!"sg_prefixo" %in% names(subs)) subs[, sg_prefixo := sg_subsistema]
  subs[, sg_prefixo := toupper(sg_prefixo)]
  id <- extrair_identidade_arquivo(x$no_dbc_origem, subs$sg_prefixo)
  x <- cbind(x, id)
  if ("ds_url" %in% names(subs)) setnames(subs, "ds_url", "ds_url_dicionario")
  candidatos <- merge(x, subs, by.x = "sg_prefixo_arquivo", by.y = "sg_prefixo", all.x = TRUE,
                      allow.cartesian = TRUE)
  # A URL é o principal desempate para prefixos reutilizados em sistemas distintos.
  if ("ds_url_dicionario" %in% names(candidatos)) {
    candidatos[, score_url := fifelse(!is.na(ds_url_dicionario) & startsWith(ds_url, ds_url_dicionario),
                                      nchar(ds_url_dicionario), 0L)]
  } else candidatos[, score_url := 0L]
  # Se nenhuma URL do dicionário casar, usa pistas inequívocas do caminho FTP.
  candidatos[is.na(sg_sistema) & grepl("/CNES/", ds_url, ignore.case = TRUE), sg_sistema := "CNES"]
  candidatos[is.na(sg_sistema) & grepl("/SIASUS/", ds_url, ignore.case = TRUE), sg_sistema := "SIA"]
  candidatos[is.na(sg_sistema) & grepl("/SIHSUS/", ds_url, ignore.case = TRUE), sg_sistema := "SIH"]
  candidatos[is.na(sg_sistema) & grepl("/SINAN/", ds_url, ignore.case = TRUE), sg_sistema := "SINAN"]
  candidatos[is.na(sg_sistema) & grepl("/SINASC/", ds_url, ignore.case = TRUE), sg_sistema := "SINASC"]
  candidatos[is.na(sg_sistema) & grepl("/SIM/", ds_url, ignore.case = TRUE), sg_sistema := "SIM"]
  candidatos[is.na(sg_sistema) & grepl("/PNI/", ds_url, ignore.case = TRUE), sg_sistema := "PNI"]
  candidatos[is.na(sg_sistema) & grepl("/RESP/", ds_url, ignore.case = TRUE), sg_sistema := "RESP"]
  candidatos[is.na(sg_sistema) & grepl("/PCE/", ds_url, ignore.case = TRUE), sg_sistema := "PCE"]
  candidatos[is.na(sg_sistema) & grepl("/SISPRENATAL/", ds_url, ignore.case = TRUE), sg_sistema := "SISPRENATAL"]
  candidatos[is.na(sg_sistema) & grepl("/CIHA/", ds_url, ignore.case = TRUE), sg_sistema := "CIHA"]
  candidatos[is.na(sg_sistema) & grepl("/CIH/", ds_url, ignore.case = TRUE), sg_sistema := "CIH"]
  candidatos[is.na(sg_sistema) & grepl("/SISCAN/|/siscan/", ds_url), sg_sistema := "SISCAN"]
  candidatos[is.na(sg_sistema) & grepl("/ESUSNOTIFICA/", ds_url, ignore.case = TRUE), sg_sistema := "ESUSNOTIFICA"]
  candidatos[is.na(sg_sistema) & grepl("/painel_oncologia/", ds_url, ignore.case = TRUE), sg_sistema := "PAINEL_ONCOLOGIA"]
  candidatos[is.na(sg_subsistema), sg_subsistema := sg_prefixo_arquivo]
  candidatos[is.na(sg_sistema), sg_sistema := "NAO_CLASSIFICADO"]
  setorder(candidatos, no_dbc_origem, ds_url, -score_url)
  candidatos <- candidatos[, .SD[1L], by = .(no_dbc_origem, ds_url)]
  candidatos[, score_url := NULL]
  candidatos[]
}

atualizar_catalogo_ftp <- function(urls = urls_ftp_padrao, dicionarios,
                                   diretorio = "./dados_catalogo_ftp") {
  dir.create(diretorio, recursive = TRUE, showWarnings = FALSE)
  atual <- file.path(diretorio, "catalogo_ftp_atual.rds")
  historico <- file.path(diretorio, "historico_versionamento.rds")
  coleta <- Sys.time()
  novo <- rbindlist(lapply(urls, listar_arquivos_ftp), fill = TRUE)
  if (!nrow(novo)) stop("Nenhum arquivo DBC/DBF encontrado.")
  novo <- classificar_por_dicionario(novo, dicionarios)
  novo[, `:=`(sg_fonte = "FTP_DATASUS", no_tema = NA_character_, sg_conjunto = sg_sistema,
              no_conjunto = no_subsistema, no_recurso = no_dbc_origem,
              ds_formato = toupper(tools::file_ext(no_dbc_origem)), st_url_direta = FALSE,
              st_processavel = TRUE)]
  sigtap <- listar_arquivos_sigtap()
  if (nrow(sigtap)) sigtap[, `:=`(sg_fonte = "FTP_SIGTAP", no_tema = "Procedimentos do SUS",
    sg_conjunto = "sigtap", no_conjunto = no_subsistema, no_recurso = no_dbc_origem,
    ds_formato = "ZIP", st_url_direta = FALSE, st_processavel = TRUE)]
  economia <- if (exists("catalogar_economia_saude", mode = "function")) catalogar_economia_saude() else data.table()
  if (nrow(economia)) economia[, `:=`(sg_fonte = fifelse(sg_sistema == "CMED", "ANVISA", "DADOS_ABERTOS_SUS"),
    no_tema = "Economia da Saúde", sg_conjunto = tolower(paste(sg_sistema, sg_subsistema, sep = "_")),
    no_conjunto = no_subsistema, no_recurso = no_dbc_origem, ds_formato = toupper(tools::file_ext(no_dbc_origem)),
    st_url_direta = sg_sistema == "CMED", st_processavel = TRUE)]
  abertas <- if (exists("catalogar_fontes_abertas", mode = "function")) catalogar_fontes_abertas() else data.table()
  if (nrow(abertas)) abertas <- abertas[!grepl("/BPS/", ds_url, ignore.case = TRUE)]
  novo <- rbindlist(list(novo, sigtap, economia, abertas), fill = TRUE, use.names = TRUE)
  novo[, dt_coleta := coleta]
  setkeyv(novo, c("ds_url", "no_dbc_origem"))

  if (file.exists(atual)) {
    antigo <- readRDS(atual)
    chave <- c("ds_url", "no_dbc_origem")
    novos <- fsetdiff(novo[, ..chave], antigo[, ..chave])
    removidos <- fsetdiff(antigo[, ..chave], novo[, ..chave])
    comparacao <- merge(novo, antigo[, c(chave, "qt_bytes_ftp"), with = FALSE], by = chave,
                        all.x = TRUE, suffixes = c("", "_anterior"))
    alterados <- comparacao[!is.na(qt_bytes_ftp_anterior) & qt_bytes_ftp != qt_bytes_ftp_anterior]
    mudancas <- rbindlist(list(
      merge(novo, novos, by = chave)[, st_versionamento := "NOVO"],
      alterados[, st_versionamento := "MODIFICADO"],
      merge(antigo, removidos, by = chave)[, `:=`(st_versionamento = "REMOVIDO", dt_coleta = coleta)]
    ), fill = TRUE)
  } else mudancas <- copy(novo)[, st_versionamento := "CARGA_INICIAL"]

  hist <- if (file.exists(historico)) rbindlist(list(readRDS(historico), mudancas), fill = TRUE) else mudancas
  saveRDS(hist, historico, compress = "xz")
  saveRDS(novo, atual, compress = "xz")
  novo[]
}
