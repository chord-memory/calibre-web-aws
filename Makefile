VENV = .venv
PYTHON = $(VENV)/bin/python
PIP = $(VENV)/bin/pip

# Load .env into Make
ifneq (,$(wildcard .env))
	include .env
	export
endif

$(VENV)/bin/activate: 
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip

.PHONY: venv
venv: $(VENV)/bin/activate

.PHONY: install
install: venv
	$(PIP) install -r requirements.txt

.PHONY: kobo-migrate
kobo-migrate: install
	$(VENV)/bin/python ./scripts/kobo/migrate.py \
		--kobo-db $(KOBO_DB) \
		--instance $(INSTANCE) \
		--title $(TITLE) \
		--shelf $(SHELF) \
		$(if $(filter true,$(DRY_RUN)),--dry-run)

.PHONY: shell
shell: install
	@echo "Entering virtual environment. Exit to deactivate."
	@bash --noprofile --norc -i -c "source $(VENV)/bin/activate && exec bash"
