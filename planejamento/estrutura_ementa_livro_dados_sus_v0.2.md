# Livro Dados Abertos do SUS — estrutura e ementa v0.2

**Situação:** proposta editorial para validação antes da criação dos capítulos do livro.

**Data da versão:** 17 de novembro de 2026.

## Título provisório

**Dados Abertos do SUS: acesso, interoperabilidade e análise aplicada à ATS**

Subtítulo provisório: **Da disseminação pelo DEMAS/SEIDIGI/MS à curadoria da SABEIS**.

## Alterações estruturantes da v0.2

1. Atribuição da disseminação dos dados ao Departamento de Monitoramento,
   Avaliação e Disseminação de Informações Estratégicas em Saúde da Secretaria
   de Informação e Saúde Digital do Ministério da Saúde
   (**DEMAS/SEIDIGI/MS**).
2. Retirada da expressão “dados DATASUS”. O termo DATASUS permanecerá apenas
   quando necessário para descrever fatos históricos, nomes legados, endereços
   antigos, ferramentas ou trechos de documentos anteriores.
3. Distinção obrigatória entre **sistema de saúde** e **sistema de informação**.
   O SUS é um sistema de saúde. SIA, SIH, SIM, SINAN e outros são sistemas de
   informação.
4. Correção do tratamento de `dbf2dbc.exe`: a ferramenta do pacote TabWin será
   apresentada como utilitário de conversão entre DBC e DBF, incluindo a
   descompactação DBC → DBF e a compactação DBF → DBC. O fluxo SABEIS documentado
   usa `wine Tab415/dbf2dbc.exe arquivo.dbc` para descompactar o DBC.
5. Desmembramento de fontes antes agrupadas. BNAFAR, e-SUS Notifica, ESAVI,
   SIES, SISAGUA, SISVAN e SIVEP passam a ter capítulos próprios.
6. Expansão da parte SABEIS para incorporar sistematicamente o método ETL
   publicado em <https://rpubs.com/sabeis/etl>.
7. Inclusão de uma matriz de incorporação das publicações de Felipe Ferré e dos
   materiais fornecidos no projeto.

# 1. Convenções editoriais obrigatórias

## 1.1 Sistema de saúde e sistema de informação

| Conceito | Uso no livro | Exemplos |
|---|---|---|
| Sistema de saúde | Conjunto institucional, político, assistencial e federativo que organiza ações e serviços de saúde | Sistema Único de Saúde, sistemas universais de saúde |
| Sistema de informação | Conjunto organizado de pessoas, processos, dados, regras e tecnologias que registra e processa informação | SIA, SIH, SIM, SINAN, SINASC, SISAB, SISVAN |
| Plataforma ou serviço digital | Ambiente que disponibiliza funções, dados ou serviços | RNDS, Meu SUS Digital, Portal de Dados Abertos do SUS, API do DEMAS |
| Cadastro ou tabela de referência | Fonte usada para identificar ou classificar entidades | CNES, SIGTAP, CATMAT, RENAME |
| Ferramenta | Software usado para adquirir, transformar, consultar ou analisar dados | TabWin, TabNet, `dbf2dbc.exe`, Bash, R, Python, DuckDB |
| Base ou conjunto de dados | Registros disseminados ou derivados de um sistema de informação | arquivos PA do SIA, registros de óbitos do SIM, coortes SABEIS |

Regra de redação: não se escreverá que “o SUS é um sistema de informação”. O
SUS é o sistema de saúde brasileiro e opera múltiplos sistemas de informação.

## 1.2 Autoria institucional da disseminação

O texto adotará as seguintes formas:

- **dados abertos do SUS**;
- **dados disseminados pelo Ministério da Saúde**;
- **dados disseminados pelo DEMAS/SEIDIGI/MS**;
- **sistemas de informação mantidos pelas áreas gestoras do Ministério da
  Saúde**;
- **diretórios e tabuladores atualmente administrados no âmbito do
  DEMAS/SEIDIGI/MS**.

A expressão “dados DATASUS” não será usada como denominação atual. O DATASUS
será citado apenas quando o contexto histórico, tecnológico ou documental o
exigir. Em citações de documentos anteriores, a redação original poderá ser
preservada entre aspas ou em nota, acompanhada da atualização institucional.

## 1.3 Atualização de documentos históricos

O relatório ETL da SABEIS foi publicado em 2022. Ao incorporá-lo ao livro:

- o método, os algoritmos, as tabelas de controle e os resultados de validação
  serão preservados;
- referências institucionais históricas serão identificadas como tais;
- a responsabilidade atual pela disseminação será atualizada para
  DEMAS/SEIDIGI/MS;
- caminhos, protocolos e disponibilidade serão testados novamente antes da
  publicação de cada capítulo;
- números de arquivos, bytes e registros serão tratados como retratos do
  período do relatório, não como totais atuais.

# 2. Plataforma editorial e repositório

## 2.1 Plataforma: Quarto Book

O livro será produzido com Quarto Book. A mesma fonte deverá gerar HTML, PDF e
EPUB, com código R executável, tabelas, gráficos, referências cruzadas e
bibliografia.

Configurações previstas:

- `execute.freeze: auto` para evitar repetição de cálculos custosos;
- cache nos capítulos de processamento;
- execução de rede desativada por padrão;
- `renv.lock` para registrar versões dos pacotes R;
- HTML com busca integral, sumário lateral e navegação entre capítulos;
- pasta `docs/` para publicação inicial no GitHub Pages;
- scripts pesados executados localmente no Bequer durante a construção.

## 2.2 Repositório provisório do livro

- nome proposto: `sabeis-ats/livro-dados-sus`;
- endereço proposto: <https://sabeis-ats.github.io/livro-dados-sus/>;
- fontes na branch `main`;
- saída HTML em `docs/`;
- GitHub Pages configurado para `main/docs`;
- arquivo `docs/.nojekyll`;
- GitHub Actions somente após a estabilização das dependências.

# 3. Ementa geral

Organização, disseminação, aquisição, transformação, integração, validação e
análise de dados abertos do Sistema Único de Saúde. Responsabilidade do
DEMAS/SEIDIGI/MS pela disseminação de informações estratégicas e dados abertos.
Diferenças entre sistema de saúde, sistema de informação, plataforma, cadastro,
terminologia e conjunto de dados. Sistemas de informação de produção
assistencial, vigilância, estatísticas vitais, imunização, nutrição, qualidade
da água e assistência farmacêutica. Fundamentos de informática em saúde,
interoperabilidade, governança, modelos de informação, HL7 FHIR, SNOMED CT e
terminologias de medicamentos. Processamento reprodutível com Bash,
PostgreSQL, R, Python, Parquet e DuckDB. Conversão DBC/DBF com
`dbf2dbc.exe`. Método SABEIS para ETL, vinculação de registros do SIA,
formação de coortes, validação contra TabNet, estimativa de demanda aferida,
análise de impacto orçamentário e monitoramento pós-incorporação. Acesso SFTP
às coortes da SABEIS. Navegador de Dados do SUS como instrumento de descoberta,
documentação e aquisição das fontes.

