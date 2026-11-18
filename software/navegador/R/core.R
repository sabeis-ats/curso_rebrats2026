suppressPackageStartupMessages({
  library(data.table)
  library(curl)
  library(stringr)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x

urls_dicionarios_padrao <- c(
  atributo = "https://raw.githubusercontent.com/LabXiabr/bd_geral/main/td_dicionario_atributo.csv",
  sistema = "https://raw.githubusercontent.com/LabXiabr/bd_geral/main/td_dicionario_sistema.csv",
  subsistema = "https://raw.githubusercontent.com/LabXiabr/bd_geral/main/td_dicionario_subsistema.csv"
)

nomes_sistemas_padrao <- c(
  CIH = "Comunicação de Internação Hospitalar",
  CIHA = "Comunicação de Informação Hospitalar e Ambulatorial",
  CNES = "Cadastro Nacional de Estabelecimentos de Saúde",
  ESUSNOTIFICA = "e-SUS Notifica", PCE = "Programa de Controle da Esquistossomose",
  PNI = "Programa Nacional de Imunizações", RESP = "Sistema de Informação da Rede de Saúde Pública",
  PAINEL_ONCOLOGIA = "Painel de Oncologia",
  SIA = "Sistema de Informações Ambulatoriais", SIH = "Sistema de Informações Hospitalares",
  SIM = "Sistema de Informações sobre Mortalidade", SINAN = "Sistema de Informação de Agravos de Notificação",
  SIGTAP = "Sistema de Gerenciamento da Tabela de Procedimentos, Medicamentos e OPM do SUS",
  BPS = "Banco de Preços em Saúde", CMED = "Câmara de Regulação do Mercado de Medicamentos",
  DADOS_ABERTOS_SUS = "Portal de Dados Abertos do SUS", ANVISA = "Dados Abertos da Anvisa",
  SINASC = "Sistema de Informações sobre Nascidos Vivos", SISCAN = "Sistema de Informação do Câncer",
  SISPRENATAL = "Sistema de Acompanhamento do Programa de Humanização no Pré-Natal e Nascimento"
)

url_ftp_sigtap <- "ftp://ftp2.datasus.gov.br/pub/sistemas/tup/downloads/"

urls_ftp_padrao <- c(
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SINASC/1996_/Dados/DNRES/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIM/CID10/DORES/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIASUS/199407_200712/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIASUS/200801_/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIHSUS/199201_200712/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIHSUS/200801_/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SIM/CID10/DOFET/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SINASC/ANT/DNRES/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SINASC/NOV/DNRES/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SISPRENATAL/201201_/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/CIH/200801_201012/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/CIHA/201101_/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/ESUSNOTIFICA/DADOS/FINAIS/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/painel_oncologia/Dados/",
  sprintf("ftp://ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/%s/",
          c("ST", "DC", "EE", "EF", "EP", "EQ", "GM", "HB", "IN", "LT", "PF", "RC", "SR")),
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SINAN/DADOS/FINAIS/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/PNI/DADOS/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/RESP/DADOS/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/PCE/Dados/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/siscan/SISCOLO4/DADOS/",
  "ftp://ftp.datasus.gov.br/dissemin/publicos/SISCAN/SISMAMA/Dados/"
)

normalizar_nomes <- function(x) {
  x <- normalizar_utf8(x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(gsub("[^A-Za-z0-9]+", "_", x))
  gsub("^_|_$", "", x)
}

normalizar_utf8 <- function(x) {
  if (!is.character(x)) return(x)
  # Mantém UTF-8 válido; tenta Windows-1252 e Latin-1 apenas nos elementos inválidos.
  y <- iconv(x, from = "UTF-8", to = "UTF-8", sub = NA_character_)
  ruins <- is.na(y) & !is.na(x)
  if (any(ruins)) {
    y[ruins] <- iconv(x[ruins], from = "WINDOWS-1252", to = "UTF-8", sub = NA_character_)
  }
  ruins <- is.na(y) & !is.na(x)
  if (any(ruins)) {
    y[ruins] <- iconv(x[ruins], from = "latin1", to = "UTF-8", sub = "")
  }
  y
}

ler_csv_flexivel <- function(path_or_url) {
  dt <- data.table::fread(path_or_url, encoding = "UTF-8", na.strings = c("", "NA", "NULL"),
                          strip.white = TRUE, showProgress = FALSE)
  setnames(dt, names(dt), normalizar_nomes(names(dt)))
  colunas_texto <- names(dt)[vapply(dt, is.character, logical(1))]
  if (length(colunas_texto)) {
    dt[, (colunas_texto) := lapply(.SD, normalizar_utf8), .SDcols = colunas_texto]
  }
  dt[]
}

resolver_fonte <- function(nome, url, diretorio_local = NULL) {
  local <- if (!is.null(diretorio_local)) file.path(diretorio_local, basename(url)) else NA_character_
  if (!is.na(local) && file.exists(local)) return(local)
  url
}

validar_colunas <- function(dt, obrigatorias, nome) {
  faltantes <- setdiff(obrigatorias, names(dt))
  if (length(faltantes)) {
    stop(nome, ": faltam colunas: ", paste(faltantes, collapse = ", "),
         ". Colunas recebidas: ", paste(names(dt), collapse = ", "))
  }
  invisible(dt)
}

canonizar_coluna <- function(dt, destino, aliases, obrigatoria = FALSE, nome_tabela = "tabela") {
  aliases <- unique(normalizar_nomes(c(destino, aliases)))
  encontrada <- intersect(aliases, names(dt))
  if (destino %in% names(dt)) return(invisible(dt))
  if (length(encontrada)) {
    setnames(dt, encontrada[[1L]], destino)
  } else if (obrigatoria) {
    stop(nome_tabela, ": não foi possível identificar `", destino, "`. Colunas recebidas: ",
         paste(names(dt), collapse = ", "))
  }
  invisible(dt)
}

canonizar_esquemas <- function(atributo, sistema, subsistema) {
  aliases_sistema <- c("sistema", "sigla_sistema", "sigla", "co_sistema", "codigo_sistema")
  aliases_subsistema <- c("subsistema", "sigla_subsistema", "co_subsistema", "codigo_subsistema", "prefixo")

  canonizar_coluna(sistema, "sg_sistema", aliases_sistema, TRUE, "sistema")
  canonizar_coluna(sistema, "no_sistema", c("nome_sistema", "nome", "label", "rotulo"), FALSE, "sistema")
  canonizar_coluna(sistema, "ds_sistema", c("descricao_sistema", "descricao"), FALSE, "sistema")
  canonizar_coluna(sistema, "ds_url", c("url", "ftp", "ds_ftp"), FALSE, "sistema")

  canonizar_coluna(subsistema, "sg_sistema", aliases_sistema, TRUE, "subsistema")
  canonizar_coluna(subsistema, "sg_subsistema", aliases_subsistema, TRUE, "subsistema")
  canonizar_coluna(subsistema, "no_subsistema", c("nome_subsistema", "nome", "label", "rotulo"), FALSE, "subsistema")
  canonizar_coluna(subsistema, "ds_subsistema", c("descricao_subsistema", "descricao"), FALSE, "subsistema")
  canonizar_coluna(subsistema, "sg_prefixo", c("prefixo_arquivo", "prefixo"), FALSE, "subsistema")
  canonizar_coluna(subsistema, "ds_url", c("url", "ftp", "ds_ftp"), FALSE, "subsistema")

  canonizar_coluna(atributo, "sg_sistema", aliases_sistema, TRUE, "atributo")
  canonizar_coluna(atributo, "sg_subsistema", aliases_subsistema, TRUE, "atributo")
  canonizar_coluna(atributo, "no_atributo", c("atributo", "nome_atributo", "column_name", "campo"), TRUE, "atributo")
  canonizar_coluna(atributo, "no_rotulo", c("rotulo", "label", "nome_rotulo"), FALSE, "atributo")
  canonizar_coluna(atributo, "ds_atributo", c("descricao_atributo", "descricao"), FALSE, "atributo")
  # A URL pertence ao subsistema/arquivo. Mantê-la por atributo só duplica dados.
  colunas_url_atributo <- intersect(c("ds_url", "url", "ftp", "ds_ftp"), names(atributo))
  if (length(colunas_url_atributo)) atributo[, (colunas_url_atributo) := NULL]
  for (j in c("no_rotulo", "ds_atributo", "no_atributo_padrao", "ds_atributo_padrao")) {
    if (!j %in% names(atributo)) atributo[, (j) := NA_character_]
  }
  list(atributo = atributo, sistema = sistema, subsistema = subsistema)
}

preparar_dicionarios <- function(diretorio_local = NULL,
                                  urls = urls_dicionarios_padrao,
                                  cache = "./dados_catalogo_ftp/dicionarios.rds",
                                  atualizar = FALSE,
                                  path_code_system_overrides = "./config/code_system_overrides.csv") {
  versao_cache <- 3L
  if (!atualizar && file.exists(cache)) {
    anterior <- readRDS(cache)
    if (identical(anterior$metadados$versao_cache, versao_cache)) return(anterior)
    message("Cache de dicionários desatualizado; reconstruindo.")
  }
  dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)

  atributo <- ler_csv_flexivel(resolver_fonte("atributo", urls[["atributo"]], diretorio_local))
  sistema <- ler_csv_flexivel(resolver_fonte("sistema", urls[["sistema"]], diretorio_local))
  subsistema <- ler_csv_flexivel(resolver_fonte("subsistema", urls[["subsistema"]], diretorio_local))

  tabelas <- canonizar_esquemas(atributo, sistema, subsistema)
  atributo <- tabelas$atributo
  sistema <- tabelas$sistema
  subsistema <- tabelas$subsistema

  validar_colunas(atributo, c("sg_sistema", "sg_subsistema", "no_atributo"), "atributo")
  validar_colunas(sistema, "sg_sistema", "sistema")
  validar_colunas(subsistema, c("sg_sistema", "sg_subsistema"), "subsistema")

  for (dt in list(atributo, sistema, subsistema)) {
    dt[, sg_sistema := toupper(trimws(sg_sistema))]
    if ("sg_subsistema" %in% names(dt)) dt[, sg_subsistema := toupper(trimws(sg_subsistema))]
  }
  atributo[, no_atributo := tolower(trimws(no_atributo))]

  setkeyv(sistema, "sg_sistema")
  setkeyv(subsistema, c("sg_sistema", "sg_subsistema"))
  chave_atributo <- intersect(c("sg_sistema", "sg_subsistema", "sg_versao", "no_atributo"), names(atributo))
  setkeyv(atributo, chave_atributo)

  code_system <- extrair_code_systems(atributo)
  if (file.exists(path_code_system_overrides) && file.info(path_code_system_overrides)$size > 0L) {
    override <- ler_csv_flexivel(path_code_system_overrides)
    obrig <- c("sg_sistema", "sg_subsistema", "no_atributo", "co_valor", "no_valor")
    if (all(obrig %in% names(override)) && nrow(override)) {
      override[, `:=`(sg_sistema = toupper(sg_sistema), sg_subsistema = toupper(sg_subsistema),
                      no_atributo = tolower(no_atributo))]
      code_system <- rbindlist(list(code_system, override), fill = TRUE)
      code_system <- unique(code_system, by = c("sg_sistema", "sg_subsistema", "no_atributo", "co_valor"), fromLast = TRUE)
    }
  }
  estrutura <- list(
    sistema = sistema,
    subsistema = subsistema,
    atributo = atributo,
    code_system = code_system,
    metadados = list(dt_criacao = Sys.time(), urls = urls, versao_cache = versao_cache)
  )
  class(estrutura) <- c("datasus_dicionarios", "list")
  saveRDS(estrutura, cache, compress = "xz")
  estrutura
}

extrair_code_systems <- function(atributos) {
  col_desc <- intersect(c("ds_atributo", "ds_atributo_padrao"), names(atributos))
  if (!length(col_desc)) return(data.table())
  x <- copy(atributos)
  x[, texto_codigo := normalizar_utf8(do.call(paste, c(.SD, sep = "; "))), .SDcols = col_desc]
  # Extrai somente pares curtos separados por vírgula, ponto-e-vírgula ou parênteses.
  # Códigos de quatro dígitos (anos) e fragmentos de prosa não viram categorias.
  padrao <- "(?<![[:alnum:]])([A-Za-z0-9]{1,3})\\s*(?:-|=|:)\\s*([^;|,()\\n.]+)"
  x[, pares := str_extract_all(texto_codigo, padrao)]
  x[, n_pares := lengths(pares)]
  enum <- x[n_pares >= 2L]
  if (nrow(enum)) {
    out <- enum[, .(par = unlist(pares)), by = .(sg_sistema, sg_subsistema, no_atributo, no_rotulo)]
    m <- str_match(out$par, padrao)
    out[, `:=`(co_valor = trimws(m[, 2L]),
               no_valor = trimws(gsub("[[:space:]]*[)\\].,;:]+$", "", m[, 3L])))]
    out[, ds_code_system := fifelse(!is.na(no_rotulo) & nzchar(no_rotulo), no_rotulo,
                                    gsub("_", " ", no_atributo))]
    out[, `:=`(tp_code_system = "enumeracao", par = NULL, no_rotulo = NULL)]
    # Remove referências a arquivos DEF e especificações de leiaute confundidas com categorias.
    estrutural <- toupper(out$co_valor) %in% c("DEF", "BPA", "UF", "AA") |
      grepl("APAC_|\\bDEF\\b|\\bCHAR\\b|LEIAUTE|LAYOUT|D[IÍ]GITO|^UNID$|^ANO$|^TIPO$",
            out$no_valor, ignore.case = TRUE)
    out <- unique(out[nzchar(co_valor) & nzchar(no_valor) & !estrutural])
  } else out <- data.table()

  # Campos CID não possuem uma enumeração finita no dicionário local: são referências à CID-10.
  cid <- unique(x[grepl("(^|_)(cid|diag|causa)", no_atributo, ignore.case = TRUE),
                  .(sg_sistema, sg_subsistema, no_atributo,
                    co_valor = NA_character_, no_valor = NA_character_,
                    ds_code_system = "CID-10", tp_code_system = "referencia")])
  unique(rbindlist(list(out, cid), fill = TRUE),
         by = c("sg_sistema", "sg_subsistema", "no_atributo", "co_valor"))
}

rotulo_coluna <- function(dic_atributo) {
  candidatos <- intersect(c("no_rotulo", "no_atributo_padrao", "no_atributo"), names(dic_atributo))
  if (!length(candidatos)) return(rep(NA_character_, nrow(dic_atributo)))
  Reduce(function(a, b) fifelse(!is.na(a) & nzchar(a), a, b), dic_atributo[, ..candidatos])
}

decorar_dataset <- function(dados, dicionarios, sistema, subsistema, versao = NULL) {
  dic <- copy(dicionarios$atributo[sg_sistema == toupper(sistema) &
                                    sg_subsistema == toupper(subsistema)])
  if (!is.null(versao) && "sg_versao" %in% names(dic)) {
    exato <- dic[is.na(sg_versao) | sg_versao == "" | sg_versao == versao]
    if (nrow(exato)) dic <- exato
  }
  dic[, rotulo_exibicao := rotulo_coluna(.SD)]
  dic <- unique(dic, by = "no_atributo")
  setkey(dic, no_atributo)
  valor1 <- function(dt, coluna, padrao = NA_character_) {
    if (!coluna %in% names(dt) || !nrow(dt)) return(padrao)
    x <- dt[[coluna]][1L]
    if (is.na(x) || !nzchar(x)) padrao else x
  }
  for (coluna in intersect(names(dados), dic$no_atributo)) {
    linha <- dic[no_atributo == coluna]
    rotulo <- valor1(linha, "rotulo_exibicao", coluna)
    descricao <- valor1(linha, "ds_atributo_padrao", valor1(linha, "ds_atributo", rotulo))
    attr(dados[[coluna]], "label") <- rotulo
    attr(dados[[coluna]], "description") <- descricao
  }
  attr(dados, "datasus_dictionary") <- dic
  attr(dados, "datasus_code_system") <- dicionarios$code_system[
    sg_sistema == toupper(sistema) & sg_subsistema == toupper(subsistema)
  ]
  class(dados) <- unique(c("datasus_dataset", class(dados)))
  dados
}

print.datasus_dataset <- function(x, ...) {
  NextMethod()
  dic <- attr(x, "datasus_dictionary")
  cat("\nDicionário anexado:", nrow(dic %||% data.table()), "atributos. Use dicionario(x).\n")
  invisible(x)
}

dicionario <- function(x) attr(x, "datasus_dictionary")
code_systems <- function(x) attr(x, "datasus_code_system")

visao_rotulada <- function(x, max_chars = 80L) {
  dic <- dicionario(x)
  if (is.null(dic) || !nrow(dic)) return(data.table(no_atributo = names(x)))
  cols <- intersect(c("no_atributo", "rotulo_exibicao", "ds_atributo_padrao", "ds_atributo"), names(dic))
  ans <- dic[no_atributo %in% names(x), ..cols]
  for (j in intersect(c("ds_atributo_padrao", "ds_atributo"), names(ans))) {
    ans[, (j) := str_trunc(get(j), max_chars)]
  }
  ans[]
}
