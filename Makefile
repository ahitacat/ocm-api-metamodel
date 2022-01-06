#
# Copyright (c) 2019 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Disable CGO so that we always generate static binaries:
export CGO_ENABLED=0

# Details of the version of 'antlr' to use:
antlr_version:=4.9.3
antlr_url:=https://www.antlr.org/download/antlr-$(antlr_version)-complete.jar
antlr_sum:=afcd40946d3de4d81e28d7c88d467289e0587285d27adb172aecc5494a17df36

# Version of the OpenAPI verification tool:
openapi_generator_version:=3.3.4
openapi_generator_url:=https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/$(openapi_generator_version)/openapi-generator-cli-$(openapi_generator_version).jar
openapi_generator_sum:=24cb04939110cffcdd7062d2f50c6f61159dc3e0ca3b8aecbae6ade53ad3dc8c

.PHONY: binary
binary: generate
	go build ./cmd/metamodel

.PHONY: generate
generate: antlr
	cd pkg/language && \
	java \
		-jar ../../$? \
		-package language \
		*.g4

antlr:
	wget --progress=dot:giga --output-document="$@" "$(antlr_url)"
	echo "$(antlr_sum) $@" | sha256sum --check

.PHONY: fmt
fmt:
	gofmt -s -l -w \
		./cmd \
		./pkg \
		./tests \
		$(NULL)

.PHONY: test tests
test tests:
	$(MAKE) unit_tests
	$(MAKE) go_tests
	$(MAKE) openapi_tests
	$(MAKE) docs_tests

.PHONY: unit_tests
unit_tests:
	ginkgo -r pkg

.PHONY: golang_tests
go_tests: binary
	rm -rf tests/go/generated
	./metamodel generate go \
		--model=tests/model \
		--base=github.com/openshift-online/ocm-api-metamodel/tests/go/generated \
		--output=tests/go/generated
	cd tests/go && ginkgo -r

.PHONY: openapi_tests
openapi_tests: openapi_generator
	rm -rf tests/openapi/generated
	./metamodel generate openapi --model=tests/model --output=tests/openapi/generated
	for spec in $$(find tests/openapi -name '*.json'); do \
		java -jar "$<" validate --input-spec=$${spec}; \
	done

openapi_generator:
	wget --progress=dot:giga --output-document "$@" "$(openapi_generator_url)"
	echo "$(openapi_generator_sum) $@" | sha256sum --check

.PHONY: docs_tests
docs_tests:
	rm -rf tests/docs/generated
	./metamodel generate docs --model=tests/model --output=tests/docs/generated

.PHONY: clean
clean:
	rm -rf \
		.gobin \
		antlr \
		metamodel \
		model \
		openapi_generator \
		tests/*/generated \
		$(NULL)