## 3.1 Público-alvo

- profissionais de NATS e da ReBrATS;
- pesquisadores e analistas de ATS;
- informatas em saúde, cientistas de dados e profissionais de tecnologia;
- gestores e trabalhadores do SUS;
- estudantes que utilizam bases administrativas, epidemiológicas ou clínicas.

## 3.2 Pré-requisitos

- noções de arquivos tabulares;
- leitura básica de R ou outra linguagem de análise;
- uso inicial de terminal e organização de diretórios;
- compreensão básica da organização federativa do SUS.

## 3.3 Objetivos de aprendizagem

Ao final do livro, o leitor deverá ser capaz de:

1. distinguir sistema de saúde, sistema de informação, plataforma, cadastro,
   terminologia e base de dados;
2. reconhecer a organização atual da disseminação pelo DEMAS/SEIDIGI/MS;
3. identificar a área gestora, a finalidade e a unidade de análise de cada
   sistema de informação;
4. localizar, inventariar, baixar e validar arquivos disseminados pelo
   Ministério da Saúde;
5. converter DBC e DBF com `dbf2dbc.exe` e validar a integridade do resultado;
6. modelar e carregar grandes volumes em PostgreSQL;
7. organizar dados em Parquet e consultá-los com DuckDB;
8. relacionar registros a CNES, SIGTAP, território e terminologias de
   medicamentos;
9. reproduzir o fluxo ETL da SABEIS e suas verificações de qualidade;
10. acessar, interpretar e documentar as coortes disponibilizadas por SFTP;
11. estimar demanda aferida e monitorar tecnologias após a incorporação;
12. usar o Navegador de Dados do SUS para localizar fontes e iniciar a
    preparação dos dados.

# 4. Bloco A — estrutura de partes, capítulos e seções

## Parte I — SUS, informação e decisão

### Capítulo 1 — O SUS como sistema de saúde orientado por informação

1. sistema de saúde, serviços, redes e organização federativa;
2. informação para cuidado, gestão, vigilância, regulação e controle social;
3. produção do dado nas esferas municipal, estadual e federal;
4. responsabilidades das áreas gestoras e das áreas de informação;
5. dados administrativos, clínicos, epidemiológicos e operacionais;
6. limitações da centralização histórica e necessidade de retorno da
   informação aos entes produtores.

### Capítulo 2 — Disseminação de dados pelo DEMAS/SEIDIGI/MS

1. atribuições atuais do DEMAS e da SEIDIGI;
2. Plano de Dados Abertos do Ministério da Saúde;
3. Portal de Dados Abertos do SUS;
4. API de Dados Abertos do DEMAS;
5. Tabuladores do SUS, TabNet e arquivos para uso local;
6. diretórios de arquivos, APIs, catálogos, painéis e documentos;
7. áreas gestoras dos sistemas de informação e responsabilidade pelo conteúdo;
8. atualização institucional de referências históricas ao DATASUS.

### Capítulo 3 — A iniciativa SABEIS

1. origem, finalidade e escopo;
2. Sala Aberta de Inteligência em Saúde;
3. dados abertos, software livre e gestão do conhecimento;
4. repositório de dados, coortes e interfaces;
5. recursos de software, hardware e infraestrutura;
6. organização do SIA em PA, AM, AQ, AR, AN, BI e PS;
7. curadoria, proveniência, reprodutibilidade e transparência;
8. SABEIS como infraestrutura para ATS e monitoramento.

### Capítulo 4 — Dados de mundo real e ATS

1. dado administrativo e evidência de mundo real;
2. unidade de análise e população observável;
3. Protocolos Clínicos e Diretrizes Terapêuticas;
4. Conitec, ReBrATS e monitoramento pós-incorporação;
5. demanda epidemiológica e demanda aferida;
6. análise de impacto orçamentário;
7. limites de cobertura, identificação, comparabilidade e inferência;
8. aprendizagem institucional apoiada por dados.

## Parte II — Sistemas de informação e fontes de dados do SUS

### Capítulo 5 — Sistema de Informações Ambulatoriais do SUS

1. finalidade e fluxo de produção do SIA;
2. competências de atendimento, apresentação e processamento;
3. PA e a produção ambulatorial;
4. AM, AQ, AR, AN e ATD nas APAC;
5. AB, ABO, ACF, AD, AMP, BI, PS e SAD;
6. autorização, usuário, estabelecimento, procedimento, quantidade e valor;
7. identificador pseudonimizado do usuário;
8. evolução de layouts e relação com SIGTAP;
9. uso do SIA pela SABEIS.

### Capítulo 6 — Sistema de Informações Hospitalares e comunicações hospitalares

1. finalidade e fluxo do SIH;
2. AIH, internação, procedimento e estabelecimento;
3. RD, RJ, SP, CH, CM e ER;
4. CIH e CIHA;
5. competências, reapresentações e rejeições;
6. diferenças entre produção hospitalar e ambulatorial;
7. limitações para seguimento de usuários;
8. validação por tabuladores e indicadores oficiais.

### Capítulo 7 — Atenção Primária e SISAB

1. organização da informação na Atenção Primária;
2. SISAB e estratégia e-SUS APS;
3. Coleta de Dados Simplificada e Prontuário Eletrônico do Cidadão;
4. arquivos históricos CT e PR;
5. cadastro, atendimento, procedimento e produção;
6. mudanças de modelo, cobertura e granularidade;
7. integração com território, equipes e CNES;
8. limites para séries históricas.

### Capítulo 8 — Cadastro Nacional de Estabelecimentos de Saúde

1. CNES como cadastro de referência;
2. estabelecimento, equipe, profissional, equipamento, habilitação e leito;
3. arquivos DC, EE, EF, EP, EQ, GM, HB, IN, LT, PF, RC, SR e ST;
4. vigência e reconstrução histórica;
5. chaves de ligação com SIA, SIH e outros sistemas de informação;
6. gestão, natureza jurídica, tipo de unidade e serviço;
7. API do DEMAS e arquivos disseminados;
8. erros frequentes de vinculação temporal.

### Capítulo 9 — Sistema de Informações sobre Mortalidade

