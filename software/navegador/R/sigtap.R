suppressPackageStartupMessages(library(data.table))

especificacoes_sigtap <- list(
  tb_procedimento = list(
    widths = c(10, 250, 1, 1, 4, 4, 4, 4, 4, 10, 10, 10, 2, 6, 4, 6),
    names = c("co_procedimento", "no_procedimento", "tp_complexidade", "tp_sexo",
              "qt_maxima_execucao", "qt_dias_permanencia", "qt_pontos",
              "vl_idade_minima", "vl_idade_maxima", "vl_sh", "vl_sa", "vl_sp",
              "co_financiamento", "co_rubrica", "qt_tempo_permanencia", "dt_competencia")),
  tb_descricao = list(c(10, 4000, 6), c("co_procedimento", "ds_procedimento", "dt_competencia")),
  tb_financiamento = list(c(2, 100, 6), c("co_financiamento", "no_financiamento", "dt_competencia")),
  tb_rubrica = list(c(6, 100, 6), c("co_rubrica", "no_rubrica", "dt_competencia")),
  tb_grupo = list(c(2, 100, 6), c("co_grupo", "no_grupo", "dt_competencia")),
  tb_sub_grupo = list(c(2, 2, 100, 6), c("co_grupo", "co_sub_grupo", "no_sub_grupo", "dt_competencia")),
  tb_forma_organizacao = list(c(2, 2, 2, 100, 6), c("co_grupo", "co_sub_grupo", "co_forma_organizacao", "no_forma_organizacao", "dt_competencia")),
  tb_modalidade = list(c(2, 100, 6), c("co_modalidade", "no_modalidade", "dt_competencia")),
  rl_procedimento_modalidade = list(c(10, 2, 6), c("co_procedimento", "co_modalidade", "dt_competencia")),
  tb_registro = list(c(2, 50, 6), c("co_registro", "no_registro", "dt_competencia")),
  rl_procedimento_registro = list(c(10, 2, 6), c("co_procedimento", "co_registro", "dt_competencia")),
  rl_procedimento_origem = list(c(10, 10, 6), c("co_procedimento", "co_procedimento_origem", "dt_competencia")),
  tb_ocupacao = list(c(6, 150), c("co_ocupacao", "no_ocupacao")),
  rl_procedimento_ocupacao = list(c(10, 6, 6), c("co_procedimento", "co_ocupacao", "dt_competencia")),
  tb_servico = list(c(3, 120, 6), c("co_servico", "no_servico", "dt_competencia")),
  tb_servico_classificacao = list(c(3, 3, 150, 6), c("co_servico", "co_classificacao", "no_classificacao", "dt_competencia")),
  rl_procedimento_servico = list(c(10, 3, 3, 6), c("co_procedimento", "co_servico", "co_classificacao", "dt_competencia")),
  tb_detalhe = list(c(3, 100, 6), c("co_detalhe", "no_detalhe", "dt_competencia")),
  rl_procedimento_detalhe = list(c(10, 3, 6), c("co_procedimento", "co_detalhe", "dt_competencia"))
)

localizar_txt_sigtap <- function(zip, nome) {
  lista <- utils::unzip(zip, list = TRUE)$Name
  alvo <- lista[tolower(basename(lista)) == paste0(tolower(nome), ".txt")]
  if (length(alvo)) alvo[[1L]] else NA_character_
}

ler_layout_sigtap <- function(zip, nome, exdir) {
  interno <- localizar_txt_sigtap(zip, paste0(nome, "_layout"))
  if (is.na(interno)) return(NULL)
  utils::unzip(zip, files = interno, exdir = exdir, overwrite = TRUE)
  layout <- utils::read.csv(file.path(exdir, interno), fileEncoding = "latin1",
                            stringsAsFactors = FALSE, check.names = FALSE)
  names(layout) <- normalizar_nomes(names(layout))
  if (!all(c("coluna", "tamanho") %in% names(layout))) return(NULL)
  list(widths = as.integer(layout$tamanho), names = tolower(trimws(layout$coluna)),
       types = toupper(trimws(layout$tipo %||% rep("VARCHAR2", nrow(layout)))))
}

