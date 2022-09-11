#!/bin/bash
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
yum install -y epel-release
yum install -y docker
groupadd admin
groupadd docker
useradd testuser01
useradd testuser02
echo "Test123" | passwd --stdin testuser01
echo "Test123" | passwd --stdin testuser02
gpasswd -a testuser01 admin
gpasswd -a testuser01 docker
sed -i '/^account\s*required\s*pam_nologin\.so/a account    required     pam_exec.so   /usr/local/bin/logon.sh' /etc/pam.d/sshd
sed -i '/^account\s*required\s*pam_nologin\.so/a account    required     pam_exec.so   /usr/local/bin/logon.sh' /etc/pam.d/login
cat << EOF > /usr/local/bin/logon.sh
#!/bin/bash

if [[ $(/sbin/lid -g admin | grep $PAM_USER) ]]; then
  exit 0
fi
if [[ `date +%u` -gt "5" ]]; then
    exit 1
  else
    exit 0;
fi
EOF
systemctl enable docker
systemctl restart docker
echo 'testuser01 ALL=NOPASSWD: /bin/systemctl restart docker.service, /bin/systemctl restart docker' > /etc/sudoers.d/testuser01