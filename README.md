ansible-eclipse-director
========================

This Ansible role provides an `eclipse_director` module that wraps the Eclipse director application, for installing or uninstalling Eclipse feature groups.

Requirements
------------

  - eclipse
  - readlink
  - which
  - sed

Currently the `eclipse_director` module has only been tested against Fedora (23) hosts, but in theory should work for all Linux variants.

Arguments
---------

  - iu: the 'installable unit' (i.e. the feature group id) that needs to be installed or uninstalled (required)
  - repository: url of the update site that hosts the feature group (optional)
  - state: one of `present`, `absent` (optional, defaults to `present`)

Notes:

  - The 'release' update site for the installed version of Eclipse will always be included, regardless of whether the repository argument is provided or not.
  - The 'release' update site url is typically of the form `http://download.eclipse.org/releases/<release-name>`, where release name is one of kepler, luna, mars etc, depending on the version installed.

Dependencies
------------

This role is just a container for the `eclipse_director` module, and as such it has no role dependencies.

Installation
------------

Install from Ansible Galaxy by executing the following command:

```
ansible-galaxy install alzadude.eclipse-director
```

Please note that the role `alzadude.eclipse-director` will need to be added to playbooks to make use of the `eclipse_director` module.

Example Playbook
----------------

Save the following configuration into files with the specified names:

**playbook.yml:**

```
- hosts: linux-workstation
  sudo: no

  roles:
    - alzadude.eclipse-director

  tasks:
    - name: Install Atlassian Connector for Eclipse
      eclipse_director:
        iu: com.atlassian.connector.eclipse.feature.group
        url: http://update.atlassian.com/atlassian-eclipse-plugin/rest/e3.7
        state: present
```
**hosts:**

```
# Dummy inventory for ansible
linux-workstation ansible_host=localhost ansible_connection=local
```
Then run the playbook with the following command:
```
ansible-playbook -i hosts playbook.yml
```

License
-------

BSD

