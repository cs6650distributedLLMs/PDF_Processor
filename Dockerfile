FROM public.ecr.aws/lambda/python:3.9

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/local/lib:/var/lang/lib:/opt/lib \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig \
    PATH=/usr/local/bin:$PATH

# Install system dependencies (using yum since this is Amazon Linux)
RUN yum update -y && \
    yum install -y gcc gcc-c++ make git \
    mesa-libGL glib2-devel libSM libXrender libXext \
    pkgconfig wget \
    nasm tar gzip bzip2 \
    && yum clean all

# Install newer CMake version
RUN wget https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-aarch64.tar.gz && \
    tar -xzf cmake-3.20.0-linux-aarch64.tar.gz && \
    cp -r cmake-3.20.0-linux-aarch64/bin/* /usr/local/bin/ && \
    cp -r cmake-3.20.0-linux-aarch64/share/* /usr/local/share/ && \
    rm -rf cmake-3.20.0-linux-aarch64 cmake-3.20.0-linux-aarch64.tar.gz && \
    cmake --version

# Download a real ARM SVE header from the ARM open source repository
RUN mkdir -p /usr/local/include && \
    wget -O /usr/local/include/arm_sve.h "https://github.com/gcc-mirror/gcc/blob/master/gcc/config/aarch64/arm_sve.h"

# Install a specific version of FFmpeg that's compatible with decord
WORKDIR /tmp
RUN wget -O ffmpeg-4.2.2.tar.bz2 https://ffmpeg.org/releases/ffmpeg-4.2.2.tar.bz2 && \
    tar xjf ffmpeg-4.2.2.tar.bz2 && \
    cd ffmpeg-4.2.2 && \
    ./configure --prefix=/usr/local --enable-shared --disable-static --disable-doc && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf ffmpeg-4.2.2 ffmpeg-4.2.2.tar.bz2

# Install pip and dependencies
RUN pip install --upgrade pip

# Install torch and other dependencies
RUN pip install torch==1.10.0 torchtext==0.11.0 torchvision==0.11.1

# Clone and build decord with the compatible FFmpeg
RUN git clone --recursive https://github.com/dmlc/decord && \
    cd decord && \
    git checkout v0.6.0 && \
    mkdir -p build && cd build && \
    /usr/local/bin/cmake .. -DUSE_CUDA=OFF -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    cd ../python && \
    pip install -e .

COPY . /var/task/
RUN echo "Listing /var/task after COPY:" && ls -R /var/task/

# Copy function code
COPY . ${LAMBDA_TASK_ROOT}/

# Define environment vars for simsimd build to disable SVE
ENV SIMSIMD_TARGET_SVE=0 \
    SIMSIMD_TARGET_SVE_F16=0 \
    SIMSIMD_TARGET_SVE_BF16=0 \
    SIMSIMD_TARGET_SVE2=0

# Try to install dependencies with modified approach
RUN pip install -r ${LAMBDA_TASK_ROOT}/requirements.txt || \
    (echo "Error installing all requirements, trying with simsimd excluded..." && \
     grep -v "simsimd" ${LAMBDA_TASK_ROOT}/requirements.txt > ${LAMBDA_TASK_ROOT}/filtered-requirements.txt && \
     pip install -r ${LAMBDA_TASK_ROOT}/filtered-requirements.txt && \
     echo "Attempting simsimd installation separately..." && \
     CFLAGS="-DSIMSIMD_TARGET_SVE=0 -DSIMSIMD_TARGET_SVE_F16=0 -DSIMSIMD_TARGET_SVE_BF16=0 -DSIMSIMD_TARGET_SVE2=0" pip install simsimd || \
     echo "WARNING: simsimd package was not installed")

# Install detectron2
RUN if [ -d "${LAMBDA_TASK_ROOT}/pdf_processor/detectron2" ]; then \
    cd ${LAMBDA_TASK_ROOT}/pdf_processor/detectron2 && pip install -e .; \
    fi

# Set the Lambda handler
CMD [ "lambda_handler.lambda_handler" ]