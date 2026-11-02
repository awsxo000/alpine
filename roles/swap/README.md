# Role `swap`

Cria uma swapfile adicional sem alterar ou redimensionar as partições existentes. A configuração padrão mantém a partição atual e adiciona `/swapfile` com 12 GiB, resultando em aproximadamente 16 GiB de swap no notebook de teste.

A role verifica o espaço livre antes de criar o arquivo, aplica modo `0600`, inicializa a assinatura de swap, registra a entrada no `/etc/fstab` e ativa a swap sem reinicialização. Se o arquivo já existir com tamanho insuficiente, a execução falha de propósito para evitar perda de dados.

Quando `energia_habilitar_hibernacao` está ativa, a role também identifica
automaticamente a UUID da partição que contém `/`, calcula o primeiro offset
físico do swapfile e adiciona `resume=` e `resume_offset=` ao GRUB. Nenhum nome
fixo como `/dev/sdb3` é usado. O arquivo não deve ser apagado ou recriado depois
disso, pois o offset poderá mudar.

## Variáveis

- `swap_habilitada`: controla a role; padrão global: `true`.
- `swapfile_caminho`: caminho do arquivo; padrão: `/swapfile`.
- `swapfile_tamanho_gib`: tamanho adicional; padrão: `12`.
- `swapfile_reserva_livre_gib`: espaço livre mantido após a criação; padrão: `2`.
- `swapfile_prioridade`: prioridade da swapfile; padrão: `-1`.

Para máquinas com firmware ou drivers que não retomam corretamente, defina
`energia_habilitar_hibernacao: false` no inventário do host. A criação da
swapfile continuará ativa.
