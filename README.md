# Dados Abertos do SUS — edição 2026

Livro online sobre sistemas de informação, fontes de dados do SUS, ferramentas de tratamento e método SABEIS.

## Conteúdo

- 7 partes;
- 49 capítulos em Quarto Markdown;
- 7 apêndices;
- aula ReBrATS 2026 com credenciais públicas, comandos e resultados observados em 2025;
- incorporação integral dos oito materiais RPubs indicados;
- capítulos completos de arquitetura, instalação e uso do Navegador de Dados do SUS;
- código-fonte da versão 14 do Navegador, com soma SHA-256 e resultados de demonstração;
- referências BibTeX do portfólio de Felipe Ferré.

## Convenções

O SUS é tratado como sistema de saúde. SIA, SIH, SIM, SINASC, SINAN, SISAB e fontes correlatas são tratados como sistemas de informação ou bases específicas. A disseminação federal atual é atribuída ao DEMAS/SEIDIGI/MS.

O executável `dbf2dbc.exe` compacta e descompacta. No fluxo SABEIS ele é usado sob Wine para converter DBC em DBF.

## Publicação local

```bash
quarto preview
```

Para gerar a versão estática:

```bash
quarto render
```

A saída será gravada em `_book/`.

## Estado editorial

A estrutura navegável está completa. O núcleo metodológico e os capítulos do Navegador estão preenchidos; os demais capítulos possuem objetivos, seções e tarefas da próxima iteração.

