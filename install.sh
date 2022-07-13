#!/bin/bash
sudo apt update
sudo apt install python3-pip python3.8 unzip
python3.8 -m pip install -U pip
git clone https://github.com/domZippilli/gcsfast.git
cd gcsfast
python3.8 -m pip install -e .
cd ../
git clone https://github.com/domZippilli/gcloud-aio.git
cd gcloud-aio/storage
python3.8 -m pip install .
echo PATH=/home/$USER/.local/bin:$PATH >> ~/.bashrc && source ~/.bashrc
cd
# sudo apt install awscli
# aws configure
