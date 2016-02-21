#!/usr/bin/env bats

# testing requirements: docker, ansible

# https://github.com/tutumcloud/tutum-fedora
readonly docker_image="tutum/fedora:21"
readonly docker_container_name="ansible-eclipse-director"
readonly director_iu=org.eclipse.epp.mpc.feature.group
readonly eclipse_url="http://www.eclipse.org/downloads/download.php?file=/eclipse/downloads/drops4/R-4.5.1-201509040015/eclipse-platform-4.5.1-linux-gtk-x86_64.tar.gz&r=1"

docker_exec() {
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
  docker_exec yum -y install deltarpm
}

eclipse_setup() {
  docker_exec yum -y install tar
  docker_exec curl -s -f -L -z /var/tmp/eclipse-platform.tar.gz -o /var/tmp/eclipse-platform.tar.gz $eclipse_url
  docker_exec tar xz -f /var/tmp/eclipse-platform.tar.gz -C /usr/local --no-same-owner --no-same-permissions
  docker_exec ln -s /usr/local/eclipse/eclipse /usr/local/bin/eclipse
}

eclipse_verify_iu() {
  local _iu=$1
  docker_exec eclipse -nosplash -application org.eclipse.equinox.p2.director -uninstallIU $_iu -verifyOnly
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
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=$director_iu"
  [[ $output =~ changed.*true ]]
  eclipse_verify_iu $director_iu
}

@test "Module exec with state present" {
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=$director_iu state=present"
  [[ $output =~ changed.*true ]]
}

@test "Module exec with state absent" {
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=$director_iu state=absent"
  [[ $output =~ changed.*false ]]
}

@test "Module exec with state absent and addon already installed" {
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=$director_iu state=present"
  [[ $output =~ changed.*true ]]
  run ansible_exec_module eclipse_director "iu=$director_iu state=absent"
  [[ $output =~ changed.*true ]]
  ! eclipse_verify_iu $director_iu
}

@test "Module exec with state present twice and check idempotent" {
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=$director_iu"
  run ansible_exec_module eclipse_director "iu=$director_iu"
  [[ $output =~ changed.*false ]]
}

@test "Module exec with multiple iu's from alternate repository" {
  docker_exec yum -y install java-headless
  eclipse_setup
  run ansible_exec_module eclipse_director "iu=org.moreunit.feature.group,org.moreunit.mock.feature.group repository=http://moreunit.sourceforge.net/update-site"
  [[ $output =~ changed.*true ]]
  eclipse_verify_iu org.moreunit.feature.group
  eclipse_verify_iu org.moreunit.mock.feature.group
}

teardown() {
  docker stop $docker_container_name > /dev/null
  docker rm $docker_container_name > /dev/null
}
