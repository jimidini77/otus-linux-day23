# otus-linux-day23
## *Пользователи и Группы. AAA. PAM*

# **Prerequisite**
- Host OS: Windows 10.0.19043
- Guest OS: CentOS 7.8.2003
- VirtualBox: 6.1.36
- Vagrant: 2.2.19

# **Содержание ДЗ**

* Запретить всем пользователям, кроме группы `admin` логин в выходные (суббота и воскресенье), без учета праздников
* Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

# **Выполнение**

## Запретить всем пользователям, кроме группы `admin` логин в выходные

Создание группы, пользователей. Добавление пользователя в группу.
```sh
groupadd admin
useradd testuser01
useradd testuser02
echo "Test123" | passwd --stdin testuser01
echo "Test123" | passwd --stdin testuser02
gpasswd -a testuser01 admin
```

Анализ на членство в группе и время входа выполнняется модулем `pam_exec`. Проверяется возможность входа через ssh и локальную консоль.

В конфиги `login` и `sshd` pam.d добавлены обязательные требования для анализа
```sh
[root@otus vagrant]# cat /etc/pam.d/sshd
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
#account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/logon.sh
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
[root@otus vagrant]#
[root@otus vagrant]#
[root@otus vagrant]# cat /etc/pam.d/login
#%PAM-1.0
auth [user_unknown=ignore success=ok ignore=ignore default=bad] pam_securetty.so
auth       substack     system-auth
auth       include      postlogin
account    required     pam_nologin.so
account    required     pam_exec.so   /usr/local/bin/logon.sh
account    include      system-auth
password   include      system-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_console.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    include      postlogin
-session   optional     pam_ck_connector.so
```

Скрипт, выполняющий анализ. Если пользователь состоит в группе `admin` модуль разрешает вход, в противном случае выполняется анализ номера текущего дня недели, если номер дня больше пятницы - вход запрещен.
```sh
[root@otus vagrant]# cat /usr/local/bin/logon.sh
#!/bin/bash

if [[ $(/sbin/lid -g admin | grep $PAM_USER) ]]; then
  exit 0
fi
if [[ `date +%u` -gt "5" ]]; then
    exit 1
  else
    exit 0;
fi
```

Теперь при попытке входа по ssh или локально в воскресенье пользователя `testuser02` не входящего в группу `admin` скрипт логина возвращает отказ. Для `testuser01` вход разрешен.
```
PS > ssh testuser02@192.168.11.101
testuser02@192.168.11.102's password:
/usr/local/bin/logon.sh failed: exit code 1
Connection closed by 192.168.11.101 port 22
PS > ssh testuser01@192.168.11.101
testuser01@192.168.11.102's password:
[testuser01@otus ~]$
[testuser01@otus ~]$
[testuser01@otus ~]$ date
Sun Sep 11 05:17:52 UTC 2022
```

##  Выдача пользователю прав на работу с докером и возможность рестартить докер сервис

Права на работу с докером выдаются через членство в группе `docker`:

Если пользователь в ней не состоит, получется ошибка:
```sh
[testuser01@otus ~]$ docker run hello-world
/usr/bin/docker-current: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post http://%2Fvar%2Frun%2Fdocker.sock/v1.26/containers/create: dial unix /var/run/docker.sock: connect: permission denied.
See '/usr/bin/docker-current run --help'.
```

После добавления в группу и рестарта docker.service:
```sh
[root@otus vagrant]# groupadd docker
[root@otus vagrant]# gpasswd -a testuser01 docker
Adding user testuser01 to group docker
[root@otus vagrant]# systemctl restart docker
```
появляются права у пользователя `testuser01`:
```sh
[testuser01@otus ~]$ docker run hello-world
Unable to find image 'hello-world:latest' locally
Trying to pull repository docker.io/library/hello-world ...
latest: Pulling from docker.io/library/hello-world
2db29710123e: Pull complete
Digest: sha256:7d246653d0511db2a6b2e0436cfd0e52ac8c066000264b3ce63331ac66dca625
Status: Downloaded newer image for docker.io/hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```
Для получения прав на перезапуск docker.service обычному пользователю необходимы права `root`:
```sh
[testuser01@otus ~]$ systemctl restart docker
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
Authentication is required to manage system services or units.
Authenticating as: root
Password:
polkit-agent-helper-1: pam_authenticate failed: Authentication failure
==== AUTHENTICATION FAILED ===
Failed to restart docker.service: Access denied
See system logs and 'systemctl status docker.service' for details.
```

Возможно создание sudoers файла для пользователя на выполнение рестарта сервиса:
```sh
[root@otus vagrant]# echo 'testuser01 ALL=NOPASSWD: /bin/systemctl restart docker.service, /bin/systemctl restart docker' > /etc/sudoers.d/testuser01
```
после этого возможен рестарт сервиса:
```sh
[testuser01@otus ~]$ sudo systemctl restart docker
[testuser01@otus ~]$ systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2022-09-11 05:51:56 UTC; 38s ago
     Docs: http://docs.docker.com
 Main PID: 22534 (dockerd-current)
   CGroup: /system.slice/docker.service
           ├─22534 /usr/bin/dockerd-current --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current --default-runtime=docker-runc --exec-opt nat...
           └─22539 /usr/bin/docker-containerd-current -l unix:///var/run/docker/libcontainerd/docker-containerd.sock --metrics-interval=0 --start-timeout ...
```

# **Результаты**

Выполнено развёртывание стенда с настройкой ограничения входа пользователям кроме группы `admin` по дням недели.
Пользователю `testuser01` предоставлены права на работу с Docker и перезапуск службы Docker.
Выполняемые при конфигурировании сервера команды перенесены в bash-скрипт для автоматического конфигурирования машин при развёртывании.
Полученный в ходе работы `Vagrantfile` и внешний скрипт для shell provisioner помещены в публичный репозиторий:

- **GitHub** - https://github.com/jimidini77/otus-linux-day23
