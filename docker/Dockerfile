FROM centos

RUN yum install -y wget \
		curl \
		openssl \
		git-core \
		&& yum clean all

WORKDIR /data/registry-sync-tools

COPY hack/registry_sync.sh /data/registry-sync-tools

COPY binary/docker /usr/bin/docker