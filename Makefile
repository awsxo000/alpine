.DEFAULT_GOAL := ajuda
.PHONY: ajuda dependencias preparar sintaxe lint simular diagnostico diagnostico-modulo aplicar instalar

ajuda:        ## Lista os comandos
	@grep -E '^[a-z_-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'
dependencias: ## Prepara Python/Ansible e instala as coleções
	sh scripts/preparar-ansible.sh
preparar:     ## Alias compatível para preparar o Ansible
	$(MAKE) dependencias
sintaxe:      ## Verifica a sintaxe
	ansible-playbook playbooks/site.yml --syntax-check
lint:         ## Roda o ansible-lint
	ansible-lint
simular:      ## Simulação (dry-run) mostrando diferenças
	ansible-playbook playbooks/site.yml --check --diff
diagnostico:  ## Aplica tudo exibindo diagnósticos detalhados
	ansible-playbook playbooks/site.yml -e desktop_mostrar_diagnosticos=true -vv
diagnostico-modulo: ## Diagnóstico somente leitura em JSON (use MODULO=audio)
	@test -n "$(MODULO)" || (echo "Uso: make diagnostico-modulo MODULO=audio" >&2; exit 2)
	@python3 scripts/diagnostico-modulo.py "$(MODULO)" --json
aplicar:      ## Aplica tudo (dependências já preparadas)
	ansible-playbook playbooks/site.yml
instalar:     ## Prepara o Ansible e instala todo o desktop
	$(MAKE) aplicar
