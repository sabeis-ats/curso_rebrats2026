# Navegador de dados do SUS - catálogo multifonte

O projeto integra os três dicionários do repositório `LabXiabr/bd_geral`, cataloga arquivos FTP, permite selecioná-los no terminal ou no Shiny, baixa DBC/DBF, concatena esquemas diferentes e anexa rótulos e descrições ao resultado.

Também cataloga os ZIP mensais do SIGTAP em `ftp://ftp2.datasus.gov.br/pub/sistemas/tup/downloads/` e lê diretamente os TXT posicionais, seguindo a harmonização do projeto `https://git.conass.org.br/ferre/sigtap/`.

A versão 14 também cataloga as bases anuais CSV do Banco de Preços em Saúde (BPS), descobre dinamicamente as listas CMED vigentes (PMVG/PF e PMC) e fornece utilitários para OBM e RENAME.

A versão 13 acrescenta catálogo CKAN do Portal de Dados Abertos do SUS, índice público da Anvisa e filtros por fonte, tema, sistema/conjunto e recurso.

## Fontes e catálogo aberto

Depois de `Rscript atualizar_catalogo.R`, cada linha possui `sg_fonte`. Os valores principais são:

- `FTP_DATASUS`: DBC/DBF da disseminação histórica;
- `FTP_SIGTAP`: pacotes mensais da tabela unificada;
- `DADOS_ABERTOS_SUS`: recursos do catálogo CKAN e bases BPS configuradas;
- `ANVISA`: índice público da Agência e listas CMED configuradas.

No Portal de Dados Abertos do SUS, os temas da página inicial são grupos CKAN. `listar_temas_dadosabertos_sus()` retorna o grupo e sua quantidade de conjuntos; `listar_recursos_dadosabertos_sus()` percorre todos os conjuntos e abre uma linha por recurso, preservando tema, identificadores do conjunto/recurso, formato, URL, tamanho e data de modificação.

```r
source("R/core.R")
source("R/catalogos_abertos.R")
temas <- listar_temas_dadosabertos_sus()
recursos <- listar_recursos_dadosabertos_sus()
```

A Anvisa publica arquivos em `https://dados.anvisa.gov.br/dados/`, atualmente servido por um índice h5ai, não por CKAN. `listar_arquivos_anvisa()` extrai os recursos tabulares e documentais que o índice expõe. A CMED é descoberta na página editorial oficial, e cada URL é validada antes de entrar no catálogo; identificadores `resolveuid` não são persistidos.

O Shiny e o terminal agora filtram primeiro por fonte e tema. Recursos CSV, JSON, XLS/XLSX, RDS e Parquet podem ser baixados e lidos. ZIP/GZ só são concatenados automaticamente quando contêm exatamente um arquivo tabular suportado. PDF, XML, dicionários e formatos desconhecidos ficam disponíveis pelo botão **Baixar recurso bruto**, mas não são misturados em uma tabela.

Recursos de conjuntos diferentes podem possuir semânticas e esquemas incompatíveis. A união de colunas é tecnicamente possível, mas o usuário deve restringir a seleção a recursos da mesma série/conjunto antes de concatenar.

## Estrutura otimizada

`preparar_dicionarios()` produz um único RDS com uma lista de `data.table` indexadas:

- `sistema`: uma linha por sistema;
- `subsistema`: uma linha por sistema, subsistema e versão, quando disponível;
- `atributo`: dicionário no formato longo, preservando atributo original, padronizado, rótulo e descrição; a URL não é repetida aqui, pois pertence ao subsistema;
- `code_system`: categorias extraídas apenas quando a descrição contém ao menos dois pares explícitos `código-rótulo`.

Os dados baixados mantêm os nomes originais em minúsculas. Rótulos e descrições ficam nos atributos `label` e `description` de cada coluna e no dicionário anexo. Isso evita quebrar scripts que dependem dos nomes físicos.

```r
x <- readRDS("dados_saida/sia_pa.rds")
visao_rotulada(x)
dicionario(x)
code_systems(x)
attr(x$pa_sexo, "label")
attr(x$pa_sexo, "description")
```

## Instalação

Execute a partir da raiz deste diretório:

```bash
Rscript instalar_dependencias.R
Rscript atualizar_catalogo.R
```

O instalador obtém `read.dbc` de `danicat/read.dbc` quando ele não estiver disponível no CRAN para a versão local do R. Os CSV são normalizados por coluna para UTF-8, aceitando também entradas Windows-1252 e Latin-1.

Para Parquet, instale também `arrow`:

```r
install.packages("arrow")
```

## Navegador no terminal

```bash
Rscript navegar_terminal.R
```

O fluxo pergunta fonte, tema, sistema/conjunto, subsistema, UF e período, confirma os arquivos, baixa e concatena, e permite gravar RDS ou Parquet. Se o catálogo ainda não existir, o navegador tenta criá-lo automaticamente.
As escolhas usam uma lista numerada própria, compatível com execução por `Rscript`.
O terminal confirma o uso de `~/Downloads/dbc`; se recusado, solicita outro diretório e oferece criá-lo.

