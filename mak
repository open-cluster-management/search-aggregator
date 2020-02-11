BINDIR              ?= output

DOCKER_USER         ?=$(ARTIFACTORY_USER)
DOCKER_PASS         ?=$(ARTIFACTORY_TOKEN)
DOCKER_REGISTRY     ?= hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com
DOCKER_NAMESPACE    ?= ibmcom
DOCKER_BUILD_TAG    ?= $(RELEASE_TAG)
WORKING_CHANGES      = $(shell git status --porcelain)
BUILD_DATE           = $(shell date +%m/%d@%H:%M:%S)
GIT_REMOTE_URL       = $(shell git config --get remote.origin.url)
GIT_COMMIT           = $(shell git rev-parse --short HEAD)
VCS_REF              = $(if $(WORKING_CHANGES),$(GIT_COMMIT)-$(BUILD_DATE),$(GIT_COMMIT))

# Arch labels
ARCH ?= $(shell uname -m)
ifeq ($(ARCH), x86_64)
	IMAGE_NAME_ARCH = $(IMAGE_NAME)-amd64
else
	IMAGE_NAME_ARCH = $(IMAGE_NAME)-$(ARCH)
	DOCKER_FILE     = Dockerfile.$(ARCH)
endif

 GITHUB_USER := $(shell echo $(GITHUB_USER) | sed 's/@/%40/g')

 .PHONY: default
default:: init;

 .PHONY: init
init::
	@mkdir -p variables
ifndef GITHUB_USER
	$(info GITHUB_USER not defined)
	exit -1
endif
	$(info Using GITHUB_USER=$(GITHUB_USER))
ifndef GITHUB_TOKEN
	$(info GITHUB_TOKEN not defined)
	exit -1
endif

 -include $(shell curl -fso .build-harness -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3.raw" "https://raw.github.ibm.com/ICP-DevOps/build-harness/master/templates/Makefile.build-harness"; echo .build-harness)

# only push to integration on a merge that is not the development branch
ifneq ($(TRAVIS_EVENT_TYPE), pull_request) 
ifneq ($(TRAVIS_BRANCH), development)
	DOCKER_REGISTRY = hyc-cloud-private-integration-docker-local.artifactory.swg-devops.com
	RELEASE_TAG = $(SEMVERSION)
endif
else
	DOCKER_REGISTRY = hyc-cloud-private-scratch-docker-local.artifactory.swg-devops.com
	RELEASE_TAG = $(GIT_COMMIT)
endif

DOCKER_BUILD_TAG       = $(RELEASE_TAG)

# Variables for Red Hat required labels
IMAGE_NAME             = search-aggregator
IMAGE_DISPLAY_NAME     = Multicloud Manager Search Aggregator
IMAGE_DESCRIPTION      = The search-aggregator is a Multicloud Manager component that sits in the hub cluster. It process the data sent by the collectors.
IMAGE_MAINTAINER       = jpadilla@us.ibm.com
IMAGE_VENDOR           = IBM
IMAGE_SUMMARY          = $(IMAGE_DESCRIPTION)
IMAGE_OPENSHIFT_TAGS   = multicloud-manager
IMAGE_VERSION         ?= $(RELEASE_TAG)
IMAGE_RELEASE         ?= $(VCS_REF)

 DOCKER_BUILD_OPTS = --build-arg "VCS_REF=$(VCS_REF)" \
	--build-arg "VCS_URL=$(GIT_REMOTE_URL)" \
	--build-arg "IMAGE_NAME=$(IMAGE_NAME)" \
	--build-arg "IMAGE_DISPLAY_NAME=$(IMAGE_DISPLAY_NAME)" \
	--build-arg "IMAGE_MAINTAINER=$(IMAGE_MAINTAINER)" \
	--build-arg "IMAGE_VENDOR=$(IMAGE_VENDOR)" \
	--build-arg "IMAGE_VERSION=$(IMAGE_VERSION)" \
	--build-arg "IMAGE_RELEASE=$(IMAGE_RELEASE)" \
	--build-arg "IMAGE_SUMMARY=$(IMAGE_SUMMARY)" \
	--build-arg "IMAGE_OPENSHIFT_TAGS=$(IMAGE_OPENSHIFT_TAGS)" \
	--build-arg "IMAGE_NAME_ARCH=$(IMAGE_NAME_ARCH)" \
	--build-arg "IMAGE_DESCRIPTION=$(IMAGE_DESCRIPTION)"

.PHONY: print_vars
print_vars:
	@echo "SEMVERSION = $(SEMVERSION)"
	@echo "IMAGE_VERSION = $(IMAGE_VERSION)"
	@echo "RELEASE_TAG = $(RELEASE_TAG)"
	@echo "DOCKER_REGISTRY = $(DOCKER_REGISTRY)"

.PHONY: deps
deps:
	go get -u github.com/golangci/golangci-lint/cmd/golangci-lint
	go get -u github.com/golang/dep/cmd/dep
	dep ensure -v

.PHONY: search-aggregator
search-aggregator:
	CGO_ENABLED=0 go build -a -v -i -installsuffix cgo -ldflags '-s -w' -o $(BINDIR)/search-aggregator ./

.PHONY: build
build: search-aggregator

.PHONY: build-linux
build-linux:
	make search-aggregator GOOS=linux

.PHONY: release
release:
	make docker:login
	make docker:tag-arch
	make docker:push-arch
ifeq ($(ARCH), x86_64)
	make docker:tag-arch DOCKER_ARCH_URI=$(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(IMAGE_NAME_ARCH):$(DOCKER_BUILD_TAG)-rhel
	make docker:push-arch DOCKER_ARCH_URI=$(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(IMAGE_NAME_ARCH):$(DOCKER_BUILD_TAG)-rhel
endif

.PHONY: lint
lint:
	golangci-lint run

.PHONY: test
test:
	go test ./... -v -coverprofile cover.out

.PHONY: coverage
coverage:
	go tool cover -html=cover.out -o=cover.html

.PHONY: copyright-check
copyright-check:
	./build-tools/copyright-check.sh

.PHONY: clean
clean::
	go clean
	rm -f cover*
	rm -rf ./$(BINDIR)
	rm -rf ./.vendor-new
	rm -rf ./vendor