1. finalidade e fluxo do SIM;
2. Declaração de Óbito;
3. DO, DOE, DOF, DOI e DOM;
4. causa básica, causas associadas e local de ocorrência;
5. residência, ocorrência e estabelecimento;
6. codificação CID e revisão de causas;
7. cobertura, atraso e qualidade;
8. uso em coortes e vinculação de registros.

### Capítulo 10 — Sistema de Informações sobre Nascidos Vivos

1. finalidade e fluxo do SINASC;
2. Declaração de Nascido Vivo;
3. DN e DNR;
4. mãe, gestação, parto, nascido vivo e estabelecimento;
5. residência e ocorrência;
6. mudanças de layout;
7. indicadores de natalidade e cuidado materno-infantil;
8. integração com SIM, CNES e território.

### Capítulo 11 — Sistema de Informação de Agravos de Notificação

1. finalidade e fluxo do SINAN;
2. notificação, investigação, encerramento e duplicidade;
3. arquivos por agravo;
4. inventário completo de siglas e períodos;
5. hanseníase como estudo de caso;
6. data de notificação, diagnóstico e encerramento;
7. mudanças de ficha, domínio e layout;
8. ETL em R ou Bash;
9. validação contra TabNet;
10. limites de subnotificação, oportunidade e completude.

### Capítulo 12 — Imunização e registros de vacinação

1. Programa Nacional de Imunizações;
2. sistemas de informação históricos e atuais;
3. doses aplicadas, coberturas, campanhas e estoques;
4. identificação de imunobiológico, dose, público e território;
5. dados disponíveis na API do DEMAS;
6. mudanças de sistemas e denominadores;
7. qualidade, duplicidade e oportunidade;
8. distinção entre vacinação e ESAVI.

### Capítulo 13 — e-SUS Notifica

1. finalidade e contexto de implantação;
2. notificações de síndromes e eventos de interesse;
3. estrutura dos registros e versões;
4. identificação, território e unidade notificadora;
5. acesso e condições de uso;
6. tratamento de duplicidades e alterações;
7. limites epidemiológicos e operacionais;
8. relação com SINAN, SIVEP e outros fluxos de vigilância.

### Capítulo 14 — SIVEP

1. família de sistemas de informação da vigilância epidemiológica;
2. SIVEP-Gripe e vigilância de síndromes respiratórias;
3. unidade de registro, internação, evolução e desfecho;
4. fichas, versões e dicionários;
5. identificação de estabelecimento e território;
6. acesso a dados e painéis;
7. completude, atraso e mudança de definição de caso;
8. integração com SIM, CNES e vacinação.

### Capítulo 15 — ESAVI

1. eventos supostamente atribuíveis à vacinação ou imunização;
2. finalidade de farmacovigilância e segurança do paciente;
3. notificação, investigação e classificação de causalidade;
4. exposição, evento, dose, lote e temporalidade;
5. dados disponibilizados pela API do DEMAS;
6. distinção entre associação temporal e causalidade;
7. completude, duplicidade e subnotificação;
8. integração com registros de vacinação e terminologias.

### Capítulo 16 — BNAFAR

1. Base Nacional de Dados de Ações e Serviços da Assistência Farmacêutica;
2. aquisição, estoque, distribuição, dispensação e posição de estoque;
3. responsabilidades federativas e sistemas alimentadores;
4. usuário, produto, estabelecimento, programa e evento;
5. integração com RENAME, CATMAT, SIGTAP e CNES;
6. acesso, transparência e restrições;
7. qualidade, cobertura e continuidade histórica;
8. potencial para estudos de utilização de medicamentos.

### Capítulo 17 — SIES

1. Sistema de Informação de Insumos Estratégicos;
2. programação, aquisição, distribuição e estoque;
3. imunobiológicos, medicamentos e outros insumos estratégicos;
4. unidade de registro e fluxos logísticos;
5. responsabilidades federais e subnacionais;
6. dados publicados e indicadores possíveis;
7. relação com BNAFAR e registros de vacinação;
8. limites para avaliação de disponibilidade e consumo.

### Capítulo 18 — SISAGUA

1. Sistema de Informação de Vigilância da Qualidade da Água para Consumo Humano;
2. formas de abastecimento e pontos de monitoramento;
3. parâmetros, amostras e resultados;
4. território, população abastecida e instituição responsável;
5. dados disponíveis na API do DEMAS e no Portal de Dados Abertos;
6. interpretação sanitária e temporal;
7. qualidade, completude e alterações de cobertura;
8. exemplos de análise territorial.

### Capítulo 19 — SISVAN

1. Sistema de Vigilância Alimentar e Nutricional;
2. indivíduos, acompanhamentos e marcadores de consumo;
3. estado nutricional e medidas antropométricas;
4. população acompanhada e população residente;
5. integração com Atenção Primária e território;
6. painéis, relatórios e dados abertos;
7. cobertura, seleção e comparabilidade;
8. exemplos por ciclo de vida.

### Capítulo 20 — Informação econômica, financeira e de custos

1. Fundo Nacional de Saúde;
2. InvestSUS;
3. Banco de Preços em Saúde;
4. ApuraSUS;
5. transferências, despesas, preços, quantidades e custos;
6. CATMAT e identificação do item adquirido;
7. inflação, competência financeira e unidade monetária;
8. integração com produção, população e território;
9. limites de comparação de preços e de inferência de custos.

### Capítulo 21 — Portais, APIs, tabuladores e painéis

1. Portal de Dados Abertos do SUS;
2. API de Dados Abertos do DEMAS;
3. dados.gov.br;
4. TabNet e tabuladores do SUS;
5. LocalizaSUS e painéis temáticos;
6. arquivos para uso local;
7. API, CSV, JSON, XML, DBC, DBF e Parquet;
8. metadados, licença, frequência e responsável;
9. critérios para extração reprodutível;
10. catálogo pesquisável no Navegador de Dados do SUS.

## Parte III — Informática em saúde, semântica e governança

### Capítulo 22 — Dado, informação, conhecimento e modelo

1. dado, informação, conhecimento e evidência;
2. modelo conceitual, lógico e físico;
3. entidade, atributo, domínio, chave e evento;
4. metadado e dicionário de dados;
5. identificador, classificação, terminologia e ontologia;
6. dado administrativo, clínico e epidemiológico;
7. proveniência, versionamento e linhagem;
8. qualidade e adequação ao uso.

### Capítulo 23 — Interoperabilidade em saúde

1. interoperabilidade técnica, sintática, semântica e organizacional;
2. modelos de informação;
3. HL7 FHIR;
4. terminologias e serviços terminológicos;
5. mapeamento, equivalência e perda semântica;
6. interoperabilidade entre cuidado e análise secundária;
7. governança do intercâmbio;
8. exemplos em prescrição, dispensação, vacinação e eventos adversos.

