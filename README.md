# Curso RebrATS 2026 - Dados da SABEIS via FTP utilizando R

Material do curso presencial do VII Congresso ReBrATS, em 18 de novembro de
2026, das 8h às 12h30.

## Produtos

- `curso_rebrats2026.Rmd`: fonte única da página e da apostila.
- `docs/index.html`: página estática autocontida, própria para GitHub Pages e
  para publicação no RPubs.
- `docs/Curso_REBRATS_2026_SABEIS_R.pdf`: apostila em PDF.
- `R/`: funções de acesso ao SFTP da SABEIS, seleção da versão correta do
  SIGTAP e análise do SIA.
- `data/`: dados sintéticos e tabelas auxiliares pequenas para contingência.
- `scripts/espelhar_sabeis_sftp.sh`: espelhamento opcional, sem exclusão, para
  uso na infraestrutura da SABEIS/LabX.

## Preparação do participante

Instale R (>= 4.3), RStudio e os pacotes do curso:

```r
source("R/instalar_pacotes.R")
```

Defina a senha pública fornecida em sala somente na sessão atual:

```r
Sys.setenv(SABEIS_SFTP_PASSWORD = "senha-informada-em-sala")
```

O código usa o usuário público `livre` por padrão. A senha não é versionada.

## Renderização

No RStudio, abra `curso_rebrats2026.Rmd` e use **Knit**. Para gerar os dois
formatos por linha de comando:

```bash
Rscript render.R
```

O HTML é autocontido. Nesse fluxo, o PDF requer uma distribuição LaTeX com
XeLaTeX. Também há uma rota estática, que não executa os blocos R e requer
Pandoc, Python com `python-docx` e LibreOffice:

```bash
bash scripts/render_static.sh
```

## Publicação

Recomendação: publicar `docs/` com GitHub Pages a partir da branch `main`.
O mesmo `docs/index.html` pode ser enviado ao RPubs como cópia estática.

Em uma cópia local previamente clonada e autenticada como colaborador,
publique as atualizações com:

```bash
bash scripts/publicar_github.sh
```

O script usa `git@github.com:sabeis-ats/curso_rebrats2026.git`, cria o primeiro
commit se necessário e executa `git push -u origin main` sem `--force`.

## Segurança e privacidade

- O servidor informado no curso usa **SFTP**, apesar do título histórico usar
  “FTP”.
- Não inclua senhas no Git.
- Valide a chave do host antes da primeira conexão.
- Não publique identificadores individuais. Os exemplos locais usam pessoas
  sintéticas e os exercícios terminam em resultados agregados.

## Licença

Conteúdo didático sob [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Código sob licença MIT. Consulte `LICENSE.md`.
