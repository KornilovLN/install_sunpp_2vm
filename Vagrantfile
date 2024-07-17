# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 1.7.0"

Vagrant.configure("2") do |config|

  #-----------------------------------------------------------------------
  # Первая виртуальная машина
  #-----------------------------------------------------------------------
  config.vm.define "firstvm", autostart: true do |firstvm|  
    firstvm.vm.box = "ubuntu/bionic64"
    firstvm.vm.network "private_network", ip: "192.168.56.10"
    firstvm.vm.hostname = "firstvm"

    firstvm.vm.provider :virtualbox do |vb|
      vb.name = "firstvm"
      vb.memory = 9096
      vb.cpus = 4
    end

    # Синхронизированная папка
    firstvm.vm.synced_folder "shared_folder", "/vagrant/shared_folder"

    firstvm.vm.provision "shell", privileged: false, inline: <<-SHELL
      echo 'vagrant:vagrant' | sudo chpasswd
    SHELL

    firstvm.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y curl python3
      sudo ln -s /usr/bin/python3 /usr/bin/python
      sudo bash -c "echo '192.168.56.11 secondvm' >> /etc/hosts"
    SHELL

    # Копирование файлов из shared_folder/first_soft в /script
    firstvm.vm.provision "shell", inline: <<-SHELL
      mkdir -p /script
      cp /vagrant/shared_folder/first_soft/*.py /script/
    SHELL

    # Запуск sender.py
    firstvm.vm.provision "shell", inline: <<-SHELL
      nohup python3 /script/sender.py > sender.log 2>&1 &
    SHELL
  end

  #-----------------------------------------------------------------------
  # Вторая виртуальная машина {sdn.dc.cns.atom или registry.dc.cns.atom}
  #-----------------------------------------------------------------------
  config.vm.define "secondvm", autostart: true do |secondvm|
    secondvm.vm.box = "ubuntu/bionic64"
    secondvm.vm.network "private_network", ip: "192.168.56.11"
    secondvm.vm.hostname = "secondvm"

    secondvm.vm.provider :virtualbox do |vb|
      vb.name = "secondvm"
      vb.memory = 2048
      vb.cpus = 2
    end

    # Синхронизированная папка
    secondvm.vm.synced_folder "shared_folder", "/vagrant/shared_folder"

    secondvm.vm.provision "shell", privileged: false, inline: <<-SHELL
      echo 'vagrant:vagrant' | sudo chpasswd
    SHELL
    
    secondvm.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y curl python3
      sudo ln -s /usr/bin/python3 /usr/bin/python
      sudo bash -c "echo '192.168.56.10 firstvm' >> /etc/hosts"  
    SHELL

    # Копирование файлов из shared_folder/second_soft в /script
    secondvm.vm.provision "shell", inline: <<-SHELL
      mkdir -p /script
      cp /vagrant/shared_folder/second_soft/*.py /script/
    SHELL

    # Запуск receiver.py
    secondvm.vm.provision "shell", inline: <<-SHELL
      nohup python3 /script/receiver.py > receiver.log 2>&1 &
    SHELL
  end

end

