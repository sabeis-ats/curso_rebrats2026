# Dados Abertos do SUS — edição 2026

Livro online e material do **Curso ReBrATS 2026 — Dados da SABEIS via FTP
utilizando a Linguagem R**.

- Repositório: <https://github.com/sabeis-ats/curso_rebrats2026>
- Livro: <https://sabeis-ats.github.io/curso_rebrats2026/>
- Aula R executada: <https://sabeis-ats.github.io/curso_rebrats2026/curso/>

## Curso ReBrATS 2026

- **Data:** 18 de novembro de 2026
- **Horário:** 8h às 12h30
- **Local:** sala 109
- **Docentes:** Felipe Ferré e Mariá Pereira
- **Nível:** intermediário

Arquivos principais:

| Arquivo | Finalidade |
|:--|:--|
| [`curso_rebrats2026.Rmd`](curso_rebrats2026.Rmd) | aula completa, tabelas e gráficos |
| [`curso_rebrats_2026.R`](curso_rebrats_2026.R) | funções de aquisição, validação e análise |
| [`dados/td_diretriz_cnv.csv`](dados/td_diretriz_cnv.csv) | lista incorporada de PCDT e diretrizes |
| [`PUBLICAR_GITHUB_PAGES.md`](PUBLICAR_GITHUB_PAGES.md) | configuração e publicação no GitHub Pages |

O Rmd tenta, nesta ordem, SFTP da SABEIS, espelho HTTPS, cache local e exemplo
reprodutível. A falha do SFTP não impede a criação das tabelas nem dos três
gráficos da aula.

## Conteúdo da aula

1. natureza da SABEIS, do SIA e dos eventos administrativos;
2. acesso público ao SFTP com `livre:12345`;
3. rotas alternativas e registro da fonte efetivamente usada;
4. gramática dos nomes e catálogo de coortes;
5. lista `td_diretriz_cnv.csv` como dimensão de PCDT e diretrizes;
6. download atômico, leitura de `csv.gz` e controles de qualidade;
7. Informe Técnico SIA/SUS de julho de 2019 como dicionário de dados;
8. relação das tabelas/subsistemas do SIA;
9. enriquecimento de SIA/PA com AM, AN, AQ, AR, BI e PS;
10. natureza mensal do SIGTAP, taxonomia e código `2–2–2–3–1`;
11. demanda aferida e avaliação pós-incorporação;
12. compilação no RStudio e publicação no GitHub Pages.

## Executar a aula

No RStudio, abra `curso_rebrats2026.Rmd` e use **Knit**. Pelo console:

```r
pacotes <- c("curl", "data.table", "ggplot2", "knitr", "rmarkdown")
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes)) install.packages(faltantes)

rmarkdown::render(
  "curso_rebrats2026.Rmd",
  params = list(
    tentar_sftp = TRUE,
    baixar_dicionario = FALSE,
    limite_registros = 20000
  )
)
```

Para uma compilação totalmente independente do SFTP:

```r
rmarkdown::render(
  "curso_rebrats2026.Rmd",
  params = list(tentar_sftp = FALSE)
)
```

## Conteúdo do livro

- 7 partes e 49 capítulos em Quarto Markdown;
- 7 apêndices;
- oito materiais RPubs incorporados;
- aula ReBrATS 2026 e resultados da aula de 2025;
- método SABEIS para ETL, reconciliação, coortes e demanda aferida;
- capítulos de arquitetura, R, Parquet, DuckDB e BPS;
- Navegador de Dados do SUS versão 14, ZIP, SHA-256 e código-fonte legível em
  [`software/navegador/`](software/navegador/).

## Convenções

O SUS é tratado como sistema de saúde. SIA, SIH, SIM, SINASC, SINAN, SISAB e
fontes correlatas são sistemas de informação ou bases específicas. A
disseminação federal atual é atribuída ao DEMAS/SEIDIGI/MS. Domínios históricos
com `datasus.gov.br` são mantidos quando necessários para acesso técnico.

O executável `dbf2dbc.exe` compacta e descompacta. No fluxo SABEIS ele é usado
sob Wine para converter DBC em DBF.

## Compilar o livro

```bash
quarto preview
quarto render
```

A saída fica em `_book/`. O script `render.R` também gera a aula em
`_book/curso/index.html`.

## Publicação automática

O fluxo [`.github/workflows/publicar-pages.yml`](.github/workflows/publicar-pages.yml)
é acionado por `push` no `main` ou manualmente. Em **Settings > Pages**, a origem
deve ser **GitHub Actions**. Consulte
[`PUBLICAR_GITHUB_PAGES.md`](PUBLICAR_GITHUB_PAGES.md).

## Estado editorial

A estrutura navegável está completa. O curso, o núcleo metodológico e os
capítulos do Navegador estão preenchidos. Os demais capítulos estruturais
permanecem identificados para desenvolvimento editorial posterior.
