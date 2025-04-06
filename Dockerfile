FROM public.ecr.aws/lambda/python:3.9

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/local/lib:/var/lang/lib:/opt/lib \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

# Install basic dependencies
RUN yum update -y && \
    yum install -y gcc gcc-c++ make git \
    mesa-libGL glib2-devel libSM libXrender libXext \
    pkgconfig cmake ninja-build wget \
    nasm yasm \
    && yum clean all

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

# Install torchtext and other common dependencies
RUN pip install torch==1.10.0 torchtext==0.11.0 torchvision==0.11.0

# Clone and build decord with the compatible FFmpeg
RUN git clone --recursive https://github.com/dmlc/decord && \
    cd decord && \
    git checkout v0.6.0 && \
    mkdir -p build && cd build && \
    cmake .. -DUSE_CUDA=OFF -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    cd ../python && \
    pip install -e .

# Copy your application files
WORKDIR ${LAMBDA_TASK_ROOT}
COPY . .

# Install the rest of the requirements
RUN pip install -r requirements.txt
RUN cd pdf_processor/detectron2 && pip install -e .

# Set the Lambda handler
CMD [ "pdf_processor/lambda_handler.lambda_handler" ]