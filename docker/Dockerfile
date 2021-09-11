FROM debian:bullseye

# File Author / Maintainer
MAINTAINER Adam Taylor <adam.taylor@sagebase.org>

RUN apt-get update && apt-get install --yes --no-install-recommends \
    wget \
    locales \
    vim-tiny \
    git \
    cmake \
    build-essential \
    libopenslide-dev \
    python3-dev \
    python3-pip \
    libblosc1 \
    unzip

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

RUN git clone https://github.com/adamjtaylor/miniature.git && \
    git clone https://github.com/jmuhlich/auto-minerva.git && \
    git clone https://github.com/labsyspharm/minerva-author.git && \
    wget https://gist.githubusercontent.com/adamjtaylor/964e206bf1e6f302f6e512082e953193/raw/0acdea0736a027a260a0bb598f619552ff106758/index.html && \
    wget https://github.com/glencoesoftware/bioformats2raw/releases/download/v0.3.0/bioformats2raw-0.3.0.zip && \
    unzip bioformats2raw-0.3.0.zip -d bioformats2raw && \
    wget https://github.com/glencoesoftware/raw2ometiff/releases/download/v0.3.0/raw2ometiff-0.3.0.zip && \
    unzip raw2ometiff-0.3.0.zip -d raw2ometiff && \
    echo 'export PATH="$PATH:/bioformats2raw"' >> ~/.bashrc && \
    echo 'export PATH="$PATH:/raw2ometiff"' >> ~/.bashrc && \
    source ~/.bashrc
