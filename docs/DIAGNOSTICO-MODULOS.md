# Diagnóstico dos módulos

O backend oferece um diagnóstico somente leitura para cada módulo do Alpine Desktop Center:

```sh
make diagnostico-modulo MODULO=audio
```

Os módulos aceitos são definidos em `modulos.json`, a fonte única compartilhada
pelo diagnóstico e pelo frontend. Atualmente são `base`, `nix`, `steam`,
`nix_opengl`, `rede`, `bluetooth`, `audio`, `swap`, `energia`, `fontes` e `kde`.

A saída padrão é JSON com `schema_version: 1`. O comando não executa Ansible, não instala pacotes, não altera serviços e não modifica arquivos do sistema. Ele apenas consulta o estado atual.

O módulo `audio` considera a sessão PipeWire funcional quando `wpctl status`
e/ou `pactl info` conseguem acessar o servidor e identificar PipeWire. A
presença de processos via `pgrep` é apenas complementar, pois os serviços de
áudio podem ser iniciados na sessão do usuário e não como serviços OpenRC
tradicionais. Os checks de rede, Bluetooth e swap também validam o conteúdo da
consulta, não somente o código de saída do executável.

## Contrato

Cada resultado contém:

- `module`: módulo consultado;
- `checked_at`: data e hora com fuso;
- `status`: `complete`, `partial`, `incomplete` ou `unknown`;
- `summary`: contagem de verificações aprovadas, falhas, avisos e desconhecidas;
- `dependencies`: dependências conhecidas do módulo;
- `checks`: verificações individuais com `id`, `title`, `status`, `required` e `message`.

Os estados de uma verificação são:

- `ok`: componente presente e funcionando;
- `error`: requisito obrigatório ausente ou quebrado;
- `warning`: situação não ideal que não impede necessariamente o módulo;
- `unknown`: não foi possível concluir a verificação.

O diagnóstico é intencionalmente independente de `make diagnostico`, que continua sendo a execução detalhada do playbook Ansible. Essa separação permite observar o sistema sem aplicar mudanças. Os checks opcionais podem gerar avisos ou erros informativos, mas somente checks `required: true` determinam o status geral do módulo.

## Integração

O frontend deve chamar somente os módulos da lista fixa e tratar o JSON conforme `schema_version`. A saída pode ser reproduzida no terminal para auditoria e suporte:

```sh
make diagnostico-modulo MODULO=steam | python3 -m json.tool
```
