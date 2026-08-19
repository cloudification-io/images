FROM ubuntu:24.04

ENV LC_ALL=C.UTF-8
ENV OS_PLACEMENT_API_VERSION=1.39

ARG OPENSTACK_RELEASE=2025.1
ARG openstack_release=stable/${OPENSTACK_RELEASE}
ARG kubectl_version=v1.31
ARG fzf_completion_version=0.48.1

COPY .bashrc /root/.bashrc
COPY scripts/ /root/scripts
COPY config/ /opt/openstack-tools

RUN echo HISTFILE="/var/bash/.bash_history" >> /etc/profile && \
    mkdir -p /var/bash
RUN apt-get update -y && apt-get install -y --no-install-recommends \
        bash-completion fzf curl mtr-tiny wget iproute2 vim-nox nano vim oping \
        pciutils iputils-ping util-linux bat dnsutils fping net-tools netcat-traditional \
        openssh-client python3-pip apt-transport-https ca-certificates jq git gpg
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/$kubectl_version/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$kubectl_version/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl ovn-common
RUN apt autoclean && apt autopurge && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/bash_completion.d && \
    wget https://raw.githubusercontent.com/junegunn/fzf/$fzf_completion_version/shell/completion.bash -O /etc/bash_completion.d/fzf.bash_completion && \
    wget https://raw.githubusercontent.com/openstack/python-novaclient/$openstack_release/tools/nova.bash_completion -O /etc/bash_completion.d/nova.bash_completion
RUN pip3 install --break-system-packages -c https://raw.githubusercontent.com/openstack/requirements/$openstack_release/upper-constraints.txt \
        python-openstackclient python-octaviaclient python-neutronclient \
        openstack-placement osc-placement networking-l2gw osprofiler \
        python-barbicanclient gnocchiclient python-cloudkittyclient \
        python-masakariclient \
        python-designateclient python-manilaclient python-heatclient && \
    openstack complete > /etc/bash_completion.d/osc.bash_completion