### Capítulo 24 — Classificações e referências clínicas

1. CID-10 e evolução para revisões posteriores;
2. CIAP-2;
3. SIGTAP;
4. SNOMED CT;
5. LOINC;
6. códigos municipais, regiões de saúde e outras dimensões territoriais;
7. versões e vigências;
8. critérios para combinar fontes.

### Capítulo 25 — Medicamentos: listas, catálogos e padrões

1. RENAME;
2. CATMAT;
3. ATC/DDD;
4. IDMP;
5. Ontologia Brasileira de Medicamentos;
6. WHODrug Global;
7. medicamento virtual, medicamento comercial, apresentação e substância;
8. relação com SIGTAP, CMED e produtos registrados;
9. mapeamentos e perdas semânticas;
10. estudos de utilização, farmacovigilância e compras públicas.

### Capítulo 26 — Saúde digital, RNDS e governança federada

1. PNIIS e Estratégia de Saúde Digital;
2. transformação digital e cuidado direcionado por dados;
3. Rede Nacional de Dados em Saúde;
4. Meu SUS Digital;
5. governança tripartite e autonomia federativa;
6. arquitetura centralizada, distribuída e federada;
7. blockchain, permissionamento e nós federados;
8. continuidade do cuidado e uso secundário;
9. proteção de dados, segurança e soberania informacional;
10. limites da tecnologia sem mudança de processos e governança.

### Capítulo 27 — Privacidade, confidencialidade e uso responsável

1. dados pessoais e dados pessoais sensíveis;
2. finalidade, necessidade e proporcionalidade;
3. pseudonimização, anonimização e risco de reidentificação;
4. controle de acesso e rastreabilidade;
5. pesquisa, gestão e vigilância;
6. uso secundário e compartilhamento;
7. segurança do paciente e confiança institucional;
8. documentação de decisões e limitações.

## Parte IV — Ferramentas para tratamento de dados

### Capítulo 28 — Arquitetura do ambiente analítico

1. arquivos, bancos relacionais, lagos e lakehouses;
2. camadas de ingestão, tratamento e publicação;
3. processamento local, servidor e nuvem;
4. armazenamento, memória e transferência;
5. logs, auditoria, retomada e idempotência;
6. gestão de segredos e permissões;
7. reprodutibilidade e versionamento;
8. dimensionamento para bilhões de registros.

### Capítulo 29 — Sistema Gerenciador de Banco de Dados

1. finalidade de um SGBD;
2. PostgreSQL;
3. modelagem relacional;
4. normalização e desnormalização;
5. esquemas, tabelas, chaves e restrições;
6. índices e particionamento;
7. `COPY`, transações e cargas em lote;
8. SQL analítico e janelas;
9. integração com R e Python;
10. controle de qualidade no banco.

### Capítulo 30 — Bash: linguagem operacional dos servidores

1. shell, processos, entrada e saída;
2. caminhos, permissões e manipulação segura de arquivos;
3. `curl`, `wget`, `find`, `rg`, `awk`, `sed`, `sort`, `paste` e `iconv`;
4. pipes e substituição de processos;
5. loops por sistema, subsistema, UF e competência;
6. logs, códigos de saída e tratamento de erro;
7. cron e execução programada;
8. retomada, idempotência e paralelização;
9. integração com `psql`, R e Wine;
10. exemplos extraídos do ETL SABEIS.

### Capítulo 31 — DBC, DBF e `dbf2dbc.exe`

1. dBase/DBF e o formato DBC;
2. estrutura e cabeçalho dos arquivos;
3. pacote TabWin e `Tab415.zip`;
4. `dbf2dbc.exe` como utilitário de conversão DBC/DBF;
5. descompactação DBC → DBF;
6. compactação DBF → DBC;
7. execução via Wine em Linux;
8. validação por bytes, cabeçalho e número de registros;
9. conversão DBF → CSV com `dbview` e tratamento de codificação;
10. alternativas livres, incluindo `read.dbc` e `microdatasus`;
11. limitações de software proprietário e reprodutibilidade.

### Capítulo 32 — Projeto R

1. projetos, pacotes, funções e organização de scripts;
2. `data.table`, `dplyr`, `DBI` e `RPostgres`;
3. leitura, limpeza e validação;
4. integração com PostgreSQL;
5. Parquet, Arrow e DuckDB;
6. tabelas, gráficos e relatórios;
7. Quarto e parâmetros;
8. `renv` e ambientes reproduzíveis;
9. testes e verificações;
10. acesso SFTP à SABEIS.

### Capítulo 33 — Python

1. ambientes e dependências;
2. leitura de arquivos e APIs;
3. automação e processamento tabular;
4. integração com PostgreSQL e DuckDB;
5. processamento de linguagem natural;
6. classificação de medicamentos por ATC como estudo de caso;
7. testes, logs e linha de comando;
8. critérios para escolher Bash, R ou Python.

### Capítulo 34 — microdatasus

1. finalidade e sistemas de informação suportados;
2. aquisição e pré-processamento;
3. conveniência para extrações pontuais;
4. dicionários e transformação de variáveis;
5. comparação com ETL próprio e arquivos brutos;
6. versões, rastreabilidade e escala;
7. validação do resultado;
8. uso complementar à arquitetura principal.

### Capítulo 35 — Parquet e DuckDB

1. armazenamento colunar;
2. compressão e tipos de dados;
3. particionamento por sistema, ano, competência e UF;
4. conversão de PostgreSQL ou CSV para Parquet;
5. consulta direta com DuckDB;
6. leitura seletiva e *predicate pushdown*;
7. metadados e estatísticas;
8. controle de completude;
9. publicação e intercâmbio de extratos;
10. comparação com banco relacional.

## Parte V — Método SABEIS: aquisição, ETL e validação

### Capítulo 36 — Inventário dos arquivos disseminados

1. identificação dos diretórios e fontes atuais;
2. listagem automatizada dos arquivos;
3. nome do arquivo, sistema de informação, subsistema, UF e competência;
4. datas, horas, tamanho e número de registros;
5. normalização de caixa, sufixos e arquivos complementares;
6. tabela de controle de coleta;
7. histórico de mudanças e desaparecimento de arquivos;
8. atualização do método de listagem publicado em 2022.

### Capítulo 37 — Download e verificação inicial

1. download com retomada e prevenção de sobrescrita;
2. comparação do tamanho remoto e local;
3. contagem de registros no DBC;
4. persistência do inventário no PostgreSQL;
5. identificação de transferências incompletas;
6. nova tentativa controlada;
7. armazenamento temporário e descarte seguro;
8. logs e indicadores da ingestão.

### Capítulo 38 — Conversão e transformação DBC → DBF → CSV

