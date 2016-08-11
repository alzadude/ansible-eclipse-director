#!/usr/bin/env bats

# dependencies of this test: bats, ansible, docker
# control machine requirements for module under test: ???

load 'bats-ansible/load'

readonly director_iu=org.eclipse.epp.mpc.feature.group
readonly eclipse_url="http://www.eclipse.org/downloads/download.php?file=/eclipse/downloads/drops4/R-4.5.2-201602121500/eclipse-platform-4.5.2-linux-gtk-x86_64.tar.gz&r=1"

setup() {
  container=$(container_startup fedora)
  container_dnf_conf $container keepcache 1
  container_dnf_conf $container metadata_timer_sync 0
  container_exec_sudo $container dnf -q -y install which
}

eclipse_setup() {
  container_exec_sudo $container dnf -q -y install tar
  container_exec_sudo $container curl -s -f -L -o /var/tmp/eclipse-platform.tar.gz $eclipse_url
  container_exec_sudo $container tar xz -f /var/tmp/eclipse-platform.tar.gz -C /usr/local --no-same-owner --no-same-permissions
  container_exec_module_sudo $container replace \
    'dest=/etc/sudoers regexp=(secure_path(?!.*/usr/local/eclipse.*).*) replace=\1:/usr/local/eclipse' > /dev/null
  container_exec_module_sudo $container copy "src=${BATS_TEST_DIRNAME}/eclipse.sh dest=/etc/profile.d/" > /dev/null
}

eclipse_verify_iu() {
  local _iu=$1
  container_exec $container eclipse -nosplash -application org.eclipse.equinox.p2.director -uninstallIU $_iu -verifyOnly
}

@test "Module exec with iu arg missing" {
  run container_exec_module_sudo $container eclipse_director
  [[ $output =~ "missing required arguments: iu" ]]
}

@test "Module exec with state arg having invalid value" {
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu state=latest"
  [[ $output =~ "value of state must be one of: present,absent, got: latest" ]]
}

@test "Module exec with state arg having default value of present" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu"
  [[ $output =~ SUCCESS.*changed.*true ]]
  eclipse_verify_iu $director_iu
}

@test "Module exec with state present" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu state=present"
  [[ $output =~ SUCCESS.*changed.*true ]]
}

@test "Module exec with state absent" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu state=absent"
  [[ $output =~ SUCCESS.*changed.*false ]]
}

@test "Module exec with state absent and addon already installed" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu state=present"
  [[ $output =~ SUCCESS.*changed.*true ]]
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu state=absent"
  [[ $output =~ SUCCESS.*changed.*true ]]
  ! eclipse_verify_iu $director_iu
}

@test "Module exec with state present twice and check idempotent" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu"
  run container_exec_module_sudo $container eclipse_director "iu=$director_iu"
  [[ $output =~ SUCCESS.*changed.*false ]]
}

@test "Module exec with multiple iu's from alternate repository" {
  container_exec_sudo $container dnf -q -y install java-headless
  eclipse_setup
  run container_exec_module_sudo $container eclipse_director "iu=org.moreunit.feature.group,org.moreunit.mock.feature.group repository=http://moreunit.sourceforge.net/update-site"
  [[ $output =~ SUCCESS.*changed.*true ]]
  eclipse_verify_iu org.moreunit.feature.group
  eclipse_verify_iu org.moreunit.mock.feature.group
}

teardown() {
  container_cleanup $container
}
