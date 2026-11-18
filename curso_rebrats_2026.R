# ==============================================================================
# Curso ReBrATS 2026 — acesso aos dados da SABEIS com R
# ==============================================================================
# Funções utilizadas por curso_rebrats2026.Rmd. O fluxo é executável com ou sem
# acesso ao SFTP: SFTP -> espelho HTTPS -> cache local -> exemplo reprodutível.
# ==============================================================================

opcoes_rebrats <- list(
  sftp = list(
    host = "45.231.133.29",
    porta = 7891L,
    usuario = "livre",
    senha = "12345",
    diretorio = "/srv/ftp/dadosabertos/",
    url = "sftp://45.231.133.29:7891/srv/ftp/dadosabertos/",
    userpwd = "livre:12345"
  ),
  espelho_https = "https://dados.labx.ia.br/files/sabeis/",
  pcdt = paste0(
    "https://raw.githubusercontent.com/sabeis-ats/bd_geral/",
    "main/td_diretriz_cnv.csv"
  ),
  dicionario_sia = paste0(
    "ftp://ftp.datasus.gov.br/dissemin/publicos/SIASUS/200801_/Doc/",
    "Informe_Tecnico_SIASUS_2019_07.pdf"
  )
)

pacotes_rebrats <- c("curl", "data.table", "ggplot2", "knitr", "rmarkdown")

