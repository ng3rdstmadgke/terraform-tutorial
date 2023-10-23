FROM python:3.10-slim-bookworm
RUN apt update && \
    apt install -y locales && \
    apt upgrade -y
RUN echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ja_JP.UTF-8

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN mkdir -p /opt
COPY app/requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY app /opt/app
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /opt/app
CMD ["/usr/local/bin/entrypoint.sh"]