### Complementação SIA com PA

Para `ABO`, `AB`, `ACF`, `AD`, `AM`, `AN`, `AQ`, `AR` e `ATD`, o terminal e o Shiny oferecem complementação opcional com o PA da mesma UF de processamento e competência. O fluxo localiza o PA no catálogo, trata autorização como texto, exclui da junção autorizações nulas/vazias ou compostas apenas por zeros e filtra o PA pelos procedimentos observados no arquivo específico. A união permite relações um-para-muitos e usa `no_atributo_padrao` para coalescer campos semanticamente equivalentes, preservando valores preenchidos.

O FTP não oferece filtro de linhas: o DBC do PA precisa estar local ou ser baixado integralmente. O filtro de procedimentos é aplicado imediatamente após a leitura.

### SIGTAP

Após executar novamente `Rscript atualizar_catalogo.R`, o sistema `SIGTAP` e o subsistema `PROCEDIMENTO` aparecem nos navegadores. Cada `TabelaUnificada_AAAAMM_*.zip` representa uma competência.

O resultado possui uma linha por procedimento **e competência**. Portanto, selecionar um intervalo conserva a série histórica mensal do mesmo código, em vez de sobrescrever competências anteriores. A base `tb_procedimento` é complementada com descrição, financiamento, nomes de grupo, subgrupo e forma de organização, complexidade e sexo. Modalidades, instrumentos de registro, procedimentos de origem, vínculos SIA/SIH, CBO, serviço/classificação, CID, tipos de leito e detalhes são agregados em campos separados por ponto e vírgula, sem multiplicar linhas.

As posições são obtidas dos arquivos `*_layout.txt` do próprio ZIP de cada competência; as especificações internas são apenas contingência. Isso acompanha mudanças de largura do DATASUS e evita que descrições extensas sejam interpretadas como separadores. Em particular, `VL_SH`, `VL_SA` e `VL_SP` têm 12 posições no ZIP atual. Eles são convertidos de centavos para números em reais, arredondados a duas casas e marcados com a unidade `BRL`. A notação usada pelo console é apenas apresentação; para exibir sempre duas casas use `format(x$vl_sh, nsmall = 2, scientific = FALSE)`.

`co_procedimento` permanece como texto de dez posições e está harmonizado com `procrea`, `proc_id`, `pa_proc_id`, `ap_pripal` e demais atributos mapeados como `co_procedimento` no dicionário geral.

### BPS, CMED, OBM e RENAME

O catálogo inclui `BPS / COMPRA_CSV` e `BPS / COMPRA_JSON` para 2020 em diante. O programa lista os endereços anuais oficiais da Amazon S3, mantém `codigo_br` como CATMAT e `anvisa` como registro sanitário, converte datas e armazena preços como números em reais. O CSV usa separador `;` e é preferido para consolidação em grande volume; o JSON é integralmente carregado em memória e permanece como alternativa de conferência/interoperabilidade.

Para consultas seletivas, sem baixar o ano inteiro:

```r
source("R/core.R")
source("R/economia_saude.R")
x <- consultar_bps_api(codigoCatmat = "405899", anoCompra = 2026)
```

A API exige `codigoCatmat` ou `cnpjInstituicao`, pagina no máximo 500 registros por chamada e a função percorre as páginas automaticamente.

O catálogo também inclui `CMED / PMVG` e `CMED / PMC`. O leitor detecta a linha real do cabeçalho, conserva registro, EAN, substância, produto, apresentação, PF, PMVG/PMC por alíquota e converte as colunas monetárias em números. A lista PMVG deve ser interpretada conforme CAP, incidência de ICMS e regras descritas pela própria CMED; ela é teto regulatório, não preço praticado. O BPS contém preços efetivamente informados em compras.

O vínculo opcional BPS→SIGTAP não confunde CATMAT com procedimento. Ele pesquisa somente o grupo SIGTAP 06 e só anexa um código quando o candidato textual é unívoco. As colunas `tp_vinculo_sigtap` e `vl_score_sigtap` tornam explícito que se trata de candidato automatizado, não de chave oficial. Todos os candidatos, inclusive ambiguidades, ficam no atributo `mapa_candidatos_sigtap`.

Se o arquivo histórico `preco_medicamento_20211117_atual.xlsx` for colocado em `config/`, seus vínculos CATMAT→SIGTAP unívocos têm precedência e são identificados como `mapa_historico_manual_2021`; os demais seguem para a aproximação textual. O mapa é útil como semente, mas não é tratado como fonte atual nem aplicado quando um CATMAT possui mais de um procedimento.

A OBM oferece um caminho mais forte para medicamentos com registro Anvisa:

```r
bps_obm <- mapear_bps_obm(bps, "obm_20220816.zip")
rename <- ler_rename_xlsx("RENAME.xlsx")
```