verificar_pacotes <- function(instalar = FALSE) {
  faltantes <- pacotes_rebrats[
    !vapply(pacotes_rebrats, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(faltantes) && instalar) {
    install.packages(faltantes, repos = "https://cloud.r-project.org")
    faltantes <- pacotes_rebrats[
      !vapply(pacotes_rebrats, requireNamespace, logical(1), quietly = TRUE)
    ]
  }
  if (length(faltantes)) {
    stop(
      "Pacotes ausentes: ", paste(faltantes, collapse = ", "),
      ". Execute o bloco de instalação antes de compilar.", call. = FALSE
    )
  }
  invisible(TRUE)
}

arquivo_valido <- function(caminho, tamanho_minimo = 1L) {
  file.exists(caminho) && is.finite(file.info(caminho)$size) &&
    file.info(caminho)$size >= tamanho_minimo
}

normalizar_listagem <- function(x) {
  x <- trimws(x)
  x <- x[nzchar(x)]
  x <- basename(sub("^.*[[:space:]]", "", x))
  unique(x[grepl("\\.csv\\.gz$", x, ignore.case = TRUE)])
}

listar_sabeis_sftp <- function(timeout = 12L) {
  if (!requireNamespace("curl", quietly = TRUE)) {
    stop("O pacote curl não está instalado.", call. = FALSE)
  }
  versao <- curl::curl_version()
  if (!"sftp" %in% versao$protocols) {
    stop("A libcurl desta instalação não oferece o protocolo SFTP.", call. = FALSE)
  }
  handle <- curl::new_handle(
    userpwd = opcoes_rebrats$sftp$userpwd,
    dirlistonly = TRUE,
    connecttimeout = timeout,
    timeout = timeout,
    noproxy = "*"
  )
  conexao <- curl::curl(opcoes_rebrats$sftp$url, handle = handle)
  on.exit(close(conexao), add = TRUE)
  normalizar_listagem(readLines(conexao, warn = FALSE, encoding = "UTF-8"))
}

listar_sabeis_https <- function(timeout = 20L) {
  if (!requireNamespace("curl", quietly = TRUE)) {
    stop("O pacote curl não está instalado.", call. = FALSE)
  }
  resposta <- curl::curl_fetch_memory(
    opcoes_rebrats$espelho_https,
    handle = curl::new_handle(connecttimeout = timeout, timeout = timeout)
  )
  if (resposta$status_code >= 400L) {
    stop("O espelho HTTPS respondeu com status ", resposta$status_code, ".")
  }
  pagina <- rawToChar(resposta$content)
  ocorrencias <- regmatches(
    pagina,
    gregexpr(
      "[[:alnum:]_.-]+\\.csv\\.gz", pagina,
      perl = TRUE, ignore.case = TRUE
    )
  )[[1]]
  normalizar_listagem(ocorrencias)
}

listar_sabeis_cache <- function(
    diretorios = c("dados_sabeis", "dados", "cache")) {
  existentes <- diretorios[dir.exists(diretorios)]
  if (!length(existentes)) return(character())
  arquivos <- unlist(lapply(
    existentes,
    list.files,
    pattern = "\\.csv\\.gz$",
    recursive = TRUE,
    full.names = FALSE,
    ignore.case = TRUE
  ), use.names = FALSE)
  normalizar_listagem(arquivos)
}

arquivos_exemplo_rebrats <- function() {
  c(
    "tf_sia_202401_pa_058_fen_subgrupo604.20261118.2880.csv.gz",
    "tf_sia_202401_pa_050_epi_subgrupo604.20261118.2880.csv.gz",
    "tf_sia_202401_pa_041_crn_subgrupo604.20261118.2880.csv.gz"
  )
}

listar_arquivos_sabeis <- function(
    tentar_sftp = TRUE,
    diretorios_cache = c("dados_sabeis", "dados", "cache")) {
  tentativas <- list()
  resumir_tentativas <- function(x) {
    data.table::rbindlist(lapply(x, function(item) {
      data.table::data.table(
        ok = item$ok,
        rota = item$rota,
        erro = item$erro
      )
    }), fill = TRUE)
  }
  registrar <- function(rota, expressao) {
    tryCatch({
      arquivos <- expressao()
      if (!length(arquivos)) stop("nenhum csv.gz localizado")
      list(ok = TRUE, rota = rota, arquivos = arquivos, erro = NA_character_)
    }, error = function(e) {
      list(
        ok = FALSE, rota = rota, arquivos = character(),
        erro = conditionMessage(e)
      )
    })
  }
  if (isTRUE(tentar_sftp)) {
    tentativas[[length(tentativas) + 1L]] <- registrar(
      "SFTP SABEIS", listar_sabeis_sftp
    )
  }
  tentativas[[length(tentativas) + 1L]] <- registrar(
    "espelho HTTPS", listar_sabeis_https
  )
  tentativas[[length(tentativas) + 1L]] <- registrar(
    "cache local", function() listar_sabeis_cache(diretorios_cache)
  )
  for (resultado in tentativas) {
    if (isTRUE(resultado$ok)) {
      return(list(
        arquivos = resultado$arquivos,
        fonte = resultado$rota,
        tentativas = resumir_tentativas(tentativas)
      ))
    }
  }
  exemplo <- list(
    ok = TRUE, rota = "exemplo reprodutível",
    arquivos = arquivos_exemplo_rebrats(), erro = NA_character_
  )
  tentativas[[length(tentativas) + 1L]] <- exemplo
  list(
    arquivos = exemplo$arquivos,
    fonte = exemplo$rota,
    tentativas = resumir_tentativas(tentativas)
  )
}

interpretar_nome_sabeis <- function(nomes) {
  modelo <- data.frame(
    sistema = character(),
    competencia_inicial = character(),
    arquivo_sia = character(),
    nu_diretriz = character(),
    sg_pcdt = character(),
    recorte = character(),
    data_geracao_chr = character(),
    qt_registro_chr = character(),
    stringsAsFactors = FALSE
  )
  partes <- strcapture(
    pattern = paste0(
      "^tf_([^_]+)_([0-9]{6})_([^_]+)_([0-9]{3})_",
      "([^_]+)_(.+)\\.([0-9]{8})\\.([0-9]+)\\.csv\\.gz$"
    ),
    x = tolower(basename(nomes)),
    proto = modelo,
    perl = TRUE
  )
  partes$no_arquivo <- basename(nomes)
  partes$sg_pcdt <- toupper(partes$sg_pcdt)
  partes$data_geracao <- as.Date(partes$data_geracao_chr, format = "%Y%m%d")
  partes$qt_registro <- suppressWarnings(as.integer(partes$qt_registro_chr))
  partes$nome_valido <- !is.na(partes$sistema) & !is.na(partes$qt_registro)
  partes[c(
    "no_arquivo", "nome_valido", "sistema", "competencia_inicial",
    "arquivo_sia", "nu_diretriz", "sg_pcdt", "recorte",
    "data_geracao", "qt_registro"
  )]
}

selecionar_coorte <- function(catalogo, limite_registros = 20000L) {
  candidatos <- catalogo[
    catalogo$nome_valido & !is.na(catalogo$qt_registro) &
      catalogo$qt_registro > 0 &
      catalogo$qt_registro <= limite_registros,
    , drop = FALSE
  ]
  if (!nrow(candidatos)) {
    candidatos <- interpretar_nome_sabeis(arquivos_exemplo_rebrats()[1])
  }
  candidatos <- candidatos[order(candidatos$qt_registro, candidatos$no_arquivo), ]
  candidatos[1, , drop = FALSE]
}

baixar_atomico <- function(url, destino, handle = NULL, timeout = 180L) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  temporario <- paste0(destino, ".part")
  if (file.exists(temporario)) unlink(temporario)
  if (is.null(handle)) {
    handle <- curl::new_handle(connecttimeout = 20L, timeout = timeout)
  }
  curl::curl_download(
    url, temporario, mode = "wb", quiet = TRUE, handle = handle
  )
  if (!arquivo_valido(temporario)) {
    stop("O download não produziu um arquivo válido.", call. = FALSE)
  }
  if (file.exists(destino)) unlink(destino)
  if (!file.rename(temporario, destino)) {
    stop("Não foi possível concluir o download atômico.", call. = FALSE)
  }
  normalizePath(destino, winslash = "/", mustWork = TRUE)
}

