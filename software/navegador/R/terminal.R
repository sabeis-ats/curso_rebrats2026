suppressPackageStartupMessages(library(data.table))

ler_terminal <- function(prompt = "") {
  if (interactive()) return(readline(prompt))
  cat(prompt)
  flush.console()
  resposta <- readLines(con = stdin(), n = 1L, warn = FALSE)
  if (!length(resposta)) stop("Entrada encerrada pelo usuário.")
  resposta[[1L]]
}

escolher_um <- function(rotulo, valores) {
  valores <- sort(unique(na.omit(valores)))
  if (!length(valores)) stop("Sem opções para ", rotulo)
  cat("\n", rotulo, ":\n", sep = "")
  cat(sprintf("  %d) %s\n", seq_along(valores), valores))
  repeat {
    i <- suppressWarnings(as.integer(ler_terminal(sprintf("Escolha [1-%d] (0 cancela): ", length(valores)))))
    if (!is.na(i) && i == 0L) stop("Operação cancelada.")
    if (!is.na(i) && i >= 1L && i <= length(valores)) return(valores[[i]])
    cat("Opção inválida.\n")
  }
}

perguntar_sim_nao <- function(texto, padrao = TRUE) {
  sufixo <- if (padrao) " [S/n]: " else " [s/N]: "
  x <- tolower(trimws(ler_terminal(paste0(texto, sufixo))))
  if (!nzchar(x)) return(padrao)
  startsWith(x, "s")
}

escolher_diretorio_dbc <- function(padrao = "~/Downloads/dbc") {
  padrao <- path.expand(padrao)
  if (dir.exists(padrao) && perguntar_sim_nao(paste0("Usar o diretório existente `", padrao, "`?"), TRUE))
    return(normalizePath(padrao))
  repeat {
    novo <- trimws(ler_terminal(paste0("Novo diretório DBC/DBF [", padrao, "]: ")))
    if (!nzchar(novo)) novo <- padrao
    novo <- path.expand(novo)
    if (dir.exists(novo)) return(normalizePath(novo))
    if (perguntar_sim_nao(paste0("O diretório `", novo, "` não existe. Criar?"), TRUE)) {
      dir.create(novo, recursive = TRUE, showWarnings = FALSE)
      if (dir.exists(novo)) return(normalizePath(novo))
      cat("Não foi possível criar o diretório.\n")
    }
  }
}

navegar_terminal <- function(path_catalogo = "./dados_catalogo_ftp/catalogo_ftp_atual.rds",
                              dicionarios = adicionar_dicionario_economia_saude(
                                adicionar_dicionario_sigtap(preparar_dicionarios()))) {
  if (!file.exists(path_catalogo)) {
    message("Catálogo não encontrado; iniciando a coleta FTP.")
    catalogo <- atualizar_catalogo_ftp(dicionarios = dicionarios, diretorio = dirname(path_catalogo))
  } else {
    catalogo <- as.data.table(readRDS(path_catalogo))
  }
  if (!all(c("sg_fonte", "no_tema", "st_processavel", "st_url_direta") %in% names(catalogo)))
    stop("Catálogo de versão anterior. Execute novamente: Rscript atualizar_catalogo.R")
  fonte <- escolher_um("Fonte", catalogo$sg_fonte)
  x <- catalogo[sg_fonte == fonte]
  temas <- sort(unique(na.omit(x$no_tema)))
  if (length(temas) && perguntar_sim_nao("Filtrar por tema?", TRUE)) {
    tema <- escolher_um("Tema", temas)
    x <- x[grepl(tema, no_tema, fixed = TRUE)]
  }
  sistema <- escolher_um("Sistema / catálogo", x$sg_sistema)
  x <- x[sg_sistema == sistema]
  subsistema <- escolher_um("Subsistema", x$sg_subsistema)
  x <- x[sg_subsistema == subsistema]
  ufs <- sort(unique(na.omit(x$sg_uf)))
  if (length(ufs) && perguntar_sim_nao("Filtrar por UF de processamento?", FALSE)) {
    uf <- escolher_um("UF de processamento", ufs)
    x <- x[sg_uf == uf]
  }
  competencias <- sort(unique(na.omit(x$nu_competencia)))
  if (length(competencias)) {
    ini <- suppressWarnings(as.integer(ler_terminal(sprintf("Competência inicial AAAAMM [%d]: ", min(competencias)))))
    fim <- suppressWarnings(as.integer(ler_terminal(sprintf("Competência final AAAAMM [%d]: ", max(competencias)))))
    if (is.na(ini)) ini <- min(competencias)
    if (is.na(fim)) fim <- max(competencias)
    x <- x[nu_competencia >= ini & nu_competencia <= fim]
  }
  print(x[, .(sg_fonte, no_tema, no_conjunto, sg_sistema, sg_subsistema, sg_uf,
               nu_competencia, no_recurso, ds_formato, st_processavel, qt_bytes_ftp)])
  if (any(!x$st_processavel %in% TRUE)) {
    if (!perguntar_sim_nao(sprintf("A seleção contém recurso não tabular. Baixar %d arquivo(s) sem concatenar?", nrow(x))))
      return(invisible(x))
    diretorio <- escolher_diretorio_dbc()
    paths <- vapply(seq_len(nrow(x)), function(i) {
      url <- if (isTRUE(x$st_url_direta[i])) x$ds_url[i] else paste0(normalizar_url_ftp(x$ds_url[i]), x$no_dbc_origem[i])
      baixar_arquivo(url, file.path(diretorio, x$no_dbc_origem[i]))
    }, character(1))
    cat("Arquivos salvos em:", diretorio, "\n")
    return(invisible(paths))
  }
  if (!perguntar_sim_nao(sprintf("Baixar e concatenar %d arquivo(s)?", nrow(x)))) return(invisible(x))
  padrao <- perguntar_sim_nao("Criar também colunas com nomes padronizados?", FALSE)
  complementar_pa <- sistema == "SIA" && subsistema %in% subsistemas_sia_com_pa &&
    perguntar_sim_nao("Complementar cada UF/competência com o PA correspondente?", FALSE)
  acrescentar_sigtap <- sistema == "BPS" &&
    perguntar_sim_nao("Acrescentar candidato SIGTAP do grupo 06 quando o vínculo for unívoco?", FALSE)
  diretorio_dbc <- escolher_diretorio_dbc()
  selecao_recursos <- rbindlist(list(x, if (complementar_pa) selecionar_pa_correspondente(x, catalogo) else data.table()), fill = TRUE)
  validar_recursos(selecao_recursos, diretorio_dbc)
  dados <- baixar_e_concatenar(x, dicionarios, diretorio = diretorio_dbc,
                              usar_atributo_padrao = padrao, complementar_pa = complementar_pa,
                              acrescentar_sigtap = acrescentar_sigtap,
                              catalogo = catalogo, progresso = function(msg) {
                                cat("\n========== ", msg, " ==========\n", sep = "")
                              })
  formato <- escolher_um("Formato de saída", c("rds", "parquet"))
  ext <- if (formato == "rds") "rds" else "parquet"
  path <- file.path("dados_saida", sprintf("%s_%s.%s", tolower(sistema), tolower(subsistema), ext))
  salvar_dataset(dados, path, formato)
  cat("Salvo em:", normalizePath(path), "\n")
  cat("Use visao_rotulada(dados), dicionario(dados) e code_systems(dados).\n")
  invisible(dados)
}
