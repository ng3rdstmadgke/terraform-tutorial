FROM public.ecr.aws/lambda/python:3.11

ARG host_uid
ARG host_gid

ENV PATH $PATH:/usr/sbin

RUN yum update -y && \
    yum install -y locales gcc unzip jq curl wget shadow-utils sudo

# set timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN pip install --upgrade pip

RUN groupadd -g 13567 sysadmin && echo "%sysadmin ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sysadmin

RUN groupadd -g $host_gid app && \
    useradd -u $host_uid -o -m -g $host_gid -s /bin/bash app && \
    usermod -aG sysadmin app

ENTRYPOINT [ ]
CMD [ ]