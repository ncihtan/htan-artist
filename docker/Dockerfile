FROM python:3.9-slim

# File Author / Maintainer
MAINTAINER Adam Taylor <adam.taylor@sagebase.org>

RUN useradd --create-home --shell /bin/bash artist
WORKDIR /home/artist

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

USER artist

COPY . .

CMD ["bash"]