gerar_dados_exemplo <- function() {
  meses <- format(
    seq(as.Date("2024-01-01"), by = "month", length.out = 24L), "%Y%m"
  )
  n_mes <- 120L
  indice <- seq_len(length(meses) * n_mes)
  dentro_mes <- rep(seq_len(n_mes), times = length(meses))
  data.table::data.table(
    nu_competencia = rep(meses, each = n_mes),
    sg_uf = rep(c("MG", "SP", "BA", "RS"), length.out = length(indice)),
    nu_apac = sprintf("%013.0f", 9000000000000 + indice),
    co_procedimento = rep(
      c("0604380011", "0604320159"), length.out = length(indice)
    ),
    co_cnes_estabelecimento = sprintf(
      "%07d", 1000000 + rep(seq_len(24L), length.out = length(indice))
    ),
    qt_aprovada = 1L + (dentro_mes %% 4L),
    vl_aprovado = round(12.5 + (dentro_mes %% 15L) * 2.1, 2),
    nu_cnspcn = sprintf(
      "%015.0f",
      700000000000000 + rep(seq_len(72L), length.out = length(indice))
    ),
    sg_sexo = rep(c("F", "M"), length.out = length(indice)),
    co_cidpri = "E700",
    no_origem = "PA"
  )
}

escrever_csv_gz <- function(dados, destino) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  conexao <- gzfile(destino, open = "wt", encoding = "UTF-8")
  on.exit(close(conexao), add = TRUE)
  utils::write.csv(dados, conexao, row.names = FALSE, na = "")
  invisible(normalizePath(destino, winslash = "/", mustWork = TRUE))
}

localizar_cache <- function(
    nome, diretorios = c("dados_sabeis", "dados", "cache")) {
  existentes <- diretorios[dir.exists(diretorios)]
  if (!length(existentes)) return(NA_character_)
  candidatos <- unlist(lapply(existentes, function(pasta) {
    arquivos <- list.files(
      pasta, pattern = "\\.csv\\.gz$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE
    )
    arquivos[tolower(basename(arquivos)) == tolower(basename(nome))]
  }), use.names = FALSE)
  if (length(candidatos)) candidatos[[1]] else NA_character_
}

