# Publicar o livro e a aula no GitHub Pages

O repositório publica dois produtos no mesmo endereço:

- livro Quarto: `https://sabeis-ats.github.io/curso_rebrats2026/`;
- aula R Markdown: `https://sabeis-ats.github.io/curso_rebrats2026/curso/`.

## 1. Configuração única no GitHub

1. Abra <https://github.com/sabeis-ats/curso_rebrats2026/settings/pages>.
2. Em **Build and deployment > Source**, selecione **GitHub Actions**.
3. Salve. Não selecione publicação a partir de uma pasta ou branch.

O fluxo já possui as permissões mínimas de `contents: read`, `pages: write` e
`id-token: write`.

## 2. Publicação automática

Cada `push` no `main` executa
`.github/workflows/publicar-pages.yml`. O processo:

1. instala Quarto e R;
2. instala `rmarkdown`, `knitr`, `curl`, `data.table` e `ggplot2`;
3. renderiza o livro em `_book/`;
4. executa `curso_rebrats2026.Rmd` com o exemplo reprodutível;
5. grava a aula em `_book/curso/index.html`;
6. publica `_book/` no GitHub Pages.

A publicação da aula usa `tentar_sftp = FALSE`. Isso testa tabelas e gráficos
sem tornar o servidor SFTP uma dependência do site.

## 3. Executar manualmente

1. Abra a aba **Actions** do repositório.
2. Selecione **Publicar livro e curso no GitHub Pages**.
3. Clique em **Run workflow**.
4. Escolha a branch `main` e confirme.

## 4. Verificar o resultado

Na execução do fluxo, confirme que os passos abaixo ficaram verdes:

- `Renderizar livro Quarto`;
- `Executar aula R Markdown`;
- `Enviar artefato do Pages`;
- `Publicar no GitHub Pages`.

Depois abra:

```text
https://sabeis-ats.github.io/curso_rebrats2026/
https://sabeis-ats.github.io/curso_rebrats2026/curso/
```

## 5. Compilar localmente antes do envio

Livro:

```bash
quarto render
```

Aula sem SFTP:

```bash
Rscript -e 'rmarkdown::render("curso_rebrats2026.Rmd", params=list(tentar_sftp=FALSE, baixar_dicionario=FALSE))'
```

Livro e aula no mesmo diretório de saída:

```bash
Rscript render.R
```

## 6. Problemas comuns

| Sintoma | Correção |
|:--|:--|
| Página 404 | conferir se **Source** está em **GitHub Actions** e aguardar o fluxo terminar |
| fluxo sem permissão | em **Settings > Actions > General**, permitir ações e fluxos de terceiros usados no YAML |
| erro em pacote R | reexecutar o fluxo; se persistir, verificar o passo de dependências |
| aula sem gráfico | verificar o log de `Executar aula R Markdown`; os três blocos gráficos não dependem do SFTP |
| domínio antigo em cache | atualizar forçadamente a página ou aguardar a propagação do Pages |

O arquivo `_book/` é resultado de compilação e não precisa ser versionado.