1. execução de `dbf2dbc.exe` com Wine;
2. localização do DBF produzido;
3. comparação do número de registros DBC e DBF;
4. leitura da estrutura do DBF;
5. conversão com `dbview`;
6. tratamento de CP861 e UTF-8;
7. delimitadores, aspas e caracteres especiais;
8. rejeição controlada de linhas com cardinalidade inválida;
9. registro das métricas de transformação;
10. validação antes da carga.

### Capítulo 39 — Padronização e carga no PostgreSQL

1. harmonização dos nomes de atributos;
2. seleção das variáveis usadas em ATS;
3. tipos SQL e domínios;
4. tabela de fatos e dimensões;
5. organização dos esquemas por sistema e subsistema;
6. criação de tabelas e carga com `COPY`;
7. tabelas mensais por UF e competência;
8. índices, herança ou particionamento;
9. consolidação de arquivos `a`, `b` e `c`;
10. rastreabilidade até o arquivo de origem.

### Capítulo 40 — Reconciliação dos subsistemas do SIA

1. PA como corpo da produção ambulatorial;
2. AM e laudos de medicamentos;
3. AQ, AR, AN, BI e PS;
4. número da APAC, CNES, gestão e competência;
5. identificador pseudonimizado do usuário;
6. transposição dos caracteres do identificador;
7. atualização do identificador no PA;
8. quantidade aprovada e código SIGTAP;
9. procedimentos do grupo 06;
10. duplicidade, conflito e cardinalidade dos pareamentos.

### Capítulo 41 — Repositório SABEIS e extratos de medicamentos

1. separação entre repositório completo do SIA e extrato SABEIS;
2. seleção dos procedimentos de medicamentos;
3. transferência entre servidores;
4. tabelas de controle de coleta;
5. consolidação por UF e competência;
6. coortes e tabelas analíticas;
7. proveniência e data de geração;
8. atualização incremental;
9. documentação dos dados publicados;
10. licenças de software e de base de dados.

### Capítulo 42 — Validação do ETL SABEIS

1. qualidade do download por número de arquivos e bytes;
2. qualidade da conversão DBC → DBF;
3. comparação entre registros DBC, CSV e PostgreSQL;
4. identificação de arquivos discrepantes;
5. validação da extração de dispensações;
6. quantidade aprovada por UF e competência;
7. comparação com TabNet;
8. detecção de oscilações temporais atípicas;
9. correspondência com bases de vinculação de registros;
10. documentação de exceções e limites.

### Capítulo 43 — Coortes SABEIS, demanda aferida e monitoramento

1. definição do evento, exposição e desfecho;
2. unidade de análise e período de seguimento;
3. critérios de inclusão e exclusão;
4. PCDT, CID, SIGTAP e território;
5. novos usuários, persistência e troca de tratamento;
6. usuários, registros, procedimentos e quantidades;
7. demanda aferida e impacto orçamentário;
8. monitoramento pós-incorporação;
9. custos e valores corrigidos;
10. validade, viés e limites de inferência.

### Capítulo 44 — Acesso SFTP à SABEIS com R

1. diagnóstico do suporte SFTP;
2. credenciais públicas `livre:12345`;
3. listagem do repositório;
4. gramática dos nomes dos arquivos;
5. seleção por PCDT, tecnologia, UF e período;
6. download atômico;
7. leitura e validação da contagem;
8. perfil mínimo da base;
9. tratamento de erro e retomada;
10. registro de proveniência no projeto analítico.

## Parte VI — Navegador de Dados do SUS

### Capítulo 45 — Catálogo e arquitetura do Navegador

1. finalidade e público-alvo;
2. inventário de sistemas de informação, fontes e arquivos;
3. responsabilidade institucional e área gestora;
4. navegação por tema, sistema, arquivo, competência e UF;
5. metadados, dicionários e caminhos de origem;
6. formatos, frequência, período e licença;
7. busca e filtros;
8. exportação do catálogo;
9. integração com Bash, R, Python e DuckDB;
10. atualização e auditoria do catálogo.

### Capítulo 46 — Instalação e prática com o Navegador

1. conteúdo e licença do ZIP;
2. verificação por SHA-256;
3. requisitos e instalação;
4. execução local;
5. descoberta de uma fonte;
6. seleção de período e território;
7. aquisição e preparação;
8. validação inicial;
9. documentação do caminho percorrido;
10. resolução de problemas.

## Parte VII — Aplicações analíticas

### Capítulo 47 — Medidas epidemiológicas para impacto orçamentário

1. população-alvo;
2. incidência, prevalência e cobertura;
3. demanda epidemiológica e demanda aferida;
4. adoção, difusão e participação de mercado;
5. quantidade por usuário e duração do tratamento;
6. preços, custos e correção monetária;
7. cenários e incerteza;
8. relação entre PCDT, coorte e modelo;
9. validação com dados observados;
10. limitações e transparência.

### Capítulo 48 — Estudos de utilização de medicamentos

1. fontes brasileiras e acesso aos dados;
2. RENAME, CATMAT, SIGTAP e ATC/DDD;
3. prevalência de uso e consumo;
4. novos usuários e coortes;
5. persistência, adesão e troca;
6. custos e padrões territoriais;
7. farmacovigilância e eventos adversos;
8. desigualdade de acesso;
9. qualidade e comparabilidade;
10. publicação reprodutível.

### Capítulo 49 — Monitoramento pós-incorporação

1. pergunta de monitoramento;
2. população elegível e tratada;
3. implementação e tempo até a oferta;
4. utilização e difusão territorial;
5. custo por paciente e impacto observado;
6. efetividade e segurança quando observáveis;
7. variação entre estados e estabelecimentos;
8. limites dos dados administrativos;
9. devolução dos resultados aos gestores;
10. aprendizagem para reavaliação da tecnologia.

# 5. Bloco B — ementa ampliada e incorporação das fontes

## 5.1 Núcleo SABEIS: incorporação do relatório ETL

O relatório técnico da SABEIS será incorporado de forma extensa nos capítulos
36 a 43. A redação do livro reorganizará o material para fins didáticos, manterá
os algoritmos e explicará as decisões técnicas. A atualização institucional não
apagará o contexto histórico do relatório.

