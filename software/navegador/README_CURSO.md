# Código-fonte incorporado ao curso

Esta pasta contém o código-fonte legível da versão 14 do Navegador de Dados do SUS.

## Proveniência

- pacote de origem: `../rshiny_ftpsus_navegador.zip`;
- versão declarada: `14`;
- SHA-256 do pacote: `a9710263a7a5286b9f0067b504bc35f4e19cd38ff2569b20d49564854aff3068`;
- data de modificação do pacote de origem: 20 de agosto de 2026.

O código e os arquivos de configuração foram mantidos com seus nomes originais. Os objetos RDS de catálogo e os resultados de demonstração permanecem somente no ZIP, pois são artefatos gerados ou dados de execução, não código-fonte.

## Estrutura

```text
navegador/
├── app.R
├── atualizar_catalogo.R
├── instalar_dependencias.R
├── navegar_terminal.R
├── VERSAO
├── config/
└── R/
```

## Execução

```bash
Rscript instalar_dependencias.R
Rscript atualizar_catalogo.R
Rscript navegar_terminal.R
```

Interface Shiny:

```bash
R -q -e 'shiny::runApp(".", launch.browser=TRUE)'
```

Os nomes internos legados que contêm `DATASUS` foram preservados para compatibilidade com a versão 14. No texto do curso, a disseminação federal vigente é atribuída ao DEMAS/SEIDIGI/MS.
