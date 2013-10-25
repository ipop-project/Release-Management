export PYTHONHOME=/data/svpn/python27/files/python
export PYTHONPATH=/data/svpn/python27/extras/python:/data/svpn/python27/files/python/lib/python2.7/lib-dynload:/data/svpn/python27/files/python/lib/python2.7
export PATH=$PYTHONHOME/bin:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/svpn/python27/files/python/lib:/data/svpn/python27/files/python/lib/python2.7/lib-dynload
python vpn_controller.py $@
