FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=120

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip

RUN python -m venv /opt/awscli \
    && /opt/awscli/bin/python -m pip install --upgrade pip \
    && /opt/awscli/bin/python -m pip install awscli \
    && ln -s /opt/awscli/bin/aws /usr/local/bin/aws

RUN python -m pip install --retries 20 --resume-retries 20 prowler==5.30.1

WORKDIR /workspace

COPY config/ ./config/
COPY scripts/ ./scripts/

RUN chmod +x scripts/*.sh

ENTRYPOINT ["prowler"]
CMD ["--help"]
