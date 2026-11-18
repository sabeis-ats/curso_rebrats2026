suppressPackageStartupMessages({
  library(data.table)
  library(curl)
})

baixar_arquivo <- function(url, destino, sobrescrever = FALSE) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(destino) && !sobrescrever) {
    message("[CACHE] ", basename(destino), " já existe: ", normalizePath(destino))
    return(normalizePath(destino))
  }
  message("[DOWNLOAD] início: ", basename(destino), " <- ", url)
  curl::curl_download(url, destino, quiet = FALSE, mode = "wb")
  message("[DOWNLOAD] concluído: ", basename(destino), " (",
          format(file.info(destino)$size, big.mark = ".", decimal.mark = ","), " bytes)")
  normalizePath(destino)
}

normalizar_texto_dataset <- function(dt) {
  for (j in names(dt)) {
    if (is.factor(dt[[j]])) set(dt, j = j, value = normalizar_utf8(as.character(dt[[j]])))
    else if (is.character(dt[[j]])) set(dt, j = j, value = normalizar_utf8(dt[[j]]))
  }
  dt[]
}

ler_dbc_dbf <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "dbc") {
    if (!requireNamespace("read.dbc", quietly = TRUE)) stop("Instale read.dbc para ler DBC.")
    return(normalizar_texto_dataset(as.data.table(read.dbc::read.dbc(path))))
  }
  if (ext == "dbf") {
    if (!requireNamespace("foreign", quietly = TRUE)) stop("Instale foreign para ler DBF.")
    return(normalizar_texto_dataset(as.data.table(foreign::read.dbf(path, as.is = TRUE))))
  }
  stop("Extensão não suportada: ", ext)
}

subsistemas_sia_com_pa <- c("ABO", "AB", "ACF", "AD", "AM", "AN", "AQ", "AR", "ATD")

normalizar_chave_autorizacao <- function(x) {
  if (is.numeric(x)) x <- format(x, scientific = FALSE, trim = TRUE, digits = 22L)
  x <- trimws(as.character(x))
  x[is.na(x) | !nzchar(x) | grepl("^0+$", x)] <- NA_character_
  x
}

normalizar_codigo_procedimento <- function(x) {
  if (is.numeric(x)) x <- format(x, scientific = FALSE, trim = TRUE, digits = 22L)
  x <- trimws(sub("\\.0+$", "", as.character(x)))
  i <- !is.na(x) & grepl("^[0-9]+$", x) & nchar(x) < 10L
  x[i] <- paste0(strrep("0", 10L - nchar(x[i])), x[i])
  x
}

primeira_coluna <- function(dt, candidatos) {
  z <- intersect(tolower(candidatos), names(dt))
  if (length(z)) z[[1L]] else NA_character_
}

origens_padrao <- function(dicionarios, sistema, subsistema, padrao) {
  dic <- dicionarios$atributo[sg_sistema == sistema & sg_subsistema == subsistema &
                               no_atributo_padrao == padrao]
  unique(na.omit(tolower(dic$no_atributo)))
}

selecionar_pa_correspondente <- function(selecao, catalogo) {
  if (is.null(catalogo) || !nrow(catalogo)) return(data.table())
  pares <- unique(as.data.table(selecao)[, .(sg_uf, nu_competencia)])
  pa <- as.data.table(catalogo)[sg_sistema == "SIA" & sg_subsistema == "PA"]
  merge(pa, pares, by = c("sg_uf", "nu_competencia"), all = FALSE)
}

coalescer_vetores <- function(a, b) {
  if (!identical(typeof(a), typeof(b))) {
    a <- as.character(a); b <- as.character(b)
  }
  vazio <- is.na(a) | (is.character(a) & !nzchar(trimws(a)))
  a[vazio] <- b[vazio]
  a
}

