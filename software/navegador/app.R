suppressPackageStartupMessages({
  library(shiny)
  library(DT)
  library(data.table)
})
source("R/core.R")
source("R/ftp_catalog.R")
source("R/download.R")
source("R/sigtap.R")
source("R/economia_saude.R")
source("R/catalogos_abertos.R")
source("R/worker.R")

dicionarios <- preparar_dicionarios()
dicionarios <- adicionar_dicionario_sigtap(dicionarios)
dicionarios <- adicionar_dicionario_economia_saude(dicionarios)
path_catalogo <- "./dados_catalogo_ftp/catalogo_ftp_atual.rds"
if (!file.exists(path_catalogo)) stop("Execute Rscript atualizar_catalogo.R antes do Shiny.")
catalogo <- as.data.table(readRDS(path_catalogo))
if (!all(c("sg_fonte", "no_tema", "st_processavel", "st_url_direta") %in% names(catalogo)))
  stop("Catálogo de versão anterior. Execute novamente: Rscript atualizar_catalogo.R")

nome_sistema <- function(sigla) {
  dt <- dicionarios$sistema[sg_sistema == sigla]
  col <- intersect(c("no_sistema", "ds_sistema"), names(dt))[1L]
  valor <- if (!is.na(col) && nrow(dt)) dt[[col]][1L] else NA_character_
  if (is.na(valor) || !nzchar(valor)) valor <- unname(nomes_sistemas_padrao[sigla])
  if (is.na(valor) || !nzchar(valor)) sigla else paste(sigla, valor, sep = " - ")
}
nome_subsistema <- function(sistema, sigla) {
  dt <- dicionarios$subsistema[sg_sistema == sistema & sg_subsistema == sigla]
  col <- intersect(c("no_subsistema", "ds_subsistema"), names(dt))[1L]
  valor <- if (!is.na(col) && nrow(dt)) dt[[col]][1L] else NA_character_
  if (is.na(valor) || !nzchar(valor)) sigla else paste(sigla, valor, sep = " - ")
}

ui <- fluidPage(
  tags$head(tags$script(HTML("Shiny.addCustomMessageHandler('statusProcessamento', function(x) { document.getElementById('status_execucao').textContent = x; });"))),
  titlePanel("Navegador de dados do SUS - catálogo multifonte"),
  sidebarLayout(
    sidebarPanel(
      selectInput("fonte", "Fonte", choices = sort(unique(catalogo$sg_fonte))),
      uiOutput("ui_tema"), uiOutput("ui_sistema"),
      uiOutput("ui_subsistema"), uiOutput("ui_uf"), uiOutput("ui_competencias"),
      textInput("diretorio_dbc", "Pasta de cache dos arquivos no servidor R", value = "~/Downloads/dbc"),
      checkboxInput("padronizar", "Criar colunas padronizadas sem remover as originais", FALSE),
      uiOutput("ui_complementar_pa"),
      uiOutput("ui_acrescentar_sigtap"),
      actionButton("selecionar_todos", "Selecionar todos os filtrados"),
      actionButton("processar", "Baixar e concatenar", class = "btn-primary"),
      downloadButton("baixar_bruto", "Baixar recurso bruto"),
      actionButton("cancelar", "Cancelar processamento"),
      uiOutput("ui_downloads"),
      tags$hr(), tags$b("Execução:"), tags$pre(id = "status_execucao", "Aguardando seleção.",
                                                style = "white-space:pre-wrap; max-height:220px; overflow-y:auto;")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Arquivos", DTOutput("arquivos")),
        tabPanel("Atributos", DTOutput("atributos")),
        tabPanel("Code systems", DTOutput("codes")),
        tabPanel("Script R", downloadButton("baixar_script", "Baixar script R"),
                 verbatimTextOutput("script_r")),
        tabPanel("Resultado", verbatimTextOutput("resumo"),
                 tags$p(tags$em("Pré-visualização limitada às primeiras 1.000 linhas; os arquivos baixados contêm o resultado completo.")),
                 DTOutput("amostra"))
      )
    )
  )
)

