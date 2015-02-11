
#!/bin/bash

BRIDGE=dkrfiki0
DOCKER_PID=`ps -ef | grep docker | grep -v grep |  awk '{print $2}'`
DOCKER_IMAGE="fiki/sshd"
IP_ADDRESSES="10.10.10.2/24"
IP_GATEWAY="10.10.10.1"

rm -f ./netconfig.env
mkdir -p /var/run/netns/

for i in `seq 1 ${#IP_ADDRESSES[@]}`; do
  let address_index=$i-1
  CONTAINER_ID=`docker run --name=fiki --hostname="Container_fiki${i}" --net="none" -i -t -d ${DOCKER_IMAGE} /usr/sbin/sshd -D`
  BASH_PID=`docker inspect --format {{.State.Pid}} ${CONTAINER_ID}`

  ln -s /proc/${BASH_PID}/ns/net /var/run/netns/${BASH_PID}

  ip link add veth${i}-1 type veth peer name veth${i}-2
  brctl addif ${BRIDGE} veth${i}-1
  ip link set veth${i}-1 up
  ip link set veth${i}-2 netns ${BASH_PID}
  ip netns exec ${BASH_PID} ip link set veth${i}-2 up
  ip netns exec ${BASH_PID} ip addr add ${IP_ADDRESSES[${address_index}]} dev veth${i}-2
  ip netns exec ${BASH_PID} ip route add default via ${IP_GATEWAY}

  hwaddr=`ip netns exec ${BASH_PID} ip link show veth${i}-2 | awk 'NR==2' | awk '{print $2}'`
  ipaddr=`echo "${IP_ADDRESSES[${address_index}]}" | awk -F/ '{print $1}'`
  netmask=`echo "${IP_ADDRESSES[${address_index}]}" | awk -F/ '{print $2}'`
  echo "veth${i}-2 ${IP_ADDRESSES[${address_index}]} ${hwaddr}"
  echo "export mac_veth${i}2=${hwaddr}" >> ./netconfig.env
  echo "export ip_veth${i}2=${ipaddr}" >> ./netconfig.env
  echo "export netmask_veth${i}2=${netmask}" >> ./netconfig.env
done