| Seção do relatório ETL | Conteúdo a incorporar | Destino principal |
|---|---|---|
| 3.1 Recursos de software e hardware | PostgreSQL, Bash, SQL, OLAP, fatos, dimensões, desnormalização e dimensionamento | capítulos 28 a 30 e 39 |
| 3.2 Fonte de dados | DBC, DBF, TabWin/TabNet, diretórios, sistemas e subsistemas | capítulos 2, 5 a 21 e 31 |
| 3.3.1 Listagem | inventário remoto, nome do arquivo, UF, ano, mês, sistema e subsistema | capítulo 36 |
| 3.3.2 Download | `wget`, retomada e armazenamento temporário | capítulo 37 |
| 3.3.3 Bytes e registros do DBC | controle da transferência e tabela de coleta | capítulos 37 e 42 |
| 3.3.4 DBC para DBF | `dbf2dbc.exe`, Wine, desempenho e reprodutibilidade | capítulos 31 e 38 |
| 3.3.5 Registros do DBF | validação da conversão | capítulos 38 e 42 |
| 3.3.6 DBF para CSV | `dbview`, codificação e delimitador | capítulo 38 |
| 3.3.7 Padronização | equivalência de atributos entre sistemas e subsistemas | capítulo 39 |
| 3.3.8 Identificador e consolidação | transposição do identificador pseudonimizado e estrutura comum | capítulo 40 |
| 3.3.9 Carga | criação de tabela e `COPY` no PostgreSQL | capítulo 39 |
| 3.3.10 Atualização do PA | vinculação do PA a AM, AQ, AR, AN, BI e PS | capítulo 40 |
| 3.3.11 Consolidação | carga por UF e mês e transferência entre servidores | capítulo 41 |
| 4.1 Qualidade do download | comparação de arquivos e bytes | capítulo 42 |
| 4.2 Qualidade da transformação | comparação DBC, DBF, CSV e PostgreSQL | capítulo 42 |
| 4.3 Dispensações | validação dos extratos de medicamentos | capítulos 41 e 42 |
| 4.4 Comparação com TabNet | quantidade aprovada por UF e mês | capítulo 42 |
| 4.5 SABEIS e vinculação | correspondência de usuários e registros | capítulos 42 e 43 |

### Diretriz para `dbf2dbc.exe`

O livro reproduzirá o comando empregado na metodologia SABEIS para
descompactação:

```bash
exe="Tab415/dbf2dbc.exe"
wine "$exe" "$fdbc"
```

O texto também apresentará o uso inverso para compactação quando necessário.
Não se ensinará a associação rígida e incorreta de que `dbf2dbc.exe` serviria
somente para compactar.

## 5.2 Publicações de Felipe Ferré por eixo do livro

| Eixo | Publicações prioritárias | Incorporação prevista |
|---|---|---|
| Gestão e ciclo de vida dos dados | `Ferre2024GestaoDados`; `Ferre2023ModelagemSQL` | fundamentos de modelagem, SQL, qualidade, armazenamento, integração com R e governança |
| Dados ambulatoriais e SABEIS | `FerreEtAl2025SaudeDebatePT`; `FerreEtAl2020SBCAS` | estrutura do SIA, processamento de bilhões de registros, sala de situação, PCDT e monitoramento |
| Monitoramento pós-incorporação | `SantosEtAl2024JAFF` | coortes, implementação, utilização, custos e impacto observado |
| Fontes para utilização de medicamentos | `LealEtAl2022Frontiers` | inventário de fontes, acesso, cobertura, granularidade e classificações |
| Impacto orçamentário e custos | `BrandaoEtAl2013RSP`; `Ferre2023ModelagemSQL` | coortes, relacionamento de bases, gastos e modelagem reprodutível |
| Informação para decisão | `Ferre2021Infoestrutura`; `Ferre2023DadosTecnologias` | infoestrutura, salas de situação, capacidade analítica e tradução do dado em intervenção |
| Transformação digital | `Ferre2026IHMT`; `SanzovoJensenFerre2026Transformacao` | cuidado direcionado por dados, processos, valor, segurança e sustentabilidade do SUS |
| Governança federada | `FerreGoncalvesGoncalves2026Blockchain` | RNDS, federalismo, arquitetura, permissionamento e governança tripartite |
| Privacidade e segurança | `FerreLima2026Privacidade` | confidencialidade, uso secundário, governança de acesso e segurança do paciente |
| Notificação e aprendizagem | `FerreMansanoOliveira2026Notificacao` | fragmentação dos sistemas de notificação, taxonomias, retorno aos serviços e aprendizagem |

## 5.3 Materiais fornecidos no projeto

| Material | Conteúdo aproveitado | Capítulos de destino |
|---|---|---|
| `FIPE 2023 Dados e medidas epidemiológicas para análise do impacto orçamentário (1).pptx` | demanda aferida, coortes, SIGTAP, PCDT, medicamentos, impacto orçamentário, ATC e ontologia | 4, 25, 40, 43 e 47 |
| `AnvisaAula2026-05(2).pptx` | KDD, modelagem de dados, SIA, SIH, SINAN, CNES, dados da Anvisa, ATC/DDD, R, Python e IA | 5, 6, 8, 11, 25, 32, 33 e 48 |
| `FELIPEFERREversaofinal2023-05-23(1).pptx` | arquitetura federada, PNIIS, RNDS, governança tripartite, FHIR e blockchain | 1, 23 e 26 |
| `Ontologia em Economia da Saúde.docx` | organização conceitual, terminologia, relações semânticas e economia da saúde | 22, 24, 25 e 47 |
| `MAD_26112025.pdf` | material de apoio a ser indexado por capítulo após validação temática | matriz bibliográfica dos capítulos correspondentes |

## 5.4 Critérios de incorporação

1. cada capítulo deverá indicar quais fontes primárias sustentam sua ementa;
2. publicações do portfólio serão usadas como eixo, não apenas em notas finais;
3. códigos do ETL serão transpostos para arquivos executáveis do repositório;
4. resultados históricos serão identificados com data de referência;
5. dados e caminhos atuais serão validados antes da publicação;
6. citações usarão chaves BibTeX estáveis;
7. trechos reproduzidos conservarão autoria, contexto e licença;
8. divergências entre documentação histórica e estrutura atual serão
   explicitadas.

# 6. Apêndices

## Apêndice A — Catálogo de sistemas de informação, fontes e arquivos

Tabela pesquisável com:

- tema;
- sistema de informação, cadastro ou plataforma;
- área gestora;
- órgão disseminador;
- sigla do arquivo;
- nome e descrição;
- unidade de análise;
- período disponível;
- frequência;
- formato;
- URL de origem;
- dicionário de dados;
- licença;
- observações de layout.

## Apêndice B — Inventário completo do SINAN

## Apêndice C — Glossário de informática em saúde

## Apêndice D — Instalação do ambiente

## Apêndice E — Checklist de qualidade e reprodutibilidade

## Apêndice F — Consultas SQL e scripts Bash, R e Python

## Apêndice G — Mapa de referências e chaves BibTeX

# 7. Estrutura prevista do repositório

