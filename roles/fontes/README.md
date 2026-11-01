# Role `fontes`

Instala fontes de sistema para ampliar a cobertura Unicode do KDE Plasma e dos aplicativos do desktop Alpine Linux 3.24.3.

A seleção inclui Noto para cobertura geral, `font-noto-cjk` para chinês, japonês e coreano, `font-noto-emoji` para emoji, `font-noto-extra` para alfabetos e símbolos adicionais, além de fontes de interface e monoespaçadas.

A role executa `fc-cache -f -v` depois da instalação. Não força uma nova fonte padrão do KDE: o Fontconfig faz fallback para uma fonte que possua o glifo quando a fonte principal não o contém.

## Variáveis

- `fontes_habilitadas`: controla a execução da role; padrão global: `true`.
- `fontes_pacotes_extras`: lista opcional para acrescentar pacotes disponíveis no repositório Alpine.

Depois da instalação, aplicativos já abertos podem precisar ser fechados e reabertos para recarregar a lista de fontes. Normalmente não é necessário reiniciar o computador.
