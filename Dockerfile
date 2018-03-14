FROM debian:stretch

RUN apt-get update && apt-get install -y ca-certificates git curl jq unzip
RUN curl https://releases.hashicorp.com/terraform/0.11.3/terraform_0.11.3_linux_amd64.zip -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip && rm /tmp/terraform.zip && mv terraform /usr/bin/ && chmod +x /usr/bin/terraform

COPY run.sh /run.sh

ENTRYPOINT ["/run.sh"]