obter_coorte_sabeis <- function(
    nome_arquivo,
    tentar_sftp = TRUE,
    diretorio = "dados_sabeis") {
  destino <- file.path(diretorio, basename(nome_arquivo))
  if (arquivo_valido(destino)) {
    return(list(caminho = normalizePath(destino), fonte = "cache local"))
  }
  erros <- character()
  if (isTRUE(tentar_sftp)) {
    resultado <- tryCatch({
      handle <- curl::new_handle(
        userpwd = opcoes_rebrats$sftp$userpwd,
        connecttimeout = 15L, timeout = 180L, noproxy = "*"
      )
      caminho <- baixar_atomico(
        paste0(opcoes_rebrats$sftp$url, basename(nome_arquivo)),
        destino, handle = handle
      )
      list(caminho = caminho, fonte = "SFTP SABEIS")
    }, error = function(e) {
      erros <<- c(erros, paste("SFTP:", conditionMessage(e)))
      NULL
    })
    if (!is.null(resultado)) return(resultado)
  }
  resultado <- tryCatch({
    caminho <- baixar_atomico(
      paste0(
        opcoes_rebrats$espelho_https,
        utils::URLencode(basename(nome_arquivo), reserved = TRUE)
      ),
      destino
    )
    list(caminho = caminho, fonte = "espelho HTTPS")
  }, error = function(e) {
    erros <<- c(erros, paste("HTTPS:", conditionMessage(e)))
    NULL
  })
  if (!is.null(resultado)) return(resultado)
  cache <- localizar_cache(nome_arquivo)
  if (!is.na(cache) && arquivo_valido(cache)) {
    return(list(caminho = normalizePath(cache), fonte = "cache local"))
  }
  dados <- gerar_dados_exemplo()
  destino_exemplo <- file.path(diretorio, arquivos_exemplo_rebrats()[1])
  escrever_csv_gz(dados, destino_exemplo)
  list(
    caminho = normalizePath(destino_exemplo),
    fonte = "exemplo reprodutível",
    erros = erros
  )
}

