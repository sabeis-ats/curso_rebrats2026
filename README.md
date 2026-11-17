# Curso ReBrATS 2026 — acesso aos dados da SABEIS com R

Material do curso presencial **Dados da SABEIS via FTP utilizando a Linguagem
R**, ofertado no VII Congresso ReBrATS.

- **Data:** 18 de novembro de 2026
- **Horário:** 8h às 12h30
- **Local:** sala 109
- **Docentes:** Felipe Ferré e Mariá Pereira
- **Nível:** intermediário

## Situação do material

Esta primeira entrega contém a aula-núcleo do curso: acesso, seleção, download,
leitura e validação dos dados da SABEIS. O conteúdo foi reconstruído a partir do
[Curso ReBrATS 2025](https://github.com/sabeis-ats/curso_rebrats2025) e atualizado
para 2026.

Após a validação desta aula no RStudio, será montada a espinha dorsal do livro.
Os demais capítulos serão desenvolvidos e revisados em iterações posteriores.

## Arquivo principal

O curso está concentrado em um único arquivo:

- [`curso_rebrats2026.Rmd`](curso_rebrats2026.Rmd)

O documento gera uma página HTML autocontida, com sumário lateral, seções
numeradas e blocos de código expansíveis.

## Conteúdo da aula

1. apresentação da SABEIS e dos dados abertos do SUS;
2. preparação do R e diagnóstico do suporte a SFTP;
3. parâmetros e credenciais de acesso;
4. listagem dos arquivos disponíveis;
5. interpretação da gramática dos nomes dos arquivos;
6. criação do catálogo de coortes;
7. seleção de uma coorte por quantidade de registros;
8. download atômico de um arquivo `csv.gz`;
9. leitura com `data.table::fread()`;
10. validação da quantidade declarada de registros;
11. inspeção de colunas, ausências e cardinalidade;
12. leitura das tabelas auxiliares da SABEIS;
13. identificação da diretriz e cuidado com a competência do SIGTAP;
14. cálculo e visualização da demanda aferida;
15. exercício prático e checklist de reprodução.

## Acesso à SABEIS

O nome oficial do curso preserva a expressão “FTP”, mas o serviço utilizado na
prática é **SFTP**, com transferência sobre SSH.

| Parâmetro | Valor |
|:--|:--|
| Host | `45.231.133.29` |
| Porta | `7891` |
| Diretório | `/srv/ftp/dadosabertos/` |
| URL | `sftp://45.231.133.29:7891/srv/ftp/dadosabertos/` |
| Usuário | `livre` |
| Senha | `12345` |
| Credencial usada pelo `curl` | `livre:12345` |

Essas credenciais são públicas, dummies e mantidas integralmente no material
para permitir a reprodução da aula.

## Dependências

- R;
- RStudio;
- Pandoc, normalmente incluído no RStudio;
- pacotes R `curl`, `data.table`, `knitr` e `rmarkdown`;
- biblioteca `libcurl` compilada com suporte ao protocolo SFTP.

Instale os pacotes necessários no console do R:

```r
pacotes <- c("curl", "data.table", "knitr", "rmarkdown")
faltantes <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]

if (length(faltantes) > 0) {
  install.packages(faltantes)
}
```

## Compilação no RStudio

1. clone ou baixe este repositório;
2. abra `curso_rebrats2026.Rmd` no RStudio;
3. mantenha inicialmente `executar_sftp: false` no cabeçalho YAML;
4. use **Knit** para testar a geração da página sem acessar o servidor;
5. altere para `executar_sftp: true` e compile novamente para executar toda a
   prática.

Também é possível compilar pelo console:

```r
rmarkdown::render(
  "curso_rebrats2026.Rmd",
  params = list(
    executar_sftp = TRUE,
    limite_registros = 20000
  )
)
```

O parâmetro `limite_registros` controla o tamanho máximo da primeira coorte
selecionada automaticamente.

## Resultado esperado

Ao final da aula, o participante deverá ter:

- validado o suporte local a SFTP;
- listado o repositório da SABEIS;
- convertido os nomes dos arquivos em um catálogo de coortes;
- selecionado e baixado um arquivo `csv.gz`;
- preservado códigos e identificadores como texto na primeira leitura;
- confrontado a quantidade observada com a declarada no nome do arquivo;
- relacionado a coorte às tabelas auxiliares;
- produzido uma série mensal de usuários distintos;
- registrado as limitações da demanda aferida para uso em ATS.

## Estrutura atual do repositório

| Arquivo | Finalidade |
|:--|:--|
| `curso_rebrats2026.Rmd` | Fonte única da aula-núcleo |
| `README.md` | Apresentação, conteúdo e instruções de execução |
| `render.R` | Rotina auxiliar de renderização |
| `LICENSE.md` | Licenças do conteúdo e do código |
| `.gitignore` | Exclusão de arquivos temporários e dados baixados |

## Referências principais

- [Curso ReBrATS 2025](https://github.com/sabeis-ats/curso_rebrats2025)
- [SABEIS — processo de ETL](https://rpubs.com/sabeis/etl)
- [SABEIS — tabelas auxiliares](https://github.com/sabeis-ats/bd_geral)
- [DATASUS — informações de saúde](https://datasus.saude.gov.br/informacoes-de-saude-tabnet/)

## Licença

Conteúdo didático sob [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Código sob licença MIT. Consulte [`LICENSE.md`](LICENSE.md).
