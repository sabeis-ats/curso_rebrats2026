executar_job_download <- function(projeto, path_selecao, path_catalogo, path_resultado,
                                  diretorio_dbc, usar_atributo_padrao, complementar_pa,
                                  acrescentar_sigtap = FALSE) {
  setwd(projeto)
  source("R/core.R")
  source("R/ftp_catalog.R")
  source("R/download.R")
  source("R/sigtap.R")
  source("R/economia_saude.R")
  source("R/catalogos_abertos.R")
  selecao <- data.table::as.data.table(readRDS(path_selecao))
  catalogo <- data.table::as.data.table(readRDS(path_catalogo))
  dicionarios <- preparar_dicionarios()
  dicionarios <- adicionar_dicionario_sigtap(dicionarios)
  dicionarios <- adicionar_dicionario_economia_saude(dicionarios)
  progresso <- function(msg) message(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", msg)
  validar_recursos(rbindlist(list(selecao,
    if (isTRUE(complementar_pa)) selecionar_pa_correspondente(selecao, catalogo) else data.table()), fill = TRUE),
    diretorio_dbc)
  validar_espaco_saida(selecao, dirname(path_resultado))
  dados <- baixar_e_concatenar(selecao, dicionarios, diretorio = diretorio_dbc,
                               usar_atributo_padrao = usar_atributo_padrao,
                               complementar_pa = complementar_pa, acrescentar_sigtap = acrescentar_sigtap,
                               catalogo = catalogo,
                               progresso = progresso)
  saveRDS(dados, path_resultado, compress = "xz")
  saveRDS(head(dados, 1000L), paste0(path_resultado, ".preview.rds"), compress = "gzip")
  saveRDS(list(n_linhas = nrow(dados), n_colunas = ncol(dados),
               sg_sistema = unique(selecao$sg_sistema)[1L],
               sg_subsistema = unique(selecao$sg_subsistema)[1L],
               visao = visao_rotulada(dados)), paste0(path_resultado, ".summary.rds"))
  writeLines("concluido", paste0(path_resultado, ".done"))
  message("RESULTADO_CONCLUIDO: ", path_resultado)
  invisible(path_resultado)
}
