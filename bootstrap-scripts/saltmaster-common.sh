#!/bin/bash -v

# This script runs on the saltmaster instance as defined in cloud-formation/<flavor>/config.json

# The pnda_env-<cluster_name>.sh script generated by the CLI should
# be run prior to running this script to define various environment
# variables
set -ex

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

# Install a saltmaster, plus saltmaster config
if [ "x$DISTRO" == "xubuntu" ]; then
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install unzip salt-master=2015.8.11+ds-1 git
HDP_OS=ubuntu14
fi

if [ "x$DISTRO" == "xrhel"  -o "x$DISTRO" == "xcentos" ]; then
yum -y install unzip salt-master-2015.8.11-1.el7 git
#Enable init mode , RHEL not enabled salt-minion by default
systemctl enable salt-master.service
HDP_OS=centos7
#enable boot time startup
systemctl enable salt-master.service
fi

cat << EOF > /etc/salt/master
## specific PNDA saltmaster config
auto_accept: True      # auto accept minion key on new minion provisioning

fileserver_backend:
  - roots
  - minion

file_roots:
  base:
    - /srv/salt/platform-salt/salt

pillar_roots:
  base:
    - /srv/salt/platform-salt/pillar

# Do not merge top.sls files across multiple environments
top_file_merging_strategy: same

# To autoload new created modules, states add and remove salt keys,
# update bastion /etc/hosts file automatically ... add the following reactor configuration
reactor:
  - 'minion_start':
    - salt://reactor/sync_all.sls
  - 'salt/cloud/*/created':
    - salt://reactor/create_bastion_host_entry.sls
  - 'salt/cloud/*/destroying':
    - salt://reactor/delete_bastion_host_entry.sls
  - 'fqdn/updated/jupyter':
    - salt://reactor/fqdn_update.sls
## end of specific PNDA saltmaster config
file_recv: True

failhard: True
EOF

# Set up platform-salt that contains the scripts the saltmaster runs to install software
mkdir -p /srv/salt
cd /srv/salt
rm -rf platform-salt

if [ "x$PLATFORM_GIT_REPO_URI" != "x" ]; then
  # Set up ssh access to the platform-salt git repo on the package server,
  # if secure access is required this key will be used automatically.
  # This mode is not normally used now the public github is available
  chmod 400 /tmp/git.pem || true

  echo "Host $PLATFORM_GIT_REPO_HOST" >> /root/.ssh/config
  echo "  IdentityFile /tmp/git.pem" >> /root/.ssh/config
  echo "  StrictHostKeyChecking no" >> /root/.ssh/config

  git clone -q --branch $PLATFORM_GIT_BRANCH $PLATFORM_GIT_REPO_URI
elif [ "x$PLATFORM_URI" != "x" ] ; then
  mkdir -p /srv/salt/platform-salt && cd /srv/salt/platform-salt && \
  wget -q -O - $PLATFORM_URI | tar -zvxf - --strip=1 && ls -al && \
  cd -
elif [ "x$PLATFORM_SALT_LOCAL" != "x" ]; then
  tar zxf /tmp/$PLATFORM_SALT_TARBALL -C /srv/salt
else
  exit 2
fi

if [ "x$SECURITY_CERTS_TARBALL" != "x" ]; then
  SECURITY_CERTS_TARBALL_HASH=`md5sum /tmp/$SECURITY_CERTS_TARBALL | awk '{ print $1 }'`
  if [ ! -e /srv/security-certs/.${SECURITY_CERTS_TARBALL_HASH} ]; then
    if [ -d /srv/security-certs ]; then rm -rf /srv/security-certs; fi
    mkdir /srv/security-certs
    tar zxf /tmp/$SECURITY_CERTS_TARBALL --strip-components=1 -C /srv/security-certs 
    touch /srv/security-certs/.${SECURITY_CERTS_TARBALL_HASH}
    # Generate pillar files to store the security material
    cert_file="/srv/salt/platform-salt/pillar/certs.sls"
    if [ -e cert_file ]; then rm cert_file; fi
    for i in `find /srv/security-certs/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;`; do
      for j in `find /srv/security-certs/$i -maxdepth 1 -mindepth 1 -type f -name '*.pem'`; do
        echo -e "$i:\n  cert: |" >> $cert_file
        sed  's/^/    /' $j >> $cert_file
        break
      done;
      for j in `find /srv/security-certs/$i -maxdepth 1 -mindepth 1 -type f -name '*.key'`; do
        out_dir="/srv/salt/platform-salt/pillar/roles/$i"
        mkdir -p $out_dir
        out_file="$out_dir/$i-key.sls"
        echo "Generating $out_file"
        echo -e "$i:\n  key: |" > $out_file
        sed  's/^/    /' $j >> $out_file
        break;
      done;
    done;
    #salt '*' saltutil.refresh_pillar
  fi
