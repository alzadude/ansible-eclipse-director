#!/usr/bin/env bats

# testing requirements: docker, ansible

# https://github.com/tutumcloud/tutum-fedora
readonly docker_image="tutum/fedora:21"
readonly docker_container_name="ansible-eclipse-director"
readonly director_iu=org.eclipse.epp.mpc.feature.group

docker_exec() {
  docker exec $docker_container_name $@
}

docker_exec_q() {
  docker exec $docker_container_name $@ > /dev/null
}

docker_exec_d() {
  docker exec -d $docker_container_name $@ > /dev/null
}

docker_exec_sh() {
  # workaround for https://github.com/sstephenson/bats/issues/89
  local IFS=' '
  docker exec $docker_container_name sh -c "$*" > /dev/null
}

ansible_exec_module() {
  local _name=$1
  local _args=$2
  ANSIBLE_LIBRARY=../ ansible localhost -i hosts -u root -m $_name ${_args:+-a "$_args"}
}

setup() {
  local _ssh_public_key=~/.ssh/id_rsa.pub
  docker run --name $docker_container_name -d -p 5555:22 -e AUTHORIZED_KEYS="$(< $_ssh_public_key)" -v $docker_container_name:/var/cache/yum/x86_64/21/ -v ${docker_container_name}-tmp:/var/tmp $docker_image
  docker_exec sed -i -e 's/keepcache=\(.*\)/keepcache=1/' /etc/yum.conf
  docker_exec_q yum -y install deltarpm
#  docker_exec_d Xvfb :1
}

setup_eclipse() {
  docker_exec_q yum -y install tar
  docker_exec curl -s -L -z /var/tmp/eclipse-platform.tar.gz -o /var/tmp/eclipse-platform.tar.gz "http://www.eclipse.org/downloads/download.php?file=/eclipse/downloads/drops4/R-4.5.1-201509040015/eclipse-platform-4.5.1-linux-gtk-x86_64.tar.gz&r=1"
  docker_exec tar xz -f /var/tmp/eclipse-platform.tar.gz -C /usr/local --no-same-owner --no-same-permissions
  docker_exec ln -s /usr/local/eclipse/eclipse /usr/local/bin/eclipse
}

@test "Module exec with iu arg missing" {
  run ansible_exec_module eclipse_director
  [[ $output =~ "missing required arguments: iu" ]]
}

@test "Module exec with state arg having invalid value" {
  run ansible_exec_module eclipse_director "iu=$director_iu state=latest"
  [[ $output =~ "value of state must be one of: present,absent, got: latest" ]]
}

@test "Module exec with state arg having default value of present" {
  docker_exec_q yum -y install java-headless
  setup_eclipse
  ansible_exec_module eclipse_director "iu=$director_iu"
  false
#  [[ $output =~ changed.*true ]]
#  docker_exec eclipse -nosplash -application org.eclipse.equinox.p2.director -uninstallIU $director_iu -verifyOnly
}

@test "Module exec with state present" {
  docker_exec yum -y install java-headless
  setup_eclipse
  run ansible_exec_module eclipse_director "iu=$director_iu state=present"
  [[ $output =~ changed.*true ]]
}

#@test "Module exec with state absent" {
#  docker_exec yum -y install firefox unzip curl
#  run ansible_exec_module eclipse_director "repository=$addon_url state=absent display=:1"
#  [[ $output =~ changed.*false ]]
#}

#@test "Module exec with state absent and addon already installed" {
#  docker_exec yum -y install firefox unzip curl
#  run ansible_exec_module eclipse_director "repository=$addon_url state=present display=:1"
#  [[ $output =~ changed.*true ]]
#  run ansible_exec_module eclipse_director "repository=$addon_url state=absent display=:1"
#  [[ $output =~ changed.*true ]]
#  docker_exec_sh test ! -e "~/.mozilla/firefox/*.default/extensions/{d10d0bf8-f5b5-c8b4-a8b2-2b9879e08c5d}"
#}

#@test "Module exec with state present twice and check idempotent" {
#  docker_exec yum -y install firefox unzip curl
#  run ansible_exec_module eclipse_director "repository=$addon_url display=:1"
#  run ansible_exec_module eclipse_director "repository=$addon_url display=:1"
#  [[ $output =~ changed.*false ]]
#}

teardown() {
  docker stop $docker_container_name > /dev/null
  docker rm $docker_container_name > /dev/null
}