complementar_sia_com_pa <- function(dados, selecao, catalogo, dicionarios, diretorio,
                                    sobrescrever = FALSE, progresso = message) {
  sub <- unique(selecao$sg_subsistema)
  if (length(sub) != 1L || !sub %in% subsistemas_sia_com_pa) return(dados)
  pa_meta <- selecionar_pa_correspondente(selecao, catalogo)
  if (!nrow(pa_meta)) stop("Não foi encontrado PA para as mesmas UF/competências da seleção.")

  dados <- projetar_atributos_padrao(dados, dicionarios, selecao)
  aut_base <- primeira_coluna(dados, c("nu_autorizacao", origens_padrao(dicionarios, "SIA", sub, "nu_autorizacao"),
                                      names(dados)[grepl("autoriz", names(dados))]))
  proc_base <- primeira_coluna(dados, c("co_procedimento", origens_padrao(dicionarios, "SIA", sub, "co_procedimento"),
                                       names(dados)[grepl("pripal|proc_id|codpro", names(dados))]))
  if (is.na(aut_base)) stop("Não foi localizado o atributo de autorização em SIA.", sub, ".")

  grupos_pa <- split(pa_meta, by = c("sg_uf", "nu_competencia"), keep.by = TRUE)
  resultados <- vector("list", length(grupos_pa))
  for (i in seq_along(grupos_pa)) {
    meta_par <- grupos_pa[[i]]
    r0 <- meta_par[1L]
    base_par <- dados[.uf == r0$sg_uf & .competencia == r0$nu_competencia]
    procedimentos <- if (!is.na(proc_base)) unique(normalizar_codigo_procedimento(base_par[[proc_base]])) else character()
    procedimentos <- procedimentos[!is.na(procedimentos) & nzchar(procedimentos)]

    partes_pa <- vector("list", nrow(meta_par))
    for (k in seq_len(nrow(meta_par))) {
      r <- meta_par[k]
      progresso(sprintf("[PA %d/%d, parte %d/%d] preparando %s", i, length(grupos_pa),
                        k, nrow(meta_par), r$no_dbc_origem))
      path <- baixar_arquivo(paste0(normalizar_url_ftp(r$ds_url), r$no_dbc_origem),
                             file.path(path.expand(diretorio), r$no_dbc_origem), sobrescrever)
      parte <- ler_dbc_dbf(path)
      setnames(parte, names(parte), tolower(names(parte)))
      parte <- projetar_atributos_padrao(parte, dicionarios, r)
      proc_parte <- primeira_coluna(parte, c("co_procedimento",
        origens_padrao(dicionarios, "SIA", "PA", "co_procedimento"),
        names(parte)[grepl("proc_id|codpro", names(parte))]))
      if (length(procedimentos) && !is.na(proc_parte))
        parte <- parte[normalizar_codigo_procedimento(get(proc_parte)) %in% procedimentos]
      parte[, .arquivo_pa := r$no_dbc_origem]
      partes_pa[[k]] <- parte
      rm(parte); invisible(gc(FALSE))
    }
    pa <- rbindlist(partes_pa, fill = TRUE, use.names = TRUE)
    aut_pa <- primeira_coluna(pa, c("nu_autorizacao", origens_padrao(dicionarios, "SIA", "PA", "nu_autorizacao"),
                                  names(pa)[grepl("autoriz|numapa", names(pa))]))
    if (is.na(aut_pa)) stop("Não foi localizado o atributo de autorização no PA.")
    base_par[, .chave_autorizacao := normalizar_chave_autorizacao(get(aut_base))]
    pa[, .chave_autorizacao := normalizar_chave_autorizacao(get(aut_pa))]
    pa <- pa[!is.na(.chave_autorizacao)]
    pa[, .complementado_pa := TRUE]
    unido <- merge(base_par, pa, by = ".chave_autorizacao", all.x = TRUE,
                   allow.cartesian = TRUE, suffixes = c("", "_pa"))

    padroes <- unique(na.omit(dicionarios$atributo[sg_sistema == "SIA" &
      sg_subsistema %in% c(sub, "PA"), no_atributo_padrao]))
    for (j in intersect(padroes, names(unido))) {
      jp <- paste0(j, "_pa")
      if (jp %in% names(unido)) {
        unido[, (j) := coalescer_vetores(get(j), get(jp))]
        unido[, (jp) := NULL]
      }
    }
    resultados[[i]] <- unido
    rm(pa, base_par, unido); invisible(gc(FALSE))
  }
  cobertos <- unique(pa_meta[, paste(sg_uf, nu_competencia)])
  restantes <- dados[!paste(.uf, .competencia) %in% cobertos]
  rbindlist(c(resultados, list(restantes)), fill = TRUE, use.names = TRUE)
}