ler_csv_sabeis <- function(caminho) {
  resultado <- tryCatch(
    data.table::fread(
      caminho, colClasses = "character",
      na.strings = c("", "NA", "NULL"), encoding = "UTF-8",
      showProgress = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(resultado)) {
    conexao <- gzfile(caminho, open = "rt", encoding = "UTF-8")
    on.exit(close(conexao), add = TRUE)
    resultado <- data.table::as.data.table(utils::read.csv(
      conexao, colClasses = "character", check.names = FALSE,
      na.strings = c("", "NA", "NULL")
    ))
  }
  data.table::setnames(resultado, tolower(names(resultado)))
  resultado
}

perfil_dados <- function(dados) {
  data.table::data.table(
    coluna = names(dados),
    classe = vapply(
      dados, function(x) paste(class(x), collapse = "/"), character(1)
    ),
    ausentes = vapply(
      dados, function(x) sum(is.na(x) | x == ""), integer(1)
    ),
    distintos = vapply(dados, data.table::uniqueN, integer(1))
  )
}

validar_contagem <- function(dados, metadados, fonte) {
  esperado <- metadados$qt_registro[[1]]
  observado <- nrow(dados)
  data.table::data.table(
    arquivo = basename(metadados$no_arquivo[[1]]),
    fonte = fonte,
    registros_declarados = esperado,
    registros_observados = observado,
    diferenca = observado - esperado,
    contagem_confere = as.integer(observado) == as.integer(esperado)
  )
}

carregar_pcdt <- function(
    caminho_local = "dados/td_diretriz_cnv.csv",
    url = opcoes_rebrats$pcdt) {
  fonte <- caminho_local
  tabela <- NULL
  if (arquivo_valido(caminho_local)) {
    tabela <- data.table::fread(caminho_local, colClasses = "character")
  } else {
    tabela <- tryCatch(
      data.table::fread(url, colClasses = "character", encoding = "UTF-8"),
      error = function(e) NULL
    )
    if (!is.null(tabela)) {
      dir.create(dirname(caminho_local), recursive = TRUE, showWarnings = FALSE)
      data.table::fwrite(tabela, caminho_local, bom = TRUE)
      fonte <- url
    }
  }
  if (is.null(tabela)) {
    tabela <- data.table::data.table(
      nu_diretriz = "058", no_diretriz = "Fenilcetonúria",
      co_cid = "E700,E701", sg_pcdt = "FEN",
      no_diretriz10 = "Fenilceton", sg_tipo = "pcdt",
      ds_url = NA_character_, ds_publicacao = NA_character_
    )
    fonte <- "registro mínimo incorporado ao script"
  }
  data.table::setnames(tabela, tolower(names(tabela)))
  tabela[, nu_diretriz := sprintf(
    "%03d", suppressWarnings(as.integer(gsub("[^0-9]", "", nu_diretriz)))
  )]
  if ("sg_pcdt" %in% names(tabela)) tabela[, sg_pcdt := toupper(sg_pcdt)]
  attr(tabela, "fonte") <- fonte
  tabela
}

enriquecer_catalogo_pcdt <- function(catalogo, pcdt) {
  data.table::merge.data.table(
    data.table::as.data.table(catalogo), data.table::copy(pcdt),
    by = c("nu_diretriz", "sg_pcdt"),
    all.x = TRUE, sort = FALSE
  )
}

normalizar_codigo_sigtap <- function(x) {
  digitos <- gsub("[^0-9]", "", as.character(x))
  vapply(digitos, function(codigo) {
    if (is.na(codigo) || !nzchar(codigo) || nchar(codigo) > 10L) {
      return(NA_character_)
    }
    paste0(strrep("0", 10L - nchar(codigo)), codigo)
  }, character(1), USE.NAMES = FALSE)
}

decompor_codigo_sigtap <- function(x) {
  codigo <- normalizar_codigo_sigtap(x)
  data.table::data.table(
    co_procedimento = codigo,
    grupo = substr(codigo, 1L, 2L),
    subgrupo = substr(codigo, 3L, 4L),
    forma_organizacao = substr(codigo, 5L, 6L),
    sequencial = substr(codigo, 7L, 9L),
    digito_verificador = substr(codigo, 10L, 10L)
  )
}

tabela_subsistemas_sia <- function() {
  data.table::data.table(
    sigla = c(
      "AB", "ABO", "ACF", "AD", "AM", "AMP", "AN", "AQ", "AR",
      "ATD", "BI", "PA", "PS", "SAD"
    ),
    nome = c(
      "Laudo de Acompanhamento à Cirurgia Bariátrica",
      "Acompanhamento Pós-Cirurgia Bariátrica",
      "Laudo de Confecção de Fístula",
      "Laudos Diversos",
      "Laudo de Medicamentos",
      "Laudo de Acompanhamento Multiprofissional",
      "Laudo de Nefrologia",
      "Laudo de Quimioterapia",
      "Laudo de Radioterapia",
      "Laudo de Tratamento Dialítico",
      "Boletim Individual",
      "Produção Ambulatorial",
      "Psicossocial",
      "Atenção Domiciliar"
    ),
    papel_sabeis = c(
      rep("outra tabela disseminada do SIA", 4L),
      "fonte de enriquecimento do PA",
      "outra tabela disseminada do SIA",
      rep("fonte de enriquecimento do PA", 3L),
      "outra tabela disseminada do SIA",
      "fonte de enriquecimento do PA",
      "tabela-alvo de produção",
      "fonte de enriquecimento do PA",
      "outra tabela disseminada do SIA"
    )
  )
}

enriquecer_pa_com_apac <- function(pa, auxiliares) {
  pa <- data.table::as.data.table(data.table::copy(pa))
  auxiliares <- data.table::rbindlist(auxiliares, fill = TRUE, use.names = TRUE)
  chaves <- c(
    "nu_competencia", "sg_uf", "co_cnes_estabelecimento", "nu_apac"
  )
  faltantes <- setdiff(c(chaves, "nu_cnspcn"), names(auxiliares))
  if (length(faltantes)) {
    stop(
      "Campos ausentes nas tabelas auxiliares: ",
      paste(faltantes, collapse = ", ")
    )
  }
  aux_cns <- auxiliares[
    !is.na(nu_cnspcn) & nzchar(nu_cnspcn),
    .(nu_cnspcn = nu_cnspcn[1L]),
    by = chaves
  ]
  pa[aux_cns, on = chaves, nu_cnspcn := i.nu_cnspcn]
  pa
}

baixar_dicionario_sia <- function(
    destino = "documentacao/Informe_Tecnico_SIASUS_2019_07.pdf",
    sobrescrever = FALSE,
    timeout = 45L) {
  if (arquivo_valido(destino, 1024L) && !sobrescrever) {
    return(data.table::data.table(
      status = "já existia", url = opcoes_rebrats$dicionario_sia,
      arquivo = normalizePath(destino), bytes = file.info(destino)$size
    ))
  }
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  urls <- c(
    opcoes_rebrats$dicionario_sia,
    sub("^ftp://", "https://", opcoes_rebrats$dicionario_sia)
  )
  erros <- character()
  for (url in urls) {
    temporario <- paste0(destino, ".part")
    if (file.exists(temporario)) unlink(temporario)
    ok <- tryCatch({
      antigo <- getOption("timeout")
      options(timeout = max(antigo, timeout))
      utils::download.file(url, temporario, mode = "wb", quiet = TRUE)
      options(timeout = antigo)
      cabecalho <- readBin(temporario, what = "raw", n = 5L)
      pdf <- identical(rawToChar(cabecalho), "%PDF-")
      if (!pdf || !arquivo_valido(temporario, 1024L)) {
        stop("resposta recebida não é um PDF válido")
      }
      if (file.exists(destino)) unlink(destino)
      file.rename(temporario, destino)
    }, error = function(e) {
      erros <<- c(erros, paste(url, conditionMessage(e), sep = " — "))
      FALSE
    })
    if (isTRUE(ok)) {
      return(data.table::data.table(
        status = "baixado", url = url,
        arquivo = normalizePath(destino), bytes = file.info(destino)$size
      ))
    }
  }
  data.table::data.table(
    status = "não baixado; compilação mantida",
    url = opcoes_rebrats$dicionario_sia,
    arquivo = destino,
    bytes = NA_real_,
    detalhe = paste(erros, collapse = " | ")
  )
}

preparar_dados_sia <- function(dados) {
  x <- data.table::as.data.table(data.table::copy(dados))
  data.table::setnames(x, tolower(names(x)))
  obrigatorios <- c("nu_competencia", "nu_cnspcn", "co_procedimento")
  faltantes <- setdiff(obrigatorios, names(x))
  if (length(faltantes)) {
    stop("Campos necessários ausentes: ", paste(faltantes, collapse = ", "))
  }
  x[, nu_competencia := sprintf(
    "%06d", suppressWarnings(as.integer(nu_competencia))
  )]
  x[, mes := as.Date(paste0(nu_competencia, "01"), format = "%Y%m%d")]
  x[, co_procedimento := normalizar_codigo_sigtap(co_procedimento)]
  if ("qt_aprovada" %in% names(x)) {
    x[, qt_aprovada_num := suppressWarnings(
      as.numeric(gsub(",", ".", qt_aprovada, fixed = TRUE))
    )]
  } else {
    x[, qt_aprovada_num := 1]
  }
  x
}

resumir_demanda <- function(dados) {
  x <- preparar_dados_sia(dados)
  x[
    !is.na(mes) & !is.na(nu_cnspcn) & nzchar(nu_cnspcn),
    .(
      usuarios_distintos = data.table::uniqueN(nu_cnspcn),
      registros = .N,
      quantidade_aprovada = sum(qt_aprovada_num, na.rm = TRUE)
    ),
    by = mes
  ][order(mes)]
}

resumir_pos_incorporacao <- function(dados) {
  x <- preparar_dados_sia(dados)
  x[
    !is.na(mes) & !is.na(nu_cnspcn) & nzchar(nu_cnspcn) &
      qt_aprovada_num > 0,
    .(
      usuarios_distintos = data.table::uniqueN(nu_cnspcn),
      quantidade_aprovada = sum(qt_aprovada_num, na.rm = TRUE)
    ),
    by = .(mes, co_procedimento)
  ][order(mes, co_procedimento)]
}