```text
livro-dados-sus/
├── _quarto.yml
├── index.qmd
├── README.md
├── LICENSE.md
├── renv.lock
├── referencias.bib
├── capitulos/
│   ├── 01-sus-sistema-saude.qmd
│   ├── 02-demas-disseminacao.qmd
│   ├── 03-iniciativa-sabeis.qmd
│   ├── ...
│   └── 49-monitoramento-pos-incorporacao.qmd
├── apendices/
├── dados/
│   └── catalogo-fontes-sus.csv
├── scripts/
│   ├── bash/
│   ├── r/
│   ├── python/
│   └── sql/
├── imagens/
├── software/
│   ├── navegador-dados-sus.zip
│   └── navegador-dados-sus.zip.sha256
└── docs/
    └── .nojekyll
```

# 8. Referências nucleares e BibTeX inicial

As entradas abaixo foram selecionadas do portfólio público de Felipe Ferré e
serão movidas para `referencias.bib` na criação do repositório do livro.

```bibtex
@misc{Sabeis2022ETL,
  author  = {{Equipe SABEIS}},
  title   = {Relatório técnico contendo descrição da validação do processo de Extração, Transformação e Carga de registros de dispensação de medicamentos regidos por Protocolo Clínico e Diretriz Terapêutica contidos na Sala Aberta de Inteligência em Saúde -- SABEIS},
  year    = {2022},
  url     = {https://rpubs.com/sabeis/etl},
  urldate = {2026-11-17}
}

@online{BrasilDEMAS2026,
  author  = {{Brasil. Ministério da Saúde}},
  title   = {Departamento de Monitoramento, Avaliação e Disseminação de Informações Estratégicas em Saúde},
  year    = {2026},
  url     = {https://www.gov.br/saude/pt-br/composicao/seidigi/demas},
  urldate = {2026-11-17}
}

@online{BrasilAPIDEMAS2026,
  author  = {{Brasil. Ministério da Saúde}},
  title   = {DEMAS -- API de Dados Abertos},
  year    = {2026},
  url     = {https://apidadosabertos.saude.gov.br/},
  urldate = {2026-11-17}
}

@book{Ferre2024GestaoDados,
  author    = {Ferré, Felipe},
  title     = {Gestão de dados de saúde},
  publisher = {Cegraf/UFG},
  address   = {Goiânia},
  year      = {2024},
  pages     = {216},
  isbn      = {978-85-495-1042-6},
  doi       = {10.5216/FER.ges.ebook.978-85-495-1042-6/2024},
  url       = {https://doi.org/10.5216/FER.ges.ebook.978-85-495-1042-6/2024}
}

@incollection{Ferre2023ModelagemSQL,
  author    = {Ferré, Felipe},
  title     = {Modelagem e gestão de banco de dados com SQL e integração com o R},
  booktitle = {Avaliação de impacto das políticas de saúde: um guia para o SUS},
  editor    = {Aragão, Erika Santos de and Souza, Luís Eugenio Portela Fernandes de and Natividade, Marcio Santos da and Mendes, Vinícius de Araújo},
  publisher = {Ministério da Saúde},
  address   = {Brasília},
  year      = {2023},
  pages     = {435--501},
  isbn      = {978-65-5993-537-6},
  url       = {https://bvsms.saude.gov.br/bvs/publicacoes/avaliacao_impacto_politicas_saude_guia_sus.pdf}
}

@article{FerreEtAl2025SaudeDebatePT,
  author   = {Ferré, Felipe and Lyrio, Amanda Oliveira and Carvalho, Samara Helena de and Pantuzza, Laís Lessa Neiva and Santos, Jéssica Barreto Ribeiro dos and Lopes, Ana Carolina de Freitas and Bonan, Luciene Fontes Schluckebier},
  title    = {Potencial no monitoramento em saúde: explorando os dados abertos ambulatoriais do SUS},
  journal  = {Saúde em Debate},
  volume   = {49},
  number   = {spe1},
  year     = {2025},
  pages    = {e10004},
  doi      = {10.1590/2358-28982025E110004P},
  url      = {https://doi.org/10.1590/2358-28982025E110004P},
  language = {Portuguese}
}

@inproceedings{FerreEtAl2020SBCAS,
  author    = {Ferré, Felipe and Oliveira, Gustavo Laine Araújo de and Queiroz, Mariana Jorge de and Gonçalves, Flávio},
  title     = {Sala de Situação aberta com dados administrativos para gestão de Protocolos Clínicos e Diretrizes Terapêuticas de tecnologias providas pelo SUS},
  booktitle = {Anais Principais do XX Simpósio Brasileiro de Computação Aplicada à Saúde},
  publisher = {Sociedade Brasileira de Computação},
  address   = {Porto Alegre},
  year      = {2020},
  pages     = {392--403},
  doi       = {10.5753/sbcas.2020.11530},
  url       = {https://doi.org/10.5753/sbcas.2020.11530}
}

@article{SantosEtAl2024JAFF,
  author  = {Santos, Jéssica Barreto Ribeiro dos and Lyrio, Amanda Oliveira and Ferré, Felipe and Mega, Tacila Pires and Lopes, Ana Carolina de Freitas and Bonan, Luciene Fontes Schluckebier},
  title   = {Monitoramento pós incorporação no Sistema Único de Saúde: uma análise de Infliximabe, Vedolizumabe e Tofacitinibe para o tratamento da Retocolite Ulcerativa},
  journal = {Jornal de Assistência Farmacêutica e Farmacoeconomia},
  volume  = {9},
  number  = {1},
  year    = {2024},
  pages   = {44--57},
  doi     = {10.22563/2525-7323.2024.v9.n.1.p.44-57},
  url     = {https://doi.org/10.22563/2525-7323.2024.v9.n.1.p.44-57}
}

@article{LealEtAl2022Frontiers,
  author  = {Leal, Lisiane Freitas and Osorio-de-Castro, Claudia Garcia Serpa and Souza, Luiz Júpiter Carneiro de and Ferré, Felipe and Mota, Daniel Marques and Ito, Marcia and Elseviers, Monique and Lima, Elisangela da Costa and Zimmermann, Ivan Ricardo and Fulone, Izabela and Carvalho-Soares, Monica da Luz and Lopes, Luciane Cruz},
  title   = {Data Sources for Drug Utilization Research in Brazil—DUR-BRA Study},
  journal = {Frontiers in Pharmacology},
  volume  = {12},
  year    = {2022},
  pages   = {789872},
  doi     = {10.3389/fphar.2021.789872},
  url     = {https://doi.org/10.3389/fphar.2021.789872}
}

@article{Ferre2026IHMT,
  author  = {Ferré, Felipe},
  title   = {Transformação digital e sustentabilidade do Sistema Único de Saúde: Cuidado Direcionado por Dados, valor e cooperação em saúde},
  journal = {Anais do Instituto de Higiene e Medicina Tropical},
  volume  = {25},
  number  = {1},
  year    = {2026},
  pages   = {104--120},
  doi     = {10.25761/anaisihmt.568},
  url     = {https://doi.org/10.25761/anaisihmt.568}
}

@article{FerreGoncalvesGoncalves2026Blockchain,
  author  = {Ferré, Felipe and Gonçalves, Andrea de Oliveira and Gonçalves, Rodrigo de Souza},
  title   = {Uma arquitetura tecnológica como a blockchain pode induzir o modelo de governança federada da Rede Nacional de Dados em Saúde?},
  journal = {Revista Tecnologia e Sociedade},
  volume  = {22},
  number  = {69},
  year    = {2026},
  pages   = {124--156},
  doi     = {10.3895/rts.v22n69.20223},
  url     = {https://doi.org/10.3895/rts.v22n69.20223}
}

@incollection{SanzovoJensenFerre2026Transformacao,
  author    = {Sanzovo, Osmeire Aparecida Chamelette and Jensen, Rodrigo and Ferré, Felipe},
  title     = {A transformação digital no Sistema Único de Saúde: um guia para gestores e profissionais de saúde},
  booktitle = {Segurança do Paciente no SUS: Inovação, Evidência e Governança para o Cuidado Confiável},
  editor    = {André, Carla Ulhoa and Santos, Aline Matilde Ferreira dos},
  series    = {Conass Documenta},
  number    = {51},
  publisher = {Conselho Nacional de Secretários de Saúde},
  address   = {Brasília},
  year      = {2026},
  pages     = {783--798},
  isbn      = {978-65-88631-54-6},
  url       = {https://www.conass.org.br/biblioteca/conass-documenta-51/}
}

@incollection{FerreLima2026Privacidade,
  author    = {Ferré, Felipe and Lima, Monica},
  title     = {Confidencialidade e privacidade da informação em saúde e segurança do paciente},
  booktitle = {Segurança do Paciente no SUS: Inovação, Evidência e Governança para o Cuidado Confiável},
  editor    = {André, Carla Ulhoa and Santos, Aline Matilde Ferreira dos},
  series    = {Conass Documenta},
  number    = {51},
  publisher = {Conselho Nacional de Secretários de Saúde},
  address   = {Brasília},
  year      = {2026},
  pages     = {929--944},
  isbn      = {978-65-88631-54-6},
  url       = {https://www.conass.org.br/biblioteca/conass-documenta-51/}
}

@incollection{FerreMansanoOliveira2026Notificacao,
  author    = {Ferré, Felipe and Mansano, Nereu Henrique and Oliveira, Maria Cecília},
  title     = {Sistema de notificação de eventos adversos no Brasil: o que temos e o que falta?},
  booktitle = {Segurança do Paciente no SUS: Inovação, Evidência e Governança para o Cuidado Confiável},
  editor    = {André, Carla Ulhoa and Santos, Aline Matilde Ferreira dos},
  series    = {Conass Documenta},
  number    = {51},
  publisher = {Conselho Nacional de Secretários de Saúde},
  address   = {Brasília},
  year      = {2026},
  pages     = {847--870},
  isbn      = {978-65-88631-54-6},
  url       = {https://www.conass.org.br/biblioteca/conass-documenta-51/}
}

@incollection{Ferre2023DadosTecnologias,
  author    = {Ferré, Felipe},
  title     = {Dados, tecnologias de informação e intervenção na saúde},
  booktitle = {Políticas Públicas Integradas para Fortalecer o SUS: um projeto nacional e participativo de desenvolvimento social},
  editor    = {Leite, Silvana Nair and Veiga, Adelir da and Manzini, Fernanda},
  publisher = {Instituto Escola Nacional dos Farmacêuticos},
  address   = {São Paulo},
  year      = {2023},
  pages     = {124--141},
  isbn      = {978-65-996479-2-5},
  url       = {https://escoladosfarmaceuticos.org.br/9-simposio/}
}

@incollection{Ferre2021Infoestrutura,
  author    = {Ferré, Felipe},
  title     = {Infoestrutura para apoio à decisão estratégica no SUS},
  booktitle = {Reflexões e futuro},
  editor    = {Santos, Alethele de Oliveira and Lopes, Luciana Tolêdo},
  series    = {Coleção Covid-19},
  volume    = {6},
  publisher = {Conselho Nacional de Secretários de Saúde},
  address   = {Brasília},
  year      = {2021},
  pages     = {114--135},
  url       = {https://www.conass.org.br/biblioteca/volume-6-reflexoes-e-futuro/}
}

@article{BrandaoEtAl2013RSP,
  author  = {Brandão, Cristina Mariano Ruas and Ferré, Felipe and Machado, Gustavo Pinto da Matta and Guerra Júnior, Augusto Afonso and Andrade, Eli Iola Gurgel and Cherchiglia, Mariângela Leal and Acurcio, Francisco de Assis},
  title   = {Gastos públicos com medicamentos para o tratamento da osteoporose na pós-menopausa},
  journal = {Revista de Saúde Pública},
  volume  = {47},
  number  = {2},
  year    = {2013},
  pages   = {390--402},
  doi     = {10.1590/S0034-8910.2013047004163},
  url     = {https://doi.org/10.1590/S0034-8910.2013047004163}
}
```