baixar_e_concatenar <- function(selecao, dicionarios,
                                diretorio = path.expand("~/Downloads/dbc"),
                                usar_atributo_padrao = FALSE,
                                complementar_pa = FALSE,
                                acrescentar_sigtap = FALSE,
                                catalogo = NULL,
                                sobrescrever = FALSE,
                                progresso = message) {
  selecao <- as.data.table(selecao)
  if (!nrow(selecao)) stop("Seleção vazia.")
  validar_colunas(selecao, c("ds_url", "no_dbc_origem", "sg_sistema", "sg_subsistema"), "seleção")
  if (all(selecao$sg_sistema == "SIGTAP")) {
    if (!exists("baixar_consolidar_sigtap", mode = "function")) stop("Carregue R/sigtap.R antes do processamento SIGTAP.")
    dados <- baixar_consolidar_sigtap(selecao, diretorio, sobrescrever, progresso)
    dados <- decorar_dataset(dados, dicionarios, "SIGTAP", "PROCEDIMENTO")
    attr(dados, "datasus_files") <- selecao
    return(dados)
  }
  if (all(selecao$sg_sistema %in% c("BPS", "CMED"))) {
    if (!exists("baixar_consolidar_economia_saude", mode = "function"))
      stop("Carregue R/economia_saude.R antes do processamento BPS/CMED.")
    dados <- baixar_consolidar_economia_saude(selecao, diretorio, sobrescrever, progresso)
    if (isTRUE(acrescentar_sigtap) && all(selecao$sg_sistema == "BPS")) {
      if (is.null(catalogo)) stop("O catálogo é necessário para acrescentar SIGTAP ao BPS.")
      dados <- acrescentar_sigtap_ao_bps(dados, catalogo, diretorio, sobrescrever, progresso)
    }
    attr(dados, "datasus_files") <- selecao
    return(dados)
  }
  if (all(selecao$sg_fonte %in% c("DADOS_ABERTOS_SUS", "ANVISA"))) {
    if (!exists("baixar_consolidar_recursos_abertos", mode = "function"))
      stop("Carregue R/catalogos_abertos.R antes de processar recursos abertos.")
    dados <- baixar_consolidar_recursos_abertos(selecao, diretorio, sobrescrever, progresso)
    attr(dados, "datasus_files") <- selecao
    return(dados)
  }
  arquivos <- character(nrow(selecao))
  partes <- vector("list", nrow(selecao))
  for (i in seq_len(nrow(selecao))) {
    r <- selecao[i]
    url <- paste0(normalizar_url_ftp(r$ds_url), r$no_dbc_origem)
    # O espelho local dos servidores pipeta/bureta é plano, sem subpastas.
    destino <- file.path(path.expand(diretorio), r$no_dbc_origem)
    progresso(sprintf("[%d/%d] verificando %s (%s bytes)", i, nrow(selecao),
                      r$no_dbc_origem, format(r$qt_bytes_ftp %||% NA_real_, big.mark = ".", decimal.mark = ",")))
    arquivos[[i]] <- baixar_arquivo(url, destino, sobrescrever)
    progresso(sprintf("[%d/%d] lendo e harmonizando %s", i, nrow(selecao), r$no_dbc_origem))
    dt <- ler_dbc_dbf(arquivos[[i]])
    setnames(dt, names(dt), tolower(names(dt)))
    dt[, `:=`(.arquivo_origem = r$no_dbc_origem, .url_origem = r$ds_url,
              .sistema = r$sg_sistema, .subsistema = r$sg_subsistema,
              .competencia = r$nu_competencia %||% NA_integer_,
              .uf_processamento = r$sg_uf %||% NA_character_, .uf = r$sg_uf %||% NA_character_)]
    partes[[i]] <- dt
  }
  dados <- rbindlist(partes, fill = TRUE, use.names = TRUE)
  sistema <- unique(selecao$sg_sistema)
  subsistema <- unique(selecao$sg_subsistema)
  if (usar_atributo_padrao) dados <- projetar_atributos_padrao(dados, dicionarios, selecao)
  if (isTRUE(complementar_pa)) {
    dados <- complementar_sia_com_pa(dados, selecao, catalogo, dicionarios, diretorio,
                                     sobrescrever, progresso)
    attr(dados, "datasus_files_pa") <- selecionar_pa_correspondente(selecao, catalogo)
  }
  if (length(sistema) == 1L && length(subsistema) == 1L) {
    dados <- decorar_dataset(dados, dicionarios, sistema, subsistema,
                             unique(selecao$sg_versao %||% NA_character_)[1L])
  }
  attr(dados, "datasus_files") <- selecao
  dados
}

