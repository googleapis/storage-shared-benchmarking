#!/bin/bash
sudo apt update
sudo apt install python3-pip python3.10 unzip
python3.10 -m pip install -U pip
git clone https://github.com/domZippilli/gcsfast.git
cd gcsfast
python3.10 -m pip install -e .
cd ../
git clone https://github.com/domZippilli/gcloud-aio.git
cd gcloud-aio/storage
python3.10 -m pip install .
echo PATH=/home/$USER/.local/bin:$PATH >> ~/.bashrc && source ~/.bashrc
cd


sudo apt update
sudo apt install -y build-essential cmake git gcc g++ cmake \
        libc-ares-dev libc-ares2 libbenchmark-dev libcurl4-openssl-dev libssl-dev \
        make npm pkg-config tar wget zlib1g-dev
sudo apt install -y clang-10 clang-tidy-10 clang-format-10 clang-tools-10
sudo update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-10 100
sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-10 100

sudo wget -q -O /usr/bin/buildifier https://github.com/bazelbuild/buildtools/releases/download/0.29.0/buildifier
sudo chmod 755 /usr/bin/buildifier

sudo curl -L -o /usr/local/bin/shfmt \
    "https://github.com/mvdan/sh/releases/download/v3.1.0/shfmt_v3.1.0_linux_amd64"
sudo chmod 755 /usr/local/bin/shfmt

sudo apt install -y python3 python3-pip
pip3 install --upgrade pip
pip3 install cmake_format==0.6.8

pip3 install black==19.3b0

sudo npm install -g cspell

pip3 install setuptools wheel
pip3 install git+https://github.com/googleapis/storage-testbench

export PATH=$PATH:$HOME/.local/bin

git -C $HOME clone https://github.com/microsoft/vcpkg

env VCPKG_ROOT="${vcpkg_dir}" $HOME/vcpkg/bootstrap-vcpkg.sh

cd $HOME/google-cloud-cpp
cmake -H. -Bcmake-out/home -DCMAKE_TOOLCHAIN_FILE=$HOME/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build cmake-out/home

git clone https://github.com/googleapis/google-cloud-cpp.git
cd google-cloud-cpp
# sudo apt install awscli
# aws configure