# 9. Sequência de produção após aprovação da v0.2

1. criar o repositório definitivo do livro;
2. criar a estrutura mínima do Quarto Book;
3. criar `referencias.bib` com as entradas do portfólio;
4. produzir primeiro o Capítulo 44, aula-núcleo de acesso SFTP à SABEIS;
5. desenvolver os capítulos 36 a 43, que formam o núcleo metodológico;
6. montar o catálogo de sistemas de informação e fontes;
7. incorporar o ZIP do Navegador de Dados do SUS;
8. escrever os demais capítulos em iterações independentes;
9. renderizar e testar localmente no RStudio/Bequer;
10. publicar a primeira versão navegável somente após a validação do núcleo.

# 10. Pendências para a v0.3

1. confirmar o título definitivo;
2. confirmar o nome do repositório do livro;
3. validar a ordem dos 49 capítulos;
4. receber e inspecionar o ZIP do Navegador de Dados do SUS;
5. verificar licença e forma de distribuição do ZIP;
6. completar o catálogo de siglas, períodos e layouts;
7. atualizar URLs e protocolos de aquisição;
8. definir a licença do texto, do código e das bases derivadas;
9. decidir se capítulos longos serão divididos durante a redação;
10. transformar a matriz bibliográfica em `referencias.bib` e citações Quarto.