ler_txt_sigtap <- function(zip, nome, exdir, obrigatorio = FALSE) {
  spec <- ler_layout_sigtap(zip, nome, exdir) %||% especificacoes_sigtap[[nome]]
  interno <- localizar_txt_sigtap(zip, nome)
  if (is.null(spec) || is.na(interno)) {
    if (obrigatorio) stop("Arquivo obrigatório ausente no ZIP SIGTAP: ", nome, ".txt")
    return(data.table())
  }
  utils::unzip(zip, files = interno, exdir = exdir, overwrite = TRUE)
  path <- file.path(exdir, interno)
  widths <- spec[["widths"]] %||% spec[[1L]]
  nomes <- spec[["names"]] %||% spec[[2L]]
  # read.fwf/read.table interpreta conteúdo de descrições como separadores e pode
  # falhar em linhas longas. Os arquivos são posicionais: corta cada linha pelas larguras.
  linhas <- readLines(path, encoding = "latin1", warn = FALSE, skipNul = TRUE)
  linhas <- linhas[nzchar(linhas)]
  inicios <- cumsum(c(1L, head(widths, -1L)))
  finais <- cumsum(widths)
  colunas <- Map(function(a, b) trimws(substr(linhas, a, b)), inicios, finais)
  x <- setDT(setNames(as.data.frame(colunas, stringsAsFactors = FALSE), nomes))
  x[, (names(x)) := lapply(.SD, normalizar_utf8)][]
}

formatar_procedimento_sigtap <- function(x) {
  x <- trimws(as.character(x))
  i <- nchar(x) < 10L
  x[i] <- paste0(strrep("0", 10L - nchar(x[i])), x[i])
  paste0(substr(x, 1, 2), ".", substr(x, 3, 4), ".", substr(x, 5, 6), ".",
         substr(x, 7, 9), "-", substr(x, 10, 10))
}

agregar_relacao_sigtap <- function(rel, dimensao = NULL, chaves_dim = NULL,
                                   colunas_valor, nome_saida) {
  if (!nrow(rel)) return(data.table())
  x <- copy(rel)
  if (!is.null(dimensao) && nrow(dimensao))
    x <- merge(x, dimensao, by = chaves_dim, all.x = TRUE, allow.cartesian = TRUE)
  x[, valor_agregado := do.call(paste, c(lapply(.SD, function(z) fifelse(is.na(z), "", z)), sep = " - ")),
    .SDcols = colunas_valor]
  x[, valor_agregado := gsub("(^[ -]+|[ -]+$)", "", valor_agregado)]
  out <- x[nzchar(valor_agregado), .(valor = paste(sort(unique(valor_agregado)), collapse = "; ")),
           by = .(co_procedimento, dt_competencia)]
  setnames(out, "valor", nome_saida)
  out
}