`mapear_bps_obm()` percorre `BPS.anvisa → OBM.tb_amp.nu_nreg → tb_vmp → tb_vtm`, usando a raiz de nove dígitos do registro para compatibilizar apresentações de 13 dígitos e recuperando medicamento virtual e princípio ativo. No pacote OBM examinado, `td_catmat_br.csv` é apenas um domínio CATMAT e não traz uma relação explícita CATMAT→AMP/VMP; portanto, CATMAT sozinho não sustenta um vínculo determinístico com SIGTAP. A RENAME acrescenta DCB, forma, concentração e ATC, mas também não fornece uma chave SIGTAP universal.

Quando existir um arquivo `config/obm_*.zip`, a opção BPS→SIGTAP usa automaticamente os registros Anvisa com princípio ativo OBM unívoco antes da aproximação textual. A página de recursos da OBM atualmente redireciona para autenticação Gov.br; por isso o projeto não tenta automatizar credenciais nem depende de scraping dessa tela.

## Navegador Shiny

```bash
R -q -e "shiny::runApp('.', launch.browser = TRUE)"
```

No Shiny, selecione arquivos na tabela. Sem seleção explícita, o botão processa todos os registros filtrados. O período usa competências discretas `AAAAMM`. A aba **Script R** mostra e permite baixar o código reproduzível correspondente à seleção.
O progresso utiliza apenas a API pública do Shiny; erros de validação ou download encerram normalmente o overlay e permanecem visíveis no painel **Execução**.
Depois da concatenação aparecem downloads completos em RDS e CSV compactado (`.csv.gz`). O botão Parquet também aparece quando o pacote `arrow` está instalado. A tabela da aba **Resultado** mostra somente as primeiras 1.000 linhas para não transferir milhões de registros ao navegador.
Downloads e concatenações são executados por `callr` em outro processo R. O job é registrado na URL (`?job=...`); recarregar a mesma URL permite retomar o acompanhamento e acessar o resultado após uma expiração da sessão Shiny.

A pasta padrão é `~/Downloads/dbc`, plana e sem subpastas. Arquivos já presentes não são baixados novamente. Em uma implantação remota, esse caminho pertence ao servidor R (pipeta/bureta), não ao computador que abriu o navegador. O resultado produzido no servidor pode ser baixado pelo botão **Baixar resultado RDS**.

## Code systems

A extração automática é conservadora. Descrições como `1-Sim; 2-Não; 9-Ignorado` viram uma tabela. Pontuação final, como `2)`, é removida. Referências a arquivos DEF e especificações como `APAC_Medicamentos`, `UF=Unid`, `AA=ano`, `CHAR` e `layout` são descartadas. Campos de diagnóstico/causa/CID são identificados como referência `CID-10`, não como enumerações.

| sg_sistema | sg_subsistema | no_atributo | co_valor | no_valor |
|---|---|---|---|---|
| ... | ... | sexo | 1 | Masculino |

Prosa livre, intervalos e regras condicionais não são convertidos automaticamente. Correções mantidas em `config/code_system_overrides.csv` são incorporadas automaticamente ao objeto de dicionários, prevalecendo sobre extrações automáticas com a mesma chave.

## Decisões importantes

- A classificação usa o dicionário e a URL, evitando depender somente de regex do nome do arquivo.
- A competência aceita `AA`, `AAMM` e `AAAAMM`; anos com dois dígitos usam corte em 79.
- A concatenação usa união de colunas (`fill = TRUE`) e adiciona proveniência por linha.
- Colunas padronizadas são opcionais e nunca substituem as originais.
- Antes de concatenar, o programa estima o volume descompactado (padrão: 12 vezes o DBC), compara com 70% da memória disponível e verifica o espaço necessário para downloads ainda ausentes. A operação é bloqueada quando excede esses limites.
- RDS exige que o resultado concatenado caiba na memória. Para os cerca de 300 GB compactados/3 TB descompactados, divida a execução por competência e/ou UF e prefira Parquet com Arrow ou DuckDB em um fluxo particionado.
- RDS preserva classes e metadados R anexados às colunas; Parquet é colunar, interoperável e normalmente mais adequado para leitura seletiva e volumes grandes. Nesta versão, ambos são exportados depois da concatenação em memória; escolher Parquet não elimina o limite de RAM da etapa anterior.
- O terminal destaca cada verificação, download, leitura e harmonização. O Shiny mantém um painel de estado com conclusão ou erro, além da barra de progresso.
- Código de saída `-9` indica `SIGKILL`: normalmente OOM/falta de RAM ou limite externo. A interface passa a mostrar RAM e espaço livre atuais para ajudar a diferenciar esse caso de falhas explícitas de escrita por disco cheio.
- Quando o PA possui várias partes para a mesma UF/competência, todas são filtradas e concatenadas antes de um único merge por autorização. Isso evita repetir as linhas sem correspondência para cada parte do PA.
