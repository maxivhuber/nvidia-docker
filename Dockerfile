FROM docker.io/huggingface/accelerate-gpu

ARG JUPYTER_TOKEN
ARG JUPYTER_PORT
ENV JUPYTER_TOKEN=${JUPYTER_TOKEN}
ENV JUPYTER_PORT=${JUPYTER_PORT}

WORKDIR /workspace
COPY requirements.txt . 

SHELL ["/bin/bash", "-c"]
RUN source activate accelerate && \
    python3 -m pip install --no-cache-dir -r requirements.txt

ENTRYPOINT conda run --no-capture-output -n accelerate jupyter lab --ip='*' --port=${JUPYTER_PORT} --no-browser --allow-root --LabApp.token=${JUPYTER_TOKEN}