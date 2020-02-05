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

RUN mkdir -p /ws
WORKDIR "/ws"
ENV GOPATH="/go"

# Module prepare (if go.mod/go.sum updated)
COPY go.mod /ws
COPY go.sum /ws
RUN GO111MODULE=on go mod download

# build and test
COPY . /ws

RUN make -C /ws go-fmt
RUN make -C /ws go-build

RUN make -C /ws go-test-fmt

#RUN make -C /ws go-test

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
# xApp
#
RUN mkdir -p /opt/xAppManager \
    && chmod -R 755 /opt/xAppManager

COPY --from=appmgr-build /ws/cache/go/cmd/appmgr /opt/xAppManager/appmgr

WORKDIR /opt/xAppManager

COPY appmgr-entrypoint.sh /opt/xAppManager/
ENTRYPOINT ["/opt/xAppManager/appmgr-entrypoint.sh"]
