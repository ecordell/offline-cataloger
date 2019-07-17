.PHONY: build

REPO = github.com/kevinrizza/offline-cataloger
BUILD_PATH = $(REPO)/cmd/offline-cataloger
PKG_PATH = $(REPO)/pkg
OPENAPI_PATH = ./pkg/openapi

# Mocks
MOCKS_PATH = ./pkg/mocks
BUILDER_MOCKS_PKG = builder_mocks

ifeq ($(GOBIN),)
mockgen = $(GOPATH)/bin/mockgen
else
mockgen = $(GOBIN)/mockgen
endif

all: build

build:
	# build binary
	./build/build.sh

install:
	go install $(BUILD_PATH)

unit: generate-mocks unit-test

unit-test:
	go test -v $(PKG_PATH)/...

generate-mocks:
	# Build mockgen from the same version used by gomock. This ensures that 
	# gomock and mockgen are never out of sync.
	go install ./vendor/github.com/golang/mock/mockgen
	
	@echo making sure directory for mocks exists
	mkdir -p $(MOCKS_PATH)

	# $(mockgen) -destination=<Path/file where the mock is generated> -package=<The package that the generated mock files will belong to> -mock_names=<Original Interface name>=<Name of Generated mocked Interface> <Go package path of the original interface> <comma seperated list of the interface you want to mock>

	# builder package
	$(mockgen) -destination=$(MOCKS_PATH)/$(BUILDER_MOCKS_PKG)/mock_downloader.go -package=$(BUILDER_MOCKS_PKG) -mock_names=Downloader=Downloader $(PKG_PATH)/downloader Downloader
	$(mockgen) -destination=$(MOCKS_PATH)/$(BUILDER_MOCKS_PKG)/mock_imagebuilder.go -package=$(BUILDER_MOCKS_PKG) -mock_names=ImageBuilder=ImageBuilder $(PKG_PATH)/builder ImageBuilder
	$(mockgen) -destination=$(MOCKS_PATH)/$(BUILDER_MOCKS_PKG)/mock_manifestdecoder.go -package=$(BUILDER_MOCKS_PKG) -mock_names=ManifestDecoder=ManifestDecoder $(PKG_PATH)/appregistry ManifestDecoder
	$(mockgen) -destination=$(MOCKS_PATH)/$(BUILDER_MOCKS_PKG)/mock_appregistry.go -package=$(BUILDER_MOCKS_PKG) -mock_names=ClientFactory=AppRegistryClientFactory,Client=AppRegistryClient $(PKG_PATH)/apprclient ClientFactory,Client

$(OPENAPI_GEN):
	@command -v openapi-generator || echo "openapi-generator not found. Install on macOS: brew install openapi-generator"

generate-openapi: $(OPENAPI_GEN)
generate-openapi: export GO_POST_PROCESS_FILE="gofmt -w"
generate-openapi: appr.spec.yaml
	@rm -rf $(OPENAPI_PATH)
	@openapi-generator generate -i appr.spec.yaml -g go -o $(OPENAPI_PATH)
	@rm -f $(OPENAPI_PATH)/go.mod
	@rm -f $(OPENAPI_PATH)/go.sum
	@go mod vendor
	@go mod tidy
	@echo "Fixing bad option names... (https://github.com/OpenAPITools/openapi-generator/pull/3206)"
	@sed -i "s/PullPackageOpts/PackagePullPackageOpts/gi" $(OPENAPI_PATH)/api_package.go
	@sed -i "s/PullPackageJsonOpts/PackagePullPackageJsonOpts/gi" $(OPENAPI_PATH)/api_package.go
	@sed -i "s/PullPackageOpts/BlobPullPackageOpts/gi" $(OPENAPI_PATH)/api_blobs.go
	@sed -i "s/PullPackageJsonOpts/BlobPullPackageJsonOpts/gi" $(OPENAPI_PATH)/api_blobs.go
	@echo Fixing missing imports...
	@goimports -w $(OPENAPI_PATH)

clean-mocks:
	@echo cleaning mock folder
	rm -rf $(MOCKS_PATH)

clean: clean-mocks