consolidar_zip_sigtap <- function(zip, competencia = NA_integer_, progresso = message) {
  exdir <- tempfile("sigtap_txt_")
  dir.create(exdir, recursive = TRUE)
  on.exit(unlink(exdir, recursive = TRUE, force = TRUE), add = TRUE)
  ler <- function(nome, obrigatorio = FALSE) {
    progresso(paste("SIGTAP: lendo", paste0(nome, ".txt")))
    z <- ler_txt_sigtap(zip, nome, exdir, obrigatorio)
    if ("dt_competencia" %in% names(z)) z[, dt_competencia := as.integer(dt_competencia)]
    z
  }
  proc <- ler("tb_procedimento", TRUE)
  proc[, co_procedimento := trimws(co_procedimento)]
  if (is.finite(competencia)) proc[is.na(dt_competencia), dt_competencia := competencia]
  proc[, `:=`(co_grupo = substr(co_procedimento, 1, 2),
              co_sub_grupo = substr(co_procedimento, 3, 4),
              co_forma_organizacao = substr(co_procedimento, 5, 6),
              co_procedimento_formatado = formatar_procedimento_sigtap(co_procedimento))]
  proc[, no_complexidade := fcase(tp_complexidade == "1", "AB - Atenção Básica",
                                  tp_complexidade == "2", "MC - Média complexidade",
                                  tp_complexidade == "3", "AC - Alta complexidade",
                                  default = tp_complexidade)]
  proc[, no_sexo := fcase(tp_sexo == "M", "M - Masculino", tp_sexo == "F", "F - Feminino",
                          tp_sexo == "I", "F/M", default = tp_sexo)]
  numericas <- intersect(c("qt_maxima_execucao", "qt_dias_permanencia", "qt_pontos",
                           "vl_idade_minima", "vl_idade_maxima", "qt_tempo_permanencia"), names(proc))
  proc[, (numericas) := lapply(.SD, as.numeric), .SDcols = numericas]
  for (j in intersect(c("vl_sh", "vl_sa", "vl_sp"), names(proc)))
    proc[, (j) := round(as.numeric(get(j)) / 100, 2)]
  proc[, `:=`(vl_total_ambulatorial = round(vl_sa, 2),
              vl_total_hospitalar = round(vl_sh + vl_sp, 2))]

  desc <- ler("tb_descricao")
  financ <- ler("tb_financiamento"); rubrica <- ler("tb_rubrica")
  grupo <- ler("tb_grupo"); subgrupo <- ler("tb_sub_grupo"); forma <- ler("tb_forma_organizacao")
  proc <- merge(proc, desc, by = c("co_procedimento", "dt_competencia"), all.x = TRUE)
  proc <- merge(proc, financ[, .(co_financiamento, dt_competencia = as.integer(dt_competencia), no_financiamento)],
                by = c("co_financiamento", "dt_competencia"), all.x = TRUE)
  proc <- merge(proc, rubrica[, .(co_rubrica, dt_competencia = as.integer(dt_competencia), no_rubrica)],
                by = c("co_rubrica", "dt_competencia"), all.x = TRUE)
  proc <- merge(proc, grupo[, .(co_grupo, dt_competencia = as.integer(dt_competencia), no_grupo)],
                by = c("co_grupo", "dt_competencia"), all.x = TRUE)
  proc <- merge(proc, subgrupo[, .(co_grupo, co_sub_grupo, dt_competencia = as.integer(dt_competencia), no_sub_grupo)],
                by = c("co_grupo", "co_sub_grupo", "dt_competencia"), all.x = TRUE)
  proc <- merge(proc, forma[, .(co_grupo, co_sub_grupo, co_forma_organizacao,
                                dt_competencia = as.integer(dt_competencia), no_forma_organizacao)],
                by = c("co_grupo", "co_sub_grupo", "co_forma_organizacao", "dt_competencia"), all.x = TRUE)

  rels <- list()
  mod <- ler("tb_modalidade"); rel <- ler("rl_procedimento_modalidade")
  rels[["ds_modalidades"]] <- agregar_relacao_sigtap(rel, mod, c("co_modalidade", "dt_competencia"),
                                                      c("co_modalidade", "no_modalidade"), "ds_modalidades")
  reg <- ler("tb_registro"); rel <- ler("rl_procedimento_registro")
  rels[["ds_instrumentos_registro"]] <- agregar_relacao_sigtap(rel, reg, c("co_registro", "dt_competencia"),
                                                               c("co_registro", "no_registro"), "ds_instrumentos_registro")
  rel <- ler("rl_procedimento_origem")
  rels[["co_procedimentos_origem"]] <- agregar_relacao_sigtap(rel, NULL, NULL,
                                                              "co_procedimento_origem", "co_procedimentos_origem")
  cbo <- ler("tb_ocupacao"); rel <- ler("rl_procedimento_ocupacao")
  rels[["ds_cbo"]] <- agregar_relacao_sigtap(rel, cbo, "co_ocupacao",
                                              c("co_ocupacao", "no_ocupacao"), "ds_cbo")
  serv <- ler("tb_servico"); clas <- ler("tb_servico_classificacao"); rel <- ler("rl_procedimento_servico")
  if (nrow(rel)) {
    dim_serv <- merge(serv, clas, by = c("co_servico", "dt_competencia"), all = TRUE)
    rels[["ds_servico_classificacao"]] <- agregar_relacao_sigtap(rel, dim_serv,
      c("co_servico", "co_classificacao", "dt_competencia"),
      c("co_servico", "co_classificacao", "no_servico", "no_classificacao"), "ds_servico_classificacao")
  }
  det <- ler("tb_detalhe"); rel <- ler("rl_procedimento_detalhe")
  rels[["ds_detalhes"]] <- agregar_relacao_sigtap(rel, det, c("co_detalhe", "dt_competencia"),
                                                   c("co_detalhe", "no_detalhe"), "ds_detalhes")
  if (nrow(rel)) {
    flags <- unique(rel[, .(co_procedimento, dt_competencia, co_detalhe, valor = TRUE)])
    flags <- dcast(flags, co_procedimento + dt_competencia ~ co_detalhe,
                   value.var = "valor", fill = FALSE)
    col_flags <- setdiff(names(flags), c("co_procedimento", "dt_competencia"))
    setnames(flags, col_flags, paste0("st_detalhe_", tolower(col_flags)))
    proc <- merge(proc, flags, by = c("co_procedimento", "dt_competencia"), all.x = TRUE)
  }
  cid <- ler("tb_cid"); rel_cid <- ler("rl_procedimento_cid")
  if (nrow(rel_cid)) {
    cid[, co_cid_formatado := fifelse(nchar(co_cid) == 4L,
      paste0(substr(co_cid, 1L, 3L), ".", substr(co_cid, 4L, 4L)), co_cid)]
    rels[["ds_cid"]] <- agregar_relacao_sigtap(rel_cid, cid, "co_cid",
      c("co_cid_formatado", "no_cid"), "ds_cid")
  }
  leito <- ler("tb_tipo_leito"); rel_leito <- ler("rl_procedimento_leito")
  rels[["ds_tipos_leito"]] <- agregar_relacao_sigtap(rel_leito, leito,
    c("co_tipo_leito", "dt_competencia"), c("co_tipo_leito", "no_tipo_leito"), "ds_tipos_leito")
  sia_sih <- ler("tb_sia_sih"); rel_sia_sih <- ler("rl_procedimento_sia_sih")
  rels[["ds_procedimentos_origem_sia_sih"]] <- agregar_relacao_sigtap(rel_sia_sih, sia_sih,
    c("co_procedimento_sia_sih", "tp_procedimento", "dt_competencia"),
    c("tp_procedimento", "co_procedimento_sia_sih", "no_procedimento_sia_sih"),
    "ds_procedimentos_origem_sia_sih")
  for (z in rels) if (nrow(z)) {
    z[, dt_competencia := as.integer(dt_competencia)]
    proc <- merge(proc, z, by = c("co_procedimento", "dt_competencia"), all.x = TRUE)
  }
  detalhes_nomeados <- c(st_inclui_anestesia = "001", st_admite_longa_permanencia = "003",
                         st_admite_permanencia_maior = "004", st_cnrac = "006",
                         st_cirurgia_eletiva = "044")
  for (j in names(detalhes_nomeados)) {
    origem <- paste0("st_detalhe_", detalhes_nomeados[[j]])
    proc[, (j) := if (origem %in% names(proc)) fifelse(is.na(get(origem)), FALSE, get(origem)) else FALSE]
  }
  setcolorder(proc, c("dt_competencia", "co_procedimento", "co_procedimento_formatado",
                      "no_procedimento", "ds_procedimento", "co_grupo", "no_grupo",
                      "co_sub_grupo", "no_sub_grupo", "co_forma_organizacao",
                      "no_forma_organizacao", setdiff(names(proc), c("dt_competencia", "co_procedimento",
                      "co_procedimento_formatado", "no_procedimento", "ds_procedimento", "co_grupo", "no_grupo",
                      "co_sub_grupo", "no_sub_grupo", "co_forma_organizacao", "no_forma_organizacao"))))
  unique(proc, by = c("dt_competencia", "co_procedimento"))
}

