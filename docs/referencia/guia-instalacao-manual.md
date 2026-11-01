# Alpine Linux + Nixpkgs — guia do que configuramos

**Ambiente:** Alpine 3.24.3, x86_64, usuário `saw`, OpenRC. O Nix instalado pelo `apk` foi 2.31.5. O canal selecionado foi `nixos-26.05` (Nixpkgs estável, sem flakes).

Este guia registra a configuração feita e separa os passos confirmados dos testes ainda não validados após reinicialização.

## 1. Instalar Nix no Alpine

Como usuário normal com `doas` configurado:

```sh
doas apk add nix nix-openrc
doas rc-update add nix-daemon default
doas rc-service nix-daemon start
```

O usuário precisa estar no grupo `nix` para acessar o daemon:

```sh
doas addgroup saw nix
```

Depois, encerre a sessão e entre novamente (ou reinicie) para aplicar a associação ao grupo. Confira:

```sh
id -nG
nix --version
doas rc-service nix-daemon status
```

No nosso caso, o erro `Connection reset by peer` em `nix-channel --update` foi resolvido quando a sessão passou a incluir o grupo `nix`.

## 2. Configurar o canal estável, sem flakes

Como o usuário `saw`, não como root:

```sh
nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
nix-channel --update
nix-channel --list
```

A listagem esperada contém:

```text
nixpkgs https://nixos.org/channels/nixos-26.05
```

Se já existir um canal chamado `nixpkgs` e a intenção for substituí-lo, remova-o antes de adicioná-lo novamente:

```sh
nix-channel --remove nixpkgs
nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
nix-channel --update
```

Não usamos flakes nem foi necessário habilitar `nix-command` experimental para esses passos.

## 3. Procurar e instalar programas no perfil do usuário

Exemplo de busca e instalação do `btop` (o comando de instalação é exemplo; não há confirmação de que o btop tenha sido instalado nesta sessão):

```sh
nix-env -f '<nixpkgs>' -qaP btop
nix-env -iA nixpkgs.btop
```

Instale pacotes como usuário normal, sem `doas`. Para remover um pacote do perfil:

```sh
nix-env -e btop
```

Evite instalar o mesmo programa tanto pelo `apk` quanto pelo perfil Nix, para não confundir qual versão está sendo executada.

## 4. Steam e pacotes não livres

Para permitir o pacote proprietário Steam no Nixpkgs, criamos esta configuração de usuário:

```sh
mkdir -p ~/.config/nixpkgs
cat > ~/.config/nixpkgs/config.nix <<'EOF'
{ allowUnfree = true; }
EOF
```

Busca e forma de instalação pelo canal configurado:

```sh
nix-env -f '<nixpkgs>' -qaP steam
nix-env -iA nixpkgs.steam
```

O Steam apareceu como instalado (`steam-1.0.0.85`). **Nota de transparência:** o registro da conversa confirma o pacote instalado, mas não preserva a linha exata que foi usada na instalação. O comando acima é a forma clássica sem flakes para reproduzi-la.

## 5. Mesa do Nix para o Steam

No Alpine, o Steam via ambiente FHS do Nix não encontrou automaticamente os caminhos de drivers gráficos que esperava. Baixamos Mesa de 64 e 32 bits do canal Nixpkgs e criamos links de saída persistentes, para que o Nix não os trate como resultados sem referência:

```sh
mkdir -p ~/.cache/nix-roots
nix-build '<nixpkgs>' -A mesa \
  --out-link "$HOME/.cache/nix-roots/mesa64"
nix-build '<nixpkgs>' -A pkgsi686Linux.mesa \
  --out-link "$HOME/.cache/nix-roots/mesa32"
```

Os drivers foram confirmados nestes resultados:

```sh
ls -l ~/.cache/nix-roots/mesa64/lib/dri/radeonsi_dri.so
ls -l ~/.cache/nix-roots/mesa32/lib/dri/radeonsi_dri.so
```

**Não apague** `~/.cache/nix-roots/mesa64` nem `~/.cache/nix-roots/mesa32`: são os links que mantêm esses resultados do Nix enraizados.

## 6. Recriar os links gráficos no boot com OpenRC

Criamos `/etc/local.d/opengl-drivers.start` com este conteúdo:

```sh
#!/bin/sh
set -eu

mesa64="$(readlink -f /home/saw/.cache/nix-roots/mesa64)"
mesa32="$(readlink -f /home/saw/.cache/nix-roots/mesa32)"

for mesa in "$mesa64" "$mesa32"; do
    if [ ! -e "$mesa/lib/dri/radeonsi_dri.so" ]; then
        echo "Driver Mesa não encontrado em: $mesa" >&2
        exit 1
    fi
done

for link in /run/opengl-driver /run/opengl-driver-32; do
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "Não vou substituir o caminho existente que não é link: $link" >&2
        exit 1
    fi
done

ln -sfn "$mesa64" /run/opengl-driver
ln -sfn "$mesa32" /run/opengl-driver-32
```

Para criar o arquivo e habilitar o serviço `local` do OpenRC:

```sh
doas mkdir -p /etc/local.d
doas tee /etc/local.d/opengl-drivers.start >/dev/null <<'EOF'
#!/bin/sh
set -eu

mesa64="$(readlink -f /home/saw/.cache/nix-roots/mesa64)"
mesa32="$(readlink -f /home/saw/.cache/nix-roots/mesa32)"

for mesa in "$mesa64" "$mesa32"; do
    if [ ! -e "$mesa/lib/dri/radeonsi_dri.so" ]; then
        echo "Driver Mesa não encontrado em: $mesa" >&2
        exit 1
    fi
done

for link in /run/opengl-driver /run/opengl-driver-32; do
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "Não vou substituir o caminho existente que não é link: $link" >&2
        exit 1
    fi
done

ln -sfn "$mesa64" /run/opengl-driver
ln -sfn "$mesa32" /run/opengl-driver-32
EOF

doas chmod +x /etc/local.d/opengl-drivers.start
doas rc-update add local default
doas /etc/local.d/opengl-drivers.start
ls -ld /run/opengl-driver /run/opengl-driver-32
```

O teste manual do script passou e os dois links apareceram. **Ainda não foi confirmado um reboot depois de habilitar o serviço**; após reiniciar, confira novamente com `ls -ld /run/opengl-driver /run/opengl-driver-32` e teste o Steam.

## 7. Menu do KDE

Quando o Vivaldi estava instalado, mas não aparecia no menu, atualizamos o cache do KDE com:

```sh
kbuildsycoca6 --noincremental
```

## O que foi confirmado

- `nix-channel --update` funcionou depois que a sessão do usuário incluiu o grupo `nix`.
- O canal salvo é `nixos-26.05`.
- Steam abriu, e o CS2 foi executado com bom desempenho após disponibilizarmos os drivers Mesa do Nix nos caminhos esperados.
- O teste com `steam-run` conseguiu executar um script de prova na pasta `SteamLibrary` do HD. Isso confirma acesso pelo wrapper, mas não confirma, por si só, que a interface do Steam adicionou/reconheceu a biblioteca.
- O serviço OpenRC foi habilitado e o script rodou manualmente; a recriação dos links após reinicialização ainda precisa de confirmação.
