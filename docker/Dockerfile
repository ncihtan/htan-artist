FROM python:3.9-slim

# File Author / Maintainer
MAINTAINER Adam Taylor <adam.taylor@sagebase.org>

RUN apt-get update && apt-get install --yes --no-install-recommends \
    wget \
    locales \
    vim-tiny \
    git \
    cmake \
    build-essential \
    libopenslide-dev

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt
