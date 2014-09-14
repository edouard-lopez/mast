sudo ntpdate ntp.metas.ch
sudo apt-get install make
branch=dev; wget --output-document="mast.tar.gz" https://github.com/edouard-lopez/mast/archive/$branch.tar.gz && tar xvzf mast.tar.gz && cd mast-$branch
sudo make install
# test ssh
sudo ssh -i /home/mast/.ssh/id_rsa.mast.coaxis.pub coaxis@MAST-Box
sudo make add-host NAME=test REMOTE_HOST=MAST-Box
sudo make add-channel NAME=test PRINTER=imp DESC="printer @ Alban"
