export PYTHONHOME=/data/ipop/python27/files/python
export PYTHONPATH=/data/ipop/python27/extras/python:/data/ipop/python27/files/python/lib/python2.7/lib-dynload:/data/ipop/python27/files/python/lib/python2.7
export PATH=$PYTHONHOME/bin:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/data/ipop/python27/files/python/lib:/data/ipop/python27/files/python/lib/python2.7/lib-dynload
python $@
