# Sample Makefile: variables, pattern rules, phony targets, conditionals.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

VERSION ?= $(shell node -p "require('./package.json').version")
REGISTRY ?= ghcr.io/blaccorek
IMAGE := $(REGISTRY)/api:$(VERSION)
SRC := $(shell find samples -type f -name '*.ts' 2>/dev/null)
OBJ := $(SRC:.ts=.js)
PLATFORMS := linux/amd64 linux/arm64

ifeq ($(CI),true)
  NPM_FLAGS := --no-audit --no-fund --silent
else
  NPM_FLAGS :=
endif

export DOCKER_BUILDKIT := 1

.PHONY: help install lint test build package docker clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

install: node_modules ## Install dependencies

node_modules: package-lock.json
	npm ci $(NPM_FLAGS)
	@touch $@

lint: install ## Run linters
	npx prettier --check "samples/**/*.{ts,tsx,js,json,css,scss,yml,yaml}"
	npx tsc --noEmit || true

test: install ## Run the test suite
	npm test -- --reporter=dot

%.js: %.ts
	npx esbuild $< --bundle --platform=node --outfile=$@

build: $(OBJ) ## Transpile sources

package: build ## Build the .vsix bundle
	npx --yes @vscode/vsce package --out "dist/theme-$(VERSION).vsix"

docker: ## Build and push multi-arch images
	docker buildx build \
	  --platform "$(subst $(space),$(comma),$(PLATFORMS))" \
	  --tag "$(IMAGE)" \
	  --build-arg VERSION="$(VERSION)" \
	  --push .

clean: ## Remove build artifacts
	$(RM) -r dist $(OBJ)
	@echo "cleaned $(words $(OBJ)) generated files"

comma := ,
space := $(empty) $(empty)