fi

# Push pillar config into platform-salt for environment specific config
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
os_user: $OS_USER
keystone.user: ''
keystone.password: ''
keystone.tenant: ''
keystone.auth_url: ''
keystone.region_name: ''
aws.apps_region: '$PNDA_APPS_REGION'
aws.apps_key: '$PNDA_APPS_ACCESS_KEY_ID'
aws.apps_secret: '$PNDA_APPS_SECRET_ACCESS_KEY'
pnda.apps_container: '$PNDA_APPS_CONTAINER'
pnda.apps_folder: '$PNDA_APPS_FOLDER'
aws.archive_region: '$PNDA_ARCHIVE_REGION'
aws.archive_key: '$PNDA_ARCHIVE_ACCESS_KEY_ID'
aws.archive_secret: '$PNDA_ARCHIVE_SECRET_ACCESS_KEY'
pnda.archive_container: '$PNDA_ARCHIVE_CONTAINER'
pnda.archive_type: 's3a'
pnda.archive_service: ''

pnda_mirror:
  base_url: '$PNDA_MIRROR'
  misc_packages_path: /mirror_misc/
  app_packages_path: /mirror_apps/

cloudera:
  parcel_repo: '$PNDA_MIRROR/mirror_cloudera'

anaconda:
  parcel_version: "4.0.0"
  parcel_repo: '$PNDA_MIRROR/mirror_anaconda'

pip:
  index_url: '$PNDA_MIRROR/mirror_python/simple'

packages_server:
  base_uri: '$PNDA_MIRROR'

hdp:
  hdp_core_stack_repo: '$PNDA_MIRROR/mirror_hdp/HDP/$HDP_OS/2.6.4.0-91/'
  hdp_utils_stack_repo: '$PNDA_MIRROR/mirror_hdp/HDP-UTILS-1.1.0.22/repos/$HDP_OS/'

mine_functions:
  network.ip_addrs: [$PNDA_INTERNAL_NETWORK]
  grains.items: []

security:
  security: $SECURITY_MODE
EOF

if [ "x$NTP_SERVERS" != "x" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
ntp:
  servers:
    "$NTP_SERVERS"
EOF
fi

if [ "$PR_FS_TYPE" == "swift" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: 'swift'
EOF
elif [ "$PR_FS_TYPE" == "s3" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: 's3'
EOF
elif [ "$PR_FS_TYPE" == "sshfs" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: "sshfs"
  fs_location_path: "$PR_FS_LOCATION_PATH"
  sshfs_user: "$PR_SSHFS_USER"
  sshfs_host: "$PR_SSHFS_HOST"
  sshfs_path: "$PR_SSHFS_PATH"
  sshfs_key: "$PR_SSHFS_KEY"
EOF
else
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
package_repository:
  fs_type: "$PR_FS_TYPE"
  fs_location_path: "$PR_FS_LOCATION_PATH"
EOF
fi

if [ "x$EXPERIMENTAL_FEATURES" == "xYES" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
features:
  - EXPERIMENTAL
EOF
fi

if [ "$COMPACTION" == "YES" ] ; then
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
dataset_compaction:
  compaction: $COMPACTION
  pattern: '$PATTERN'
EOF
else
cat << EOF >> /srv/salt/platform-salt/pillar/env_parameters.sls
dataset_compaction:
  compaction: NO
  pattern: '$PATTERN'
EOF
fi
