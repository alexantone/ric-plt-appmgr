#   Copyright (c) 2019 AT&T Intellectual Property.
#   Copyright (c) 2019 Nokia.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

#----------------------------------------------------------

# ARG DOCKER_REPO=nexus3.o-ran-sc.org:10004
ARG DOCKER_REPO=akrainoenea

FROM ${DOCKER_REPO}/bldr-ubuntu18-c-go:3-u18.04-nng AS appmgr-build

# ARG ARCH=amd64
ARG ARCH=arm64

RUN apt-get update -y && apt-get install -y jq

ENV PATH="/usr/local/go/bin:${PATH}"
ARG HELMVERSION=v2.12.3
ENV HELM_PKG="helm-${HELMVERSION}-linux-${ARCH}.tar.gz"

# Install helm
RUN wget -nv https://storage.googleapis.com/kubernetes-helm/${HELM_PKG} \
    && tar -zxvf ${HELM_PKG} \
    && cp linux-${ARCH}/helm /usr/local/bin/helm \
    && rm -rf ${HELM_PKG} \
    && rm -rf linux-${ARCH}

# Install kubectl
ENV KUBE_VER=v1.10.3

RUN wget -nv https://storage.googleapis.com/kubernetes-release/release/${KUBE_VER}/bin/linux/${ARCH}/kubectl \
         -O /usr/local/bin/kubectl

ENV GOPATH="/go"

# Swagger
ENV SWAGGER_VER=v0.19.0
ENV SWAGGER_PKG=swagger_linux_${ARCH}

RUN mkdir -p /go/bin
RUN cd /go/bin \
    && wget --quiet https://github.com/go-swagger/go-swagger/releases/download/${SWAGGER_VER}/${SWAGGER_PKG} \
    && mv ${SWAGGER_PKG} swagger \
    && chmod +x swagger

RUN mkdir -p /go/src/ws
WORKDIR "/go/src/ws"

# Module prepare (if go.mod/go.sum updated)
COPY go.mod /go/src/ws
COPY go.sum /go/src/ws
RUN GO111MODULE=on go mod download

# build and test
COPY . /go/src/ws

# Generate Swagger code
RUN /go/bin/swagger generate server -f api/appmgr_rest_api.yaml --name AppManager -t pkg/ --exclude-main

COPY . /go/src/ws

# Build the code
RUN GO111MODULE=on GO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /go/src/ws/cache/go/cmd/appmgr cmd/appmgr.go

# Run unit tests
RUN GO111MODULE=on GO_ENABLED=0 GOOS=linux go test -p 1 -cover ./pkg/cm/ ./pkg/helm/ ./pkg/resthooks/

RUN gofmt -l $(find cmd/ pkg/  -name '*.go' -not -name '*_test.go')

CMD ["/bin/bash"]

#----------------------------------------------------------
FROM ubuntu:18.04 as appmgr

RUN apt-get update -y \
    && apt-get install -y sudo openssl ca-certificates ca-cacert \
    && apt-get clean

#
# libraries and helm
#
COPY --from=appmgr-build /usr/local/include/ /usr/local/include/
COPY --from=appmgr-build /usr/local/lib/ /usr/local/lib/
COPY --from=appmgr-build /usr/local/bin/helm /usr/local/bin/helm
COPY --from=appmgr-build /usr/local/bin/kubectl /usr/local/bin/kubectl

RUN ldconfig

#
# xApp Manager
#
RUN mkdir -p /opt/xAppManager \
    && chmod -R 755 /opt/xAppManager

COPY --from=appmgr-build /go/src/ws/cache/go/cmd/appmgr /opt/xAppManager/appmgr

WORKDIR /opt/xAppManager

COPY appmgr-entrypoint.sh /opt/xAppManager/
ENTRYPOINT ["/opt/xAppManager/appmgr-entrypoint.sh"]
