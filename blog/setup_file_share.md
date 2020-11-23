# Setup Samba file share

Follow the steps below to setup the Samba file share on the Greengrass EC2 instance.
1. Using the `GreengrassPublicIP` CloudFormation output you recorded earlier, [login to the Linux server via SSH](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html). Use the keypair that you created earlier for authentication.
1. Install samba:
    ```bash
    sudo yum -y install samba smbfs
    sudo groupadd sambashare
    sudo mkdir /samba/
    sudo chown :sambashare /samba/
    sudo mkdir /samba/iot
    sudo usermod -a -G sambashare ggc_user
    ```
1. Create iot user and set share permissions:
    ```bash
    sudo adduser --home-dir /samba/iot --no-create-home --groups sambashare iot
    sudo chown :sambashare /samba/iot/
    sudo chmod 2775 /samba/iot/
    (echo iotaccess; echo iotaccess) | sudo smbpasswd -a iot -s
    sudo smbpasswd -e iot
    ```
1. Stop the samba service and edit the configuration file:
    ```bash
    # Stop the sambda service
    sudo systemctl stop smb.service

    # Update /etc/samba/smb.conf
    cd ~
    cat << EoF > smb.conf
    [global]
            server string = samba_server
            server role = standalone server
            interfaces = lo eth0
            bind interfaces only = yes
            disable netbios = yes
            smb ports = 445
            log file = /var/log/samba/smb.log
            max log size = 10000
    [iotshare]
            path = /samba/iot
            browseable = yes
            read only = no
            valid users = iot ggc_user @ggc_group @sambashare @wheel
    
    EoF

    sudo mv smb.conf /etc/samba/smb.conf
    ```
1. Modify ownership and permissions for smb.conf and share files/directories:
    ```bash
    sudo chown root:root /etc/samba/smb.conf
    sudo chmod 644 /etc/samba/smb.conf
    sudo chown ggc_user:ggc_group -R /samba
    sudo chmod 775 -R /greengrass 
    sudo chmod 777 -R /samba
    ```
1. Restart the samba service
    ```bash
    sudo systemctl start smb.service
    systemctl status smb.service
    ```