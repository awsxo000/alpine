# Role `swap`

Cria uma swapfile adicional sem alterar ou redimensionar as partições existentes. A configuração padrão mantém a partição atual e adiciona `/swapfile` com 12 GiB, resultando em aproximadamente 16 GiB de swap no notebook de teste.

A role verifica o espaço livre antes de criar o arquivo, aplica modo `0600`, inicializa a assinatura de swap, registra a entrada no `/etc/fstab` e ativa a swap sem reinicialização. Se o arquivo já existir com tamanho insuficiente, a execução falha de propósito para evitar perda de dados.

Esta role não habilita hibernação automaticamente. Para hibernar usando uma swapfile, ainda é necessário configurar `resume=` e `resume_offset=` no initramfs e no kernel.

## Variáveis

- `swap_habilitada`: controla a role; padrão global: `true`.
- `swapfile_caminho`: caminho do arquivo; padrão: `/swapfile`.
- `swapfile_tamanho_gib`: tamanho adicional; padrão: `12`.
- `swapfile_reserva_livre_gib`: espaço livre mantido após a criação; padrão: `2`.
- `swapfile_prioridade`: prioridade da swapfile; padrão: `-1`.
