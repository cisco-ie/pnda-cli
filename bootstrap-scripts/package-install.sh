#!/bin/bash -v

set -ex

if [ "x$REJECT_OUTBOUND" == "xYES" ]; then
PNDA_MIRROR_IP=$(echo $PNDA_MIRROR | awk -F'[/:]' '/http:\/\//{print $4}')

OS_RELEASE=$(lsb_release -sc)
OS_VERSION=$(lsb_release -sr)
OS_ID=$(lsb_release -si)
OS_SHORT=${OS_ID,,}${OS_VERSION%.*}

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[ipreject] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -F LOGGING | true
iptables -F OUTPUT | true
iptables -X LOGGING | true
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Allow access to proxies - proxy.esl.cisco.com
iptables -A LOGGING -d 173.36.224.109/32 -j ACCEPT
iptables -A LOGGING -d 173.36.224.108/32 -j ACCEPT
iptables -A LOGGING -d 64.102.255.40/32 -j ACCEPT
## Allow ssh from any host
iptables -A INPUT -i ens+ -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A LOGGING -o ens+ -p tcp -m tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT
## Allow http from any host
iptables -A INPUT -i ens+ -p tcp -m tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A LOGGING -o ens+ -p tcp -m tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## Log and reject all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[ipreject] " --log-level 7 -m state --state NEW
iptables -A LOGGING -d  $PNDA_MIRROR_IP/32 -j ACCEPT # PNDA mirror
if [ "x$CLIENT_IP" != "x" ]; then
iptables -A LOGGING -d  $CLIENT_IP/32 -j ACCEPT # PNDA client
fi
if [ "x$NTP_SERVERS" != "x" ]; then
NTP_SERVERS=$(echo "$NTP_SERVERS" | sed -e 's|[]"'\''\[ ]||g')
iptables -A LOGGING -d  $NTP_SERVERS -j ACCEPT # NTP server
fi
iptables -A LOGGING -d  ${vpcCidr} -j ACCEPT # PNDA network
iptables -A LOGGING -j REJECT --reject-with icmp-net-unreachable
iptables-save > /etc/iptables.conf
echo -e '#!/bin/sh\niptables-restore < /etc/iptables.conf' > /etc/rc.local
chmod +x /etc/rc.d/rc.local | true
fi

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

if [ "x$DISTRO" == "xubuntu" ]; then
  export DEBIAN_FRONTEND=noninteractive
  wget -O - $PNDA_MIRROR/mirror_deb/pnda.gpg.key | apt-key add -
  wget -O - $PNDA_MIRROR/mirror_hdp/hdp.gpg.key | apt-key add -

if [ "x$ADD_ONLINE_REPOS" == "xYES" ]; then
  # Give local mirror priority
  sed -i "1ideb $PNDA_MIRROR/mirror_deb/ ./" /etc/apt/sources.list

  (curl -L "https://archive.cloudera.com/cm5/ubuntu/${OS_RELEASE}/amd64/cm/archive.key" | apt-key add - ) && echo "deb [arch=amd64] https://archive.cloudera.com/cm5/ubuntu/${OS_RELEASE}/amd64/cm/ ${OS_RELEASE}-cm5.12.1 contrib" > /etc/apt/sources.list.d/cloudera-manager.list
  (curl -L "https://repo.saltstack.com/apt/ubuntu/${OS_VERSION}/amd64/archive/2015.8.11/SALTSTACK-GPG-KEY.pub" | apt-key add - ) && echo "deb [arch=amd64] https://repo.saltstack.com/apt/ubuntu/${OS_VERSION}/amd64/archive/2015.8.11/ ${OS_RELEASE} main" > /etc/apt/sources.list.d/saltstack.list
  (curl -L "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" | apt-key add - ) && echo "deb [arch=amd64] https://deb.nodesource.com/node_6.x ${OS_RELEASE} main" > /etc/apt/sources.list.d/nodesource.list
else
  mv /etc/apt/sources.list /etc/apt/sources.list.backup
  echo -e "deb $PNDA_MIRROR/mirror_deb/ ./" > /etc/apt/sources.list
fi

apt-get update

elif [ "x$DISTRO" == "xrhel" -o "x$DISTRO" == "xcentos" ]; then

if [ "x$ADD_ONLINE_REPOS" == "xYES" ]; then
  RPM_EXTRAS=rhui-REGION-rhel-server-extras
  RPM_OPTIONAL=rhui-REGION-rhel-server-optional
  yum-config-manager --enable $RPM_EXTRAS $RPM_OPTIONAL
  yum install -y yum-plugin-priorities yum-utils
  PNDA_REPO=${PNDA_MIRROR/http\:\/\//}
  PNDA_REPO=${PNDA_REPO/\//_mirror_rpm}
  yum-config-manager --add-repo $PNDA_MIRROR/mirror_rpm
  yum-config-manager --setopt="$PNDA_REPO.priority=1" --enable $PNDA_REPO
else
  mkdir -p /etc/yum.repos.d.backup/
  mv /etc/yum.repos.d/* /etc/yum.repos.d.backup/
  yum-config-manager --add-repo $PNDA_MIRROR/mirror_rpm
fi
  if [ "x$DISTRO" == "xrhel" ]; then
    rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-redhat-release
  fi
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-mysql
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-cloudera
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-EPEL-7
  rpm --import $PNDA_MIRROR/mirror_rpm/SALTSTACK-GPG-KEY.pub
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-CentOS-7
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-Jenkins
fi

PIP_INDEX_URL="$PNDA_MIRROR/mirror_python/simple"
TRUSTED_HOST=$(echo $PIP_INDEX_URL | awk -F'[/:]' '/http:\/\//{print $4}')
cat << EOF > /etc/pip.conf
[global]
index-url=$PIP_INDEX_URL
trusted-host=$TRUSTED_HOST
EOF
cat << EOF > /root/.pydistutils.cfg
[easy_install]
index_url=$PIP_INDEX_URL
EOF

if [ "x$ADD_ONLINE_REPOS" == "xYES" ]; then
cat << EOF >> /etc/pip.conf
extra-index-url=https://pypi.python.org/simple/
EOF
cat << EOF >> /root/.pydistutils.cfg
find_links=https://pypi.python.org/simple/
EOF
fi

