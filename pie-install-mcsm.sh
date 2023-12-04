#!/bin/bash

dir=/opt/mcsmanager
node_ver=14
mcs_manager_download="https://github.com/MCSManager/MCSManager/releases/latest/download"
mcs_manager_filename="mcsmanager_linux_release.tar.gz"

if [ $(id -u) -ne 0 ]; then
    echo -e "You need root permissions to execute this script. Please use sudo or switch to the root user."
    exit 1
fi

verify_dependant_tool() {
    #Preping variables
    local tool="${1,,}"
    local install_cmd=''
    case "$tool" in
    "node") 
      if $# > 1
      then
        install_cmd='snap install $tool --classic --channel=$2'
      else
        echo "Missing desired ${tool} version! skipping..."
      fi
      ;;
    "git" | "tar")
      install_cmd='apt install $tool'
      ;;
    *)
      echo "Tool not expected! Skipping..."
      ;;
    esac

    if test -z "$install_cmd"
    then
        echo "Verifying ${tool} installation..."

        if ! command -v ${tool} &> /dev/null
        then
          echo "${tool} is missing. Installing ${tool} now..."
          $install_cmd
          if command -v git &> /dev/null
          then
            echo -e "Git could not be installed via apt"
            exit 1
          fi
        fi
        echo
    fi
}

verify_dependant_tool "node" $node_ver
verify_dependant_tool "git"
verify_dependant_tool "tar"

mkdir $dir

echo "+-------------------------------------------------------------------------+"
echo "| MCSManager Installer                                                    |"
echo "+-------------------------------------------------------------------------+"
echo "| Copyright © 2023 MCSManager.                                            |"
echo "+-------------------------------------------------------------------------+"
echo "| Contributors: Nuomiaa, CreeperKong, Unitwk, FunnyShadow                 |"
echo "|     Install script by KillerOfPie                                       |"
echo "+-------------------------------------------------------------------------+"
echo
echo


echo "[+] Install MCSManager..."

# Stop Service
systemctl stop mcsm-{web,daemon}

echo

# Delete Service
rm -rf /etc/systemd/system/mcsm-daemon.service
rm -rf /etc/systemd/system/mcsm-web.service

echo

systemctl daemon-reload

echo

cd $dir || exit

echo

wget $mcs_manager_download/$mcs_manager_filename

echo

tar -zxf $mcs_manager_filename
rm -rf $mcs_manager_filename

echo

cd daemon || exit

echo

echo "[+] Install MCSManager-Daemon dependencies..."
npm install --registry=https://registry.npmmirror.com --production > npm_install_log

echo

cd ../web || exit

echo "[+] Install MCSManager-Web dependencies..."
npm install --registry=https://registry.npmmirror.com --production > npm_install_log

echo

echo
echo "================ MCSManager ==============="
echo "Daemon: ${dir}/daemon"
echo "Web: ${dir}/web"
echo "================ MCSManager ==============="
echo

sleep 3

echo "[+] Create MCSManager service..."

echo "
[Unit]
Description=MCSManager Daemon

[Service]
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=node app.js
ExecReload=/bin/kill -s QUIT $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/mcsm-daemon.service

echo "
[Unit]
Description=MCSManager Web

[Service]
WorkingDirectory=/opt/mcsmanager/web
ExecStart=node app.js
ExecReload=/bin/kill -s QUIT $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Environment=\"PATH=${PATH}\"

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/mcsm-web.service

systemctl daemon-reload
systemctl enable mcsm-daemon.service --now
systemctl enable mcsm-web.service --now

#Create command scripts for common commands
script_dir="/usr/local/bin/mcsmanager"
script_file="${script_dir}/mcsm"
script_link="/usr/local/bin/mcsm"
mkdir "${script_dir}"
rm -f $script_file
touch $script_file
echo '
#!/bin/bash

#
# MCSM Command Script
# Contributors: KillerOfPie
#

echo_help() {
  echo "Command could not be recognized. Valid commands are: "
  echo "mcsm panel start - starts the panel"
  echo "mcsm panel stop - stpos the panel"
  echo "mcsm panel restart - restarts the panel"
}

if [[ "${1,,}" =~ ^(panel)$ ]]
then
  case "$2" in
    "start") systemctl start mcsm-{daemon,web}.service
    ;;
    "stop") systemctl stop mcsm-{daemon,web}.service
    ;;
    "restart") systemctl restart mcsm-{daemon,web}.service
    ;;
    *) echo_help
    ;;
  esac
else echo_help
fi
' >>  $script_file
if [ -s $script_file ]; then
        # The file is not-empty.
        echo "Command script installed!"
else
        # The file is empty.
        echo "Command script installation failed!"
fi

chmod +x ${script_file}
if ! test -f ${script_link}; then
 echo "Sym-Link doesn't exist, creating..."
  ln -s ${script_file} ${script_link}
else
  echo "Sym-Link already exists skipping creation."
fi

sleep 3

echo "=================================================================="
echo "The installation is complete! Welcome to use the MCSManager panel!"
echo " "
echo "Control panel address: "
echo "http://your public IP:23333"
echo "You must open ports 23333 (Panel) and 24444 (Daemon). The control panel requires these two ports to work properly."
echo " "
echo "The following are some commonly used commands:"
echo "mcsm panel start"
echo "mcsm panel stop"
echo "mcsm panel restart"
echo " "
echo "Official documentation (must read): https://docs.mcsmanager.com/"
echo "=================================================================="
