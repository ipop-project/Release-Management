#!/usr/bin/env bash

function Usage() {
cat <<-ENDOFMESSAGE
options:
  -m Operation mode 
    1 -- Creating instances
    2 -- Copy binaries to instances and run IPOP
    3 -- Run Simple Test
  -p Prefix | Specify lxc instance name prefix
  -i Specify instance count

Examples:
  Creating Instances with prefix
    ./gvpn_lxc -m 1 -p prefix -i 5
    Creating lxc instances with names "prefix0" "refix1" ... "prefix4"
  Copy ipop-tincan binary and controllers and configure IP for node
    ./gvpn_lxc -m 2 -p prefix -i 5 -a 172.16.1.1
    LXC instance will have ipop node with IP address 172.16.1.1, 172.16.1.2, ...
  
ENDOFMESSAGE
exit 1
}

function create_instances {
PREFIX=$1
COUNT=$2
lxc_path=/var/lib/lxc
 
CONTROLLER=gvpn_controller.py

#Check whether lxc is installed
#if not, install it
if ! dpkg -l lxc >> /dev/null 2>&1 
then 
  echo "LXC Package is not installed"
  sudo apt-get update
  sudo apt-get install -y lxc 
fi
echo "LXC is installed"


#Check whether LXC exists with give prefix
if sudo test ! -e /var/lib/lxc/${PREFIX}0
then 
  echo "Ubuntu LXC not exists. creating one"
  sudo lxc-create -t ubuntu -n ${PREFIX}0
else
  echo "Ubuntu LXC exists with given prefix $PREFIX"
  exit 1;
fi

#Install python and tap device in instance
sudo chroot /var/lib/lxc/${PREFIX}0/rootfs apt-get update
sudo chroot /var/lib/lxc/${PREFIX}0/rootfs apt-get install -y python
sudo chroot /var/lib/lxc/${PREFIX}0/rootfs mkdir /dev/net
sudo chroot /var/lib/lxc/${PREFIX}0/rootfs mknod /dev/net/tun c 10 200
sudo chroot /var/lib/lxc/${PREFIX}0/rootfs chmod 666 /dev/net/tun

for ((i=1; i<$COUNT; i++))
do
  container_path=$lxc_path/$PREFIX$i

  if sudo test -e /var/lib/lxc/$PREFIX$i
  then 
    echo "LXC instance name $PREFIX$i exists."
    exit 1;
  fi

  sudo lxc-clone -o ${PREFIX}0 -n $PREFIX$i
done
}

function copy {
PREFIX=$1
COUNT=$2
ADDR=$3
lxc_path=/var/lib/lxc
IP=(${ADDR//./ })

cat > run.sh << EOF
#!/usr/bin/env bash
cd /home/ubuntu
sudo ./ipop-tincan-x86_64 &> tincan.log &
./gvpn_controller.py -c config.json &> controller.log &
EOF

sudo chmod +x run.sh

for ((i=0; i<$COUNT; i++))
do
  container_path=$lxc_path/$PREFIX$i

  if sudo test ! -e /var/lib/lxc/$PREFIX$i
  then 
    echo "Target does not exist ($PREFIX$i)."
    exit 0;
  fi

  sudo cp ipop-tincan-x86_64 $container_path/rootfs/home/ubuntu/
  sudo cp config.json $container_path/rootfs/home/ubuntu/
  sudo cp gvpn_controller.py $container_path/rootfs/home/ubuntu/
  sudo cp svpn_controller.py $container_path/rootfs/home/ubuntu/
  sudo cp run.sh $container_path/rootfs/home/ubuntu/

  sudo sed -i "s/\"ip4\":.*/\"ip4\": \"${IP[0]}.${IP[1]}.${IP[2]}.$((${IP[3]}+$i))\",/g" $container_path/rootfs/home/ubuntu/config.json
 

  #If your lxc version is less than version 1.0 uncomments below script and comment out the below sucl lxc-attach part
  #sudo bash -c "echo lxc.network.ipv4 = 10.0.3.$(($i+2)) >> $container_path/config"
  #sudo sed 's/^lxc.network.ipv4/lxc.network.ipv4 = 10.0.3.$(($i+2))/g' $container_path/config
  """
  if sudo grep -q "^lxc.network.ipv4" $container_path/config
  then 
    sudo sed -i "s/^lxc.network.ipv4.*/lxc.network.ipv4 = 10.0.3.$(($i+2))/g" $container_path/config
  else
    sudo bash -c "echo \"lxc.network.ipv4 = 10.0.3.$(($i+2))\" >> $container_path/config"
  fi 
  sudo mkdir -p $container_path/rootfs/home/ubuntu/.ssh
  sudo bash -c "/bin/cat ~/.ssh/id_rsa.pub >> $container_path/rootfs/home/ubuntu/.ssh/authorized_keys"
  sudo lxc-start -d -n $PREFIX$i 
  sleep 1 #Wait till lxc instances boot up

  #This removes registered keys and register a new one.
  ssh-keygen -R 10.0.3.$(($i+2)) 1> /dev/null 2> /dev/null
  ssh-keyscan -H -t ecdsa-sha2-nistp256 10.0.3.$(($i+2)) 2> /dev/null 1>> $HOME/.ssh/known_hosts

  #This enables run binary which requires sudo previlege run without asking password and tty.
  sudo bash -c "echo \"ubuntu ALL = NOPASSWD: /home/ubuntu/run.sh\" >> $container_path/rootfs/etc/sudoers"
  sudo bash -c "echo \"ubuntu ALL = NOPASSWD: /home/ubuntu/ipop-tincan-x86_64\" >> $container_path/rootfs/etc/sudoers"

  ssh -l ubuntu 10.0.3.$(($i+2)) /home/ubuntu/run.sh 
  """

  #lxc-attach is not supported for all linux packages
  #If below is not supproted, I recommend to use ssh
  sudo lxc-start -d -n $PREFIX$i 
  sudo lxc-attach -n $PREFIX$i /home/ubuntu/run.sh 

done

}

TEMP=`getopt -o m:p:i:a: -- "$@"`
eval set -- "$TEMP"
while true 
do
  case "$1" in 
    -m) MODE=$2; shift 2;;
    -p) PREFIX=$2; shift 2;;
    -i) COUNT=$2; shift 2;;
    -a) ADDR=$2; shift 2;;
    --) shift; break ;;
    *) Usage; exit 1;;
  esac
done

case $MODE in 
  1) create_instances $PREFIX $COUNT; exit 1;;
  2) copy $PREFIX $COUNT $ADDR; exit 1;;
  *) echo "Unknown operation mode"; Usage; exit 1;;
esac
