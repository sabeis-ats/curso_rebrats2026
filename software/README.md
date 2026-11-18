# Software

Este diretório contém o pacote-fonte do Navegador de Dados do SUS documentado nos capítulos 45 e 46.

| Arquivo | Descrição |
|---|---|
| `navegador/` | código-fonte extraído e legível da versão 14, organizado em pasta específica do curso |
| `rshiny_ftpsus_navegador.zip` | versão 14, com código R, configurações, catálogo, dicionários e trabalhos de demonstração |
| `rshiny_ftpsus_navegador.zip.sha256` | soma de verificação SHA-256 |

O diretório `navegador/` contém os pontos de entrada, os módulos em `R/` e os arquivos de configuração. Os RDS de catálogo e os resultados de demonstração permanecem no ZIP, pois são artefatos de execução.

Verificação:

```bash
sha256sum -c rshiny_ftpsus_navegador.zip.sha256
```

Resultado esperado:

```text
rshiny_ftpsus_navegador.zip: OK
```
