SHELL := /bin/bash

APP_NAME ?= wezterm
IMAGE_REPO ?= ghcr.io/your-org/$(APP_NAME)
IMAGE_TAG ?= $(shell git rev-parse --short HEAD)
IMAGE ?= $(IMAGE_REPO):$(IMAGE_TAG)

DOCKERFILE ?= Dockerfile
CONTEXT ?= .

K8S_NAMESPACE ?= default
K8S_DIR ?= k8s
K8S_DEPLOYMENT ?= $(APP_NAME)
K8S_CONTAINER ?= $(APP_NAME)

.PHONY: help build-image push-image k8s-apply k8s-set-image rollout-status deploy k8s-delete print-vars

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target> [VAR=value]\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

print-vars: ## Print resolved build/deploy variables
	@echo "APP_NAME=$(APP_NAME)"
	@echo "IMAGE_REPO=$(IMAGE_REPO)"
	@echo "IMAGE_TAG=$(IMAGE_TAG)"
	@echo "IMAGE=$(IMAGE)"
	@echo "DOCKERFILE=$(DOCKERFILE)"
	@echo "CONTEXT=$(CONTEXT)"
	@echo "K8S_NAMESPACE=$(K8S_NAMESPACE)"
	@echo "K8S_DIR=$(K8S_DIR)"
	@echo "K8S_DEPLOYMENT=$(K8S_DEPLOYMENT)"
	@echo "K8S_CONTAINER=$(K8S_CONTAINER)"

build-image: ## Build container image (IMAGE_REPO/IMAGE_TAG)
	@test -f "$(DOCKERFILE)" || (echo "Missing $(DOCKERFILE). Set DOCKERFILE=<path>" && exit 1)
	docker build -f "$(DOCKERFILE)" -t "$(IMAGE)" "$(CONTEXT)"

push-image: ## Push container image
	docker push "$(IMAGE)"

k8s-apply: ## Apply manifests from K8S_DIR
	@test -d "$(K8S_DIR)" || (echo "Missing $(K8S_DIR). Set K8S_DIR=<path>" && exit 1)
	kubectl -n "$(K8S_NAMESPACE)" apply -f "$(K8S_DIR)"

k8s-set-image: ## Update deployment container image
	kubectl -n "$(K8S_NAMESPACE)" set image deployment/"$(K8S_DEPLOYMENT)" "$(K8S_CONTAINER)"="$(IMAGE)"

rollout-status: ## Wait for deployment rollout
	kubectl -n "$(K8S_NAMESPACE)" rollout status deployment/"$(K8S_DEPLOYMENT)"

deploy: build-image push-image k8s-apply k8s-set-image rollout-status ## Build, push, apply manifests, set image, and wait for rollout

k8s-delete: ## Delete manifests from K8S_DIR
	@test -d "$(K8S_DIR)" || (echo "Missing $(K8S_DIR). Set K8S_DIR=<path>" && exit 1)
	kubectl -n "$(K8S_NAMESPACE)" delete -f "$(K8S_DIR)"
