FROM nvcr.io/nvidia/pytorch:23.07-py3

ARG JUPYTER_TOKEN
ENV JUPYTER_TOKEN=${JUPYTER_TOKEN}
WORKDIR /workspace

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    & pip install --no-cache-dir -r requirements.txt

ENTRYPOINT jupyter lab --ip=0.0.0.0 --no-browser --allow-root --LabApp.token=${JUPYTER_TOKEN} 