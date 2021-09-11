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

RUN git clone https://github.com/adamjtaylor/miniature.git
RUN git clone https://github.com/jmuhlich/auto-minerva.git
RUN git clone https://github.com/labsyspharm/minerva-author.git