recursos_disponiveis <- function(diretorio = tempdir()) {
  memoria <- NA_real_
  if (file.exists("/proc/meminfo")) {
    z <- readLines("/proc/meminfo", warn = FALSE)
    memoria <- suppressWarnings(as.numeric(sub(".*MemAvailable:\\s*([0-9]+).*", "\\1", z[grepl("MemAvailable", z)][1L]))) * 1024
  }
  linha_df <- suppressWarnings(system2("df", c("-Pk", path.expand(diretorio)), stdout = TRUE))
  campos_df <- if (length(linha_df) >= 2L) strsplit(trimws(linha_df[2L]), "[[:space:]]+")[[1L]] else character()
  disco <- if (length(campos_df) >= 4L) suppressWarnings(as.numeric(campos_df[4L])) * 1024 else NA_real_
  list(memoria_bytes = memoria, disco_bytes = disco)
}

gerar_script_download <- function(selecao, usar_atributo_padrao = FALSE,
                                  complementar_pa = FALSE,
                                  acrescentar_sigtap = FALSE,
                                  diretorio_dbc = "~/Downloads/dbc",
                                  arquivo_saida = NULL) {
  selecao <- as.data.table(selecao)
  if (!nrow(selecao)) stop("Seleção vazia.")
  if (is.null(arquivo_saida)) {
    arquivo_saida <- sprintf("dados_saida/%s_%s.rds", tolower(selecao$sg_sistema[1L]),
                             tolower(selecao$sg_subsistema[1L]))
  }
  linhas <- c(
    "# Script reproduzível gerado pelo Navegador de dados do SUS - catálogo multifonte",
    "# Execute a partir da raiz do projeto datasus_navegador.",
    "source(\"R/core.R\")", "source(\"R/ftp_catalog.R\")", "source(\"R/download.R\")", "source(\"R/sigtap.R\")", "source(\"R/economia_saude.R\")", "source(\"R/catalogos_abertos.R\")",
    "dicionarios <- adicionar_dicionario_economia_saude(adicionar_dicionario_sigtap(preparar_dicionarios()))",
    "catalogo <- data.table::as.data.table(readRDS(\"dados_catalogo_ftp/catalogo_ftp_atual.rds\"))",
    "selecao <- data.table::data.table("
  )
  campos <- c("sg_fonte", "no_tema", "sg_conjunto", "no_conjunto", "id_recurso", "no_recurso",
              "ds_formato", "st_processavel", "sg_sistema", "sg_subsistema", "sg_versao", "sg_uf",
              "nu_competencia", "no_dbc_origem", "qt_bytes_ftp", "ds_url")
  campos <- intersect(campos, names(selecao))
  literal <- function(v) {
    if (is.logical(v)) paste(ifelse(is.na(v), "NA", ifelse(v, "TRUE", "FALSE")), collapse = ", ")
    else if (is.numeric(v) || is.integer(v)) paste(ifelse(is.na(v), "NA", format(v, scientific = FALSE, trim = TRUE)), collapse = ", ")
    else paste(vapply(v, function(z) if (is.na(z)) "NA_character_" else encodeString(z, quote = "\""), character(1)), collapse = ", ")
  }
  defs <- vapply(campos, function(j) sprintf("  %s = c(%s)", j, literal(selecao[[j]])), character(1))
  linhas <- c(linhas, paste(defs, collapse = ",\n"), ")",
              sprintf("diretorio_dbc <- path.expand(%s)", encodeString(diretorio_dbc, quote = "\"")),
              "# Reutiliza automaticamente DBC/DBF já presentes na pasta plana acima.",
              sprintf("complementar_pa <- %s", if (complementar_pa) "TRUE" else "FALSE"),
              sprintf("acrescentar_sigtap <- %s", if (acrescentar_sigtap) "TRUE" else "FALSE"),
              "selecao_recursos <- data.table::rbindlist(list(selecao, if (complementar_pa) selecionar_pa_correspondente(selecao, catalogo) else data.table::data.table()), fill = TRUE)",
              "validar_recursos(selecao_recursos, diretorio_dbc)",
              sprintf("dados <- baixar_e_concatenar(selecao, dicionarios, diretorio = diretorio_dbc, usar_atributo_padrao = %s, complementar_pa = complementar_pa, acrescentar_sigtap = acrescentar_sigtap, catalogo = catalogo)",
                      if (usar_atributo_padrao) "TRUE" else "FALSE"),
              sprintf("salvar_dataset(dados, %s, \"rds\")", encodeString(arquivo_saida, quote = "\"")),
              sprintf("message(\"Concluído: %s\")", arquivo_saida))
  paste(linhas, collapse = "\n")
}

