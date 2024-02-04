.PHONY: clone fetch merge pull up build

all: up

clone:
	git clone https://github.com/davidamacey/ollama-webui.git .

fetch:
	git -C ../ollama-webui fetch upstream

merge:
	git -C ../ollama-webui checkout main && git merge upstream/main

pull:
	git -C ../ollama-webui pull myfork main

up: pull
	docker compose -f docker-compose-vllm.yaml up -d --build

build:
	docker-compose build