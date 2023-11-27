FROM python:3.11-slim-bookworm
RUN apt update && \
    apt install -y locales curl unzip make jq default-mysql-client  && \
    apt upgrade -y
RUN echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ja_JP.UTF-8

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# aws cli インストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

RUN mkdir -p /opt
COPY app/requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY app /opt/app
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /opt/app
CMD ["/usr/local/bin/entrypoint.sh"]