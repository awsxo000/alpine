.DEFAULT_GOAL := ajuda
.PHONY: ajuda dependencias preparar preparar-estado sintaxe lint simular diagnostico diagnostico-modulo verificar-canal-stable-nix migrar-canal-stable-nix aplicar aplicar-modulo atualizar-canal-nix atualizar-aplicativos-nix atualizar-nix instalar

ANSIBLE_STATE_VARS = -e @../.alpine-state/vars.yml
TEMP_DOAS = scripts/executar-com-doas-temporario.sh
NIX_UPDATE = scripts/atualizar-nix.sh
STABLE_CHANNEL = scripts/canal-stable-nix.py

ajuda:        ## Lista os comandos
	@grep -E '^[a-z_-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'
dependencias: ## Prepara Python/Ansible e instala as coleções
	sh scripts/preparar-ansible.sh
preparar:     ## Alias compatível para preparar o Ansible
	$(MAKE) dependencias
preparar-estado: ## Prepara o estado externo somente quando necessário
	@if [ ! -f ../.alpine-state/vars.yml ] || [ ! -d ../.alpine-state/collections ]; then \
		echo "==> Estado Ansible ausente; executando a preparação"; \
		sh scripts/preparar-ansible.sh; \
	fi
sintaxe:         ## Verifica a sintaxe
	$(MAKE) preparar-estado
	ansible-playbook playbooks/site.yml --syntax-check $(ANSIBLE_STATE_VARS)
lint:         ## Roda o ansible-lint
	ansible-lint
simular:      ## Simulação (dry-run) mostrando diferenças
	$(MAKE) preparar-estado
	$(TEMP_DOAS) ansible-playbook playbooks/site.yml --check --diff $(ANSIBLE_STATE_VARS)
diagnostico:  ## Aplica tudo exibindo diagnósticos detalhados
	$(MAKE) preparar-estado
	$(TEMP_DOAS) ansible-playbook playbooks/site.yml -e desktop_mostrar_diagnosticos=true -vv $(ANSIBLE_STATE_VARS)
diagnostico-modulo: ## Diagnóstico somente leitura em JSON (use MODULO=audio)
	@test -n "$(MODULO)" || (echo "Uso: make diagnostico-modulo MODULO=audio" >&2; exit 2)
	@python3 scripts/diagnostico-modulo.py "$(MODULO)" --json
verificar-canal-stable-nix: ## Consulta a versão Stable oficial sem alterar o sistema
	@python3 $(STABLE_CHANNEL) verificar
migrar-canal-stable-nix: ## Migra para o Stable mais recente após confirmação externa
	@python3 $(STABLE_CHANNEL) migrar
atualizar-canal-nix: ## Atualiza os canais Nix do usuário
	$(NIX_UPDATE) canal
atualizar-aplicativos-nix: ## Atualiza todos os aplicativos do perfil Nix
	$(NIX_UPDATE) aplicativos
atualizar-nix: ## Atualiza canal e aplicativos Nix
	$(NIX_UPDATE) tudo
aplicar:      ## Prepara o estado se necessário e aplica tudo
	$(MAKE) preparar-estado
	$(TEMP_DOAS) ansible-playbook playbooks/site.yml $(ANSIBLE_STATE_VARS)
aplicar-modulo: ## Aplica um módulo (use MODULO=audio)
	@test -n "$(MODULO)" || (echo "Uso: make aplicar-modulo MODULO=audio" >&2; exit 2)
	$(MAKE) preparar-estado
	$(TEMP_DOAS) ansible-playbook playbooks/site.yml --tags "$(MODULO)" $(ANSIBLE_STATE_VARS)
instalar:     ## Prepara o Ansible e instala todo o desktop
	$(MAKE) aplicar