server <- function(input, output, session) {
  fonte_base <- reactive({ req(input$fonte); catalogo[sg_fonte == input$fonte] })
  output$ui_tema <- renderUI({
    temas <- sort(unique(na.omit(fonte_base()$no_tema)))
    if (!length(temas)) return(NULL)
    selectInput("tema", "Tema", choices = c("Todos" = "", temas), selected = "")
  })
  tema_base <- reactive({
    x <- fonte_base()
    if (!is.null(input$tema) && nzchar(input$tema) && any(grepl(input$tema, x$no_tema, fixed = TRUE)))
      x <- x[grepl(input$tema, no_tema, fixed = TRUE)]
    x
  })
  output$ui_sistema <- renderUI({
    s <- sort(unique(tema_base()$sg_sistema))
    selectInput("sistema", "Sistema / catálogo", choices = setNames(s, vapply(s, nome_sistema, character(1))))
  })
  output$ui_subsistema <- renderUI({
    req(input$sistema)
    s <- sort(unique(tema_base()[sg_sistema == input$sistema, sg_subsistema]))
    selectInput("subsistema", "Subsistema", choices = setNames(s, vapply(s, function(z) nome_subsistema(input$sistema, z), character(1))))
  })
  base <- reactive({ req(input$sistema, input$subsistema); tema_base()[sg_sistema == input$sistema & sg_subsistema == input$subsistema] })
  output$ui_uf <- renderUI({
    u <- sort(unique(na.omit(base()$sg_uf)))
    selectInput("uf", "UF de processamento", choices = c("Todas" = "", u), selected = "")
  })
  output$ui_competencias <- renderUI({
    comp <- sort(unique(na.omit(base()$nu_competencia)))
    if (!length(comp)) return(NULL)
    tags$div(
      selectInput("competencia_ini", "Competência inicial (AAAAMM)", choices = comp, selected = min(comp)),
      selectInput("competencia_fim", "Competência final (AAAAMM)", choices = comp, selected = max(comp))
    )
  })
  output$ui_complementar_pa <- renderUI({
    if (identical(input$sistema, "SIA") && input$subsistema %in% subsistemas_sia_com_pa)
      checkboxInput("complementar_pa", "Complementar cada UF/competência com o PA correspondente", FALSE)
  })
  output$ui_acrescentar_sigtap <- renderUI({
    if (identical(input$sistema, "BPS"))
      checkboxInput("acrescentar_sigtap", "Acrescentar candidato SIGTAP (grupo 06, vínculo unívoco)", FALSE)
  })
  filtrado <- reactive({
    x <- copy(base())
    if (!is.null(input$uf) && nzchar(input$uf)) x <- x[sg_uf == input$uf]
    if (!is.null(input$competencia_ini) && !is.null(input$competencia_fim))
      x <- x[nu_competencia >= as.integer(input$competencia_ini) & nu_competencia <= as.integer(input$competencia_fim)]
    x
  })
  output$arquivos <- renderDT(datatable(filtrado(), selection = "multiple", filter = "top",
                                         options = list(pageLength = 15, scrollX = TRUE)))
  observeEvent(input$selecionar_todos, {
    proxy <- dataTableProxy("arquivos")
    selectRows(proxy, seq_len(nrow(filtrado())))
  })
  output$atributos <- renderDT({
    x <- dicionarios$atributo[sg_sistema == input$sistema & sg_subsistema == input$subsistema]
    datatable(x, filter = "top", options = list(pageLength = 15, scrollX = TRUE))
  })
  output$codes <- renderDT({
    x <- dicionarios$code_system[sg_sistema == input$sistema & sg_subsistema == input$subsistema]
    datatable(x, filter = "top", options = list(pageLength = 15, scrollX = TRUE))
  })
  resultado <- reactiveVal(NULL)
  resumo_resultado <- reactiveVal(NULL)
  path_resultado <- reactiveVal(NULL)
  processo <- reactiveVal(NULL)
  info_job <- reactiveVal(NULL)
  observeEvent(TRUE, {
    query <- shiny::parseQueryString(session$clientData$url_search %||% "")
    id <- query$job %||% ""
    if (grepl("^[0-9]{8}_[0-9]{6}_[0-9]+_[0-9]+$", id)) {
      base <- normalizePath(file.path("data/jobs", paste0(id, "_resultado.rds")), mustWork = FALSE)
      info_job(list(id = id, log = normalizePath(file.path("data/jobs", paste0(id, ".log")), mustWork = FALSE),
                    output = base))
    }
  }, once = TRUE)
  selecao_atual <- reactive({
    idx <- input$arquivos_rows_selected
    if (!length(idx)) idx <- seq_len(nrow(filtrado()))
    filtrado()[idx]
  })
  output$baixar_bruto <- downloadHandler(
    filename = function() {
      x <- selecao_atual()
      if (nrow(x) != 1L) return("selecione_um_recurso.txt")
      x$no_dbc_origem[1L]
    },
    content = function(file) {
      x <- selecao_atual()
      if (nrow(x) != 1L) stop("Selecione exatamente um recurso na aba Arquivos.")
      url <- if (isTRUE(x$st_url_direta[1L])) x$ds_url[1L] else
        paste0(normalizar_url_ftp(x$ds_url[1L]), x$no_dbc_origem[1L])
      curl::curl_download(url, file, quiet = FALSE, mode = "wb")
    }
  )
  script_atual <- reactive({
    gerar_script_download(selecao_atual(), usar_atributo_padrao = isTRUE(input$padronizar),
                          complementar_pa = isTRUE(input$complementar_pa),
                          acrescentar_sigtap = isTRUE(input$acrescentar_sigtap),
                          diretorio_dbc = input$diretorio_dbc %||% "~/Downloads/dbc")
  })
  output$script_r <- renderText(script_atual())
  output$baixar_script <- downloadHandler(
    filename = function() sprintf("baixar_%s_%s.R", tolower(input$sistema), tolower(input$subsistema)),
    content = function(file) writeLines(script_atual(), file, useBytes = TRUE)
  )
  observeEvent(input$processar, {
    if (!is.null(processo()) && processo()$is_alive()) {
      showNotification("Já existe um processamento em execução.", type = "warning")
      return()
    }
    sel <- selecao_atual()
    tryCatch({
      if (any(!sel$st_processavel %in% TRUE))
        stop("A seleção contém recurso não tabular. Selecione um arquivo e use 'Baixar recurso bruto'.")
      dir.create("./data/jobs", recursive = TRUE, showWarnings = FALSE)
      id <- paste(format(Sys.time(), "%Y%m%d_%H%M%S"), Sys.getpid(), sample.int(999999L, 1L), sep = "_")
      path_sel <- normalizePath(file.path("data/jobs", paste0(id, "_selecao.rds")), mustWork = FALSE)
      path_out <- normalizePath(file.path("data/jobs", paste0(id, "_resultado.rds")), mustWork = FALSE)
      path_log <- normalizePath(file.path("data/jobs", paste0(id, ".log")), mustWork = FALSE)
      saveRDS(sel, path_sel)
      incluir_pa <- isTRUE(input$complementar_pa) && input$sistema == "SIA" &&
        input$subsistema %in% subsistemas_sia_com_pa
      total_sel <- rbindlist(list(sel, if (incluir_pa) selecionar_pa_correspondente(sel, catalogo) else data.table()), fill = TRUE)
      validar_recursos(total_sel, input$diretorio_dbc)
      validar_espaco_saida(sel, "./data/jobs")
      p <- callr::r_bg(executar_job_download,
        args = list(projeto = normalizePath("."), path_selecao = path_sel,
                    path_catalogo = normalizePath(path_catalogo), path_resultado = path_out,
                    diretorio_dbc = path.expand(input$diretorio_dbc),
                    usar_atributo_padrao = isTRUE(input$padronizar), complementar_pa = incluir_pa,
                    acrescentar_sigtap = isTRUE(input$acrescentar_sigtap)),
        stdout = path_log, stderr = "2>&1", supervise = FALSE)
      processo(p)
      info_job(list(id = id, log = path_log, output = path_out))
      updateQueryString(paste0("?job=", id), mode = "replace", session = session)
      resultado(NULL); resumo_resultado(NULL); path_resultado(NULL)
      session$sendCustomMessage("statusProcessamento",
        paste("PROCESSO INICIADO EM SEGUNDO PLANO", "Job:", id,
              "A tela pode permanecer aberta durante a execução.", sep = "\n"))
    }, error = function(e) {
      session$sendCustomMessage("statusProcessamento", paste("ERRO:", conditionMessage(e)))
      showNotification(conditionMessage(e), type = "error", duration = NULL)
    })
  })
  monitor <- reactiveTimer(1000, session)
  observe({
    monitor()
    p <- processo(); info <- info_job()
    if (is.null(info)) return()
    linhas <- if (file.exists(info$log)) tail(readLines(info$log, warn = FALSE), 30L) else "Aguardando saída do processo..."
    session$sendCustomMessage("statusProcessamento", paste(c(paste("Job:", info$id), linhas), collapse = "\n"))
    vivo <- !is.null(p) && p$is_alive()
    artefatos <- c(info$output, paste0(info$output, ".preview.rds"), paste0(info$output, ".summary.rds"))
    pronto <- all(file.exists(artefatos))
    if (!vivo && pronto && is.null(path_resultado())) {
      path_resultado(info$output)
      resultado(readRDS(paste0(info$output, ".preview.rds")))
      resumo_resultado(readRDS(paste0(info$output, ".summary.rds")))
      showNotification("Processamento concluído. Downloads liberados.", type = "message")
      processo(NULL)
    } else if (!vivo && !is.null(p) && !pronto) {
      status <- p$get_exit_status(); processo(NULL)
      diagnostico <- if (identical(status, 0L))
        paste("O processo terminou com código 0, mas não produziu todos os artefatos esperados:",
              paste(basename(artefatos[!file.exists(artefatos)]), collapse = ", "))
      else diagnosticar_codigo_saida(status, input$diretorio_dbc, dirname(info$output))
      session$sendCustomMessage("statusProcessamento", paste(c(linhas, "", diagnostico), collapse = "\n"))
      showNotification(diagnostico, type = "error", duration = NULL)
    }
  })
  observeEvent(input$cancelar, {
    p <- processo()
    if (!is.null(p) && p$is_alive()) {
      p$kill(); processo(NULL)
      session$sendCustomMessage("statusProcessamento", "Processamento cancelado pelo usuário.")
    }
  })
  output$resumo <- renderPrint({
    x <- resumo_resultado(); req(x)
    cat("Linhas:", x$n_linhas, " Colunas:", x$n_colunas, "\n")
    print(x$visao)
  })
  output$amostra <- renderDT({ x <- resultado(); req(x); datatable(head(x, 1000), options = list(scrollX = TRUE)) })
  output$ui_downloads <- renderUI({
    req(resultado())
    botoes <- list(
      downloadButton("baixar_rds", "Baixar RDS completo"),
      downloadButton("baixar_csv", "Baixar CSV.gz completo")
    )
    if (requireNamespace("arrow", quietly = TRUE)) {
      botoes <- c(botoes, list(downloadButton("baixar_parquet", "Baixar Parquet completo")))
    } else {
      botoes <- c(botoes, list(tags$small("Parquet indisponível: instale o pacote R 'arrow'.")))
    }
    tags$div(style = "display:flex; flex-wrap:wrap; gap:6px; margin-top:8px;", botoes)
  })
  nome_base_resultado <- reactive({
    z <- resumo_resultado()
    if (is.null(z)) return(sprintf("%s_%s", tolower(input$sistema), tolower(input$subsistema)))
    sprintf("%s_%s", tolower(z$sg_sistema), tolower(z$sg_subsistema))
  })
  output$baixar_rds <- downloadHandler(
    filename = function() paste0(nome_base_resultado(), ".rds"),
    content = function(file) { origem <- path_resultado(); req(origem); file.copy(origem, file, overwrite = TRUE) }
  )
  output$baixar_csv <- downloadHandler(
    filename = function() paste0(nome_base_resultado(), ".csv.gz"),
    content = function(file) {
      origem <- path_resultado(); req(origem); x <- readRDS(origem)
      data.table::fwrite(x, file, compress = "gzip", bom = TRUE)
    }
  )
  output$baixar_parquet <- downloadHandler(
    filename = function() paste0(nome_base_resultado(), ".parquet"),
    content = function(file) {
      origem <- path_resultado(); req(origem); x <- readRDS(origem)
      if (!requireNamespace("arrow", quietly = TRUE)) stop("Instale o pacote arrow para exportar Parquet.")
      arrow::write_parquet(as.data.frame(x), file, compression = "zstd")
    }
  )
}

shinyApp(ui, server)