validar_recursos <- function(selecao, diretorio = path.expand("~/Downloads/dbc"),
                             fator_descompressao = 12, fracao_memoria = 0.7) {
  dir.create(path.expand(diretorio), recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(path.expand(diretorio), selecao$no_dbc_origem)
  total_entrada <- sum(selecao$qt_bytes_ftp, na.rm = TRUE)
  total_download <- sum(selecao$qt_bytes_ftp[!file.exists(paths)], na.rm = TRUE)
  estimado <- total_entrada * fator_descompressao
  r <- recursos_disponiveis(diretorio)
  if (is.finite(r$memoria_bytes) && estimado > r$memoria_bytes * fracao_memoria)
    stop("Concatenação bloqueada: estimativa descompactada de ", format(estimado, big.mark = ".", decimal.mark = ","),
         " bytes excede ", fracao_memoria * 100, "% da RAM disponível. Divida a seleção por competência/UF.")
  if (is.finite(r$disco_bytes) && total_download > r$disco_bytes)
    stop("Download bloqueado: faltam espaço em disco. Necessário: ", format(total_download, big.mark = ".", decimal.mark = ","), " bytes.")
  invisible(list(compactado = total_entrada, download_pendente = total_download,
                 descompactado_estimado = estimado, recursos = r))
}

validar_espaco_saida <- function(selecao, diretorio_saida, fator_descompressao = 12) {
  dir.create(diretorio_saida, recursive = TRUE, showWarnings = FALSE)
  estimado <- sum(selecao$qt_bytes_ftp, na.rm = TRUE) * fator_descompressao
  disco <- recursos_disponiveis(diretorio_saida)$disco_bytes
  if (is.finite(disco) && estimado > disco)
    stop("Saída bloqueada: a estimativa de ", format(estimado, big.mark = ".", decimal.mark = ","),
         " bytes não cabe no sistema de arquivos de `", diretorio_saida, "`.")
  invisible(estimado)
}

diagnosticar_codigo_saida <- function(status, diretorio_dbc, diretorio_saida = "./data/jobs") {
  if (!identical(as.integer(status), -9L)) return(paste("Processo encerrado com código", status, "."))
  rd <- recursos_disponiveis(diretorio_dbc)
  rs <- recursos_disponiveis(diretorio_saida)
  paste0("Processo encerrado por SIGKILL (-9). Causa mais provável: OOM/falta de RAM ou limite externo do serviço; ",
         "disco cheio normalmente gera erro explícito de escrita. Espaço livre atual: DBC=",
         format(rd$disco_bytes, big.mark = ".", decimal.mark = ","), " bytes; saída=",
         format(rs$disco_bytes, big.mark = ".", decimal.mark = ","), " bytes; RAM disponível após o evento=",
         format(rd$memoria_bytes, big.mark = ".", decimal.mark = ","), " bytes.")
}

projetar_atributos_padrao <- function(dados, dicionarios, selecao) {
  dic <- copy(dicionarios$atributo)
  if (!all(c("no_atributo_padrao", "no_atributo") %in% names(dic))) return(dados)
  sistemas <- unique(selecao$sg_sistema)
  subsistemas <- unique(selecao$sg_subsistema)
  mapa <- dic[sg_sistema %in% sistemas & sg_subsistema %in% subsistemas &
                !is.na(no_atributo_padrao) & nzchar(no_atributo_padrao),
              .(no_atributo, no_atributo_padrao)]
  mapa <- unique(mapa[no_atributo %in% names(dados)])
  # Não destrói atributos originais. Se versões diferentes trouxerem mais de uma
  # origem equivalente, a coluna canônica preserva o primeiro valor preenchido.
  for (padrao in unique(mapa$no_atributo_padrao)) {
    origem <- mapa[no_atributo_padrao == padrao, unique(no_atributo)]
    origem <- intersect(origem, names(dados))
    if (length(origem) && !padrao %in% names(dados)) {
      dados[, (padrao) := get(origem[[1L]])]
      if (length(origem) > 1L) for (j in origem[-1L])
        dados[, (padrao) := coalescer_vetores(get(padrao), get(j))]
    }
  }
  dados
}

salvar_dataset <- function(dados, path, formato = c("rds", "parquet")) {
  formato <- match.arg(formato)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (formato == "rds") saveRDS(dados, path, compress = "xz")
  else {
    if (!requireNamespace("arrow", quietly = TRUE)) stop("Instale arrow para gravar Parquet.")
    arrow::write_parquet(as.data.frame(dados), path)
    saveRDS(list(dictionary = dicionario(dados), code_system = code_systems(dados),
                 files = attr(dados, "datasus_files")), paste0(path, ".metadata.rds"), compress = "xz")
  }
  invisible(path)
}