baixar_consolidar_sigtap <- function(selecao, diretorio, sobrescrever = FALSE, progresso = message) {
  partes <- vector("list", nrow(selecao))
  for (i in seq_len(nrow(selecao))) {
    r <- selecao[i]
    progresso(sprintf("[SIGTAP %d/%d] %s", i, nrow(selecao), r$no_dbc_origem))
    zip <- baixar_arquivo(paste0(normalizar_url_ftp(r$ds_url), r$no_dbc_origem),
                          file.path(path.expand(diretorio), r$no_dbc_origem), sobrescrever)
    partes[[i]] <- consolidar_zip_sigtap(zip, r$nu_competencia, progresso)
    partes[[i]][, .arquivo_origem := r$no_dbc_origem]
  }
  out <- rbindlist(partes, fill = TRUE, use.names = TRUE)
  setorder(out, dt_competencia, co_procedimento)
  for (j in intersect(c("vl_sh", "vl_sa", "vl_sp", "vl_total_ambulatorial",
                        "vl_total_hospitalar"), names(out))) {
    attr(out[[j]], "units") <- "BRL"
    attr(out[[j]], "label") <- paste0(j, " (R$)")
  }
  out[]
}

adicionar_dicionario_sigtap <- function(dicionarios) {
  if (!"SIGTAP" %in% dicionarios$sistema$sg_sistema)
    dicionarios$sistema <- rbindlist(list(dicionarios$sistema,
      data.table(sg_sistema = "SIGTAP", no_sistema = nomes_sistemas_padrao[["SIGTAP"]])), fill = TRUE)
  if (!any(dicionarios$subsistema$sg_sistema == "SIGTAP"))
    dicionarios$subsistema <- rbindlist(list(dicionarios$subsistema,
      data.table(sg_sistema = "SIGTAP", sg_subsistema = "PROCEDIMENTO",
                 no_subsistema = "Tabela unificada por procedimento", ds_url = url_ftp_sigtap)), fill = TRUE)
  campos <- c("co_procedimento", "no_procedimento", "ds_procedimento", "co_grupo", "no_grupo",
              "co_sub_grupo", "no_sub_grupo", "co_forma_organizacao", "no_forma_organizacao",
              "tp_complexidade", "no_complexidade", "tp_sexo", "no_sexo",
              "vl_sh", "vl_sa", "vl_sp", "vl_total_ambulatorial",
              "vl_total_hospitalar", "ds_modalidades", "ds_instrumentos_registro", "ds_cbo",
              "ds_servico_classificacao", "ds_detalhes", "ds_cid", "ds_tipos_leito",
              "co_procedimentos_origem", "ds_procedimentos_origem_sia_sih",
              "st_inclui_anestesia", "st_admite_longa_permanencia",
              "st_admite_permanencia_maior", "st_cnrac", "st_cirurgia_eletiva")
  novos <- data.table(sg_sistema = "SIGTAP", sg_subsistema = "PROCEDIMENTO",
                      no_atributo = campos, no_rotulo = gsub("_", " ", campos),
                      ds_atributo = gsub("_", " ", campos))
  novos[no_atributo == "co_procedimento", `:=`(
    no_atributo_padrao = "co_procedimento",
    ds_atributo_padrao = "Código SIGTAP do procedimento")]
  novos[no_atributo %chin% c("vl_sh", "vl_sa", "vl_sp", "vl_total_ambulatorial",
                              "vl_total_hospitalar"), `:=`(
    no_rotulo = paste0(toupper(no_atributo), " (R$)"),
    ds_atributo = "Valor monetário em reais, armazenado como número com duas casas decimais")]
  dicionarios$atributo <- unique(rbindlist(list(dicionarios$atributo, novos), fill = TRUE),
                                   by = c("sg_sistema", "sg_subsistema", "no_atributo"))
  dicionarios
}
