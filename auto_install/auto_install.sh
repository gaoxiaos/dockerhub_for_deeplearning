#!/bin/sh

if [ $# -eq 5 ]; then
    driver_version="$1"
    cuda_version="$2"
    cudnn_version="$3"
    is_install_perseus="$4"
    is_install_rapids="$5"

fi

AUTO_INSTALL="/root/auto_install"
CUDA_DIR="/root/auto_install/cuda"

mkdir -p ${AUTO_INSTALL}
mkdir -p ${CUDA_DIR}
log=${AUTO_INSTALL}"/auto_install.log"
PROCESS_NAME="$0"
issue=$(cat /etc/issue | grep Ubuntu)
if [ -n "$issue" ];then
    os="ubuntu"
    DRIVER_PROCESS_NAME="cuda-drivers"
    CUDA_PROCESS_NAME="cuda "
    DOWNLOAD_DRIVER="nvidia-"
    #DOWNLOAD_DRIVER="nvidia*driver"
else
    DRIVER_PROCESS_NAME="${AUTO_INSTALL}/NVIDIA-Linux-x86_64"
    CUDA_PROCESS_NAME="${AUTO_INSTALL}/cuda"
    DOWNLOAD_DRIVER="NVIDIA-Linux"
fi


RAPIDS_PROCESS_NAME="${AUTO_INSTALL}/rapids"
PERSEUS_PROCESS_NAME="${AUTO_INSTALL}/miniconda"
CUDNN_PROCESS_NAME="${AUTO_INSTALL}/cudnn"
NCCL_PROCESS_NAME="${AUTO_INSTALL}/nccl"
DOWNLOAD_PROCESS_NAME="wget"
SUCCESS_STR="ALL INSTALL OK"
DOWNLOAD_SUCCESS_STR="Download OK"

DRIVER_FAIL_STR="Driver INSTALL FAIL"
CUDA_FAIL_STR="CUDA INSTALL FAIL"
CUDNN_FAIL_STR="CUDNN INSTALL FAIL"
NCCL_FAIL_STR="NCCL INSTALL FAIL"
PERSEUS_FAIL_STR="PERSEUS ENV INSTALL FAIL"
RAPIDS_FAIL_STR="RAPIDS INSTALL FAIL"
DOWNLOAD_FAIL_STR="Download FAIL"

install_notes="The script automatically downloads and installs a NVIDIA GPU driver and CUDA, CUDNN library. if you choose install perseus, perseus environment will install as well.
1. The installation takes 15 to 20 minutes, depending on the intranet bandwidth and the quantity of vCPU cores of the instance. Please do not operate the GPU or install any GPU-related software until the GPU driver is installed successfully.
2. After the GPU is installed successfully, the instance will restarts automatically."

check_install()
{
    b=''
    if [ "$1" = "NVIDIA" ]; then
        ProcessName=${DRIVER_PROCESS_NAME}
        t=2
    elif [ "$1" = "cuda" ]; then
        ProcessName=${CUDA_PROCESS_NAME}
        t=3
    elif [ "$1" = "cudnn" ]; then
        ProcessName=${CUDNN_PROCESS_NAME}
        t=0.5
    elif [ "$1" = "nccl" ]; then
        ProcessName=${NCCL_PROCESS_NAME}
        t=0.5
    elif [ "$1" = "rapids" ]; then
        ProcessName=${RAPIDS_PROCESS_NAME}
        t=1
    elif [ "$1" = "perseus" ]; then
        ProcessName=${PERSEUS_PROCESS_NAME}
        t=1
    fi
    i=0
    while true
    do
        pid_num=$(ps -ef | grep ${ProcessName} |grep -v grep | wc -l)
        if [ $pid_num -eq 0 ]; then
            str=$(printf "%-100s" "#")
            b=$(echo "$str" | sed 's/ /#/g')
            printf "| %-100s | %d%% \r\n" "$b" "100";
            break
        fi
        i=$(($i+1))
        str=$(printf "%-${i}s" "#")
        b=$(echo "$str" | sed 's/ /#/g')
        printf "| %-100s | %d%% \r" "$b" "$i";
        sleep $t
    done
    echo
    return 0
}

check_download()
{
    name=$1
    i=0
    b=''
    filesize=0
    percent=0

    sleep 0.5
    while true
    do
        pid_num=$(ps -ef | grep wget |grep ${name} |grep -v grep | wc -l)
        if [ $pid_num -eq 0 ]; then
            filesize=$(du -sk ${AUTO_INSTALL}/${name}* | awk '{print $1}')
            str=$(printf "%-100s" "#")
            b=$(echo "$str" | sed 's/ /#/g')
            printf "%-8s| %-100s | %d%% \r\n" "${filesize}K" "$b" "100";
            break
        fi
        line=$(tail -2 ${log})
        filesize=$(echo $line | awk -F ' ' '{print $1}')
        percent=$(echo $line | awk -F '%' '{print $1}' | awk -F ' ' '{print $NF}')
        if [ "$percent" -ge 0 ] 2>/dev/null ;then
           str=$(printf "%-${percent}s" "#")
           b=$(echo "$str" | sed 's/ /#/g')
           printf "%-8s| %-100s | %d%% \r" "${filesize}" "$b" "$percent";
        else
            continue
        fi
        sleep 0.5

    done
    return 0
}

check_install_log()
{
    if [ ! -f "$log" ];then
        echo "NVIDIA install log $log not exist! Install may fail!"
        echo
        exit 1
    fi

    if [ "$1" = "NVIDIA" ]; then
        succstr=$(cat $log |grep "${SUCCESS_STR}")
        str2=$(cat $log |grep "INSTALL_ERROR")
        if [ -n "${succstr}" ] && [ -z "${str2}" ]; then
            echo "${succstr} !!"
            echo
            return 0
        else
            echo "Install may have some INSTALL_ERROR, please check log $log !"
            return 1
        fi
    fi

    if [ "$1" = "DRIVER" ]; then
        failstr=${DRIVER_FAIL_STR}
    elif [ "$1" = "CUDA" ]; then
        failstr=${CUDA_FAIL_STR}
    elif [ "$1" = "CUDNN" ]; then
        failstr=${CUDNN_FAIL_STR}
    elif [ "$1" = "NCCL" ]; then
        failstr=${NCCL_FAIL_STR}
    elif [ "$1" = "PERSEUS" ]; then
        failstr=${PERSEUS_FAIL_STR}
    elif [ "$1" = "RAPIDS" ]; then
        failstr=${RAPIDS_FAIL_STR}
    fi
    str1=$(cat $log |grep "${failstr}")
    if [ -n "${str1}" ] ;then
        echo
        echo "${failstr} ! please check install log ${log} !"
        return 1
    fi
}

check_install_process()
{
    echo "CHECKING AUTO INSTALL, DRIVER_VERSION=${1} CUDA_VERSION=${2} CUDNN_VERSION=${3} INSTALL PERSEUS=${4} INSTALL RAPIDS=${5}, PLEASE WAIT ......"
    echo "$install_notes"
    echo

    while true
    do
        pid_num=$(ps -ef | grep ${PROCESS_NAME} |grep -v grep | grep -v check | wc -l)
        if [ $pid_num -eq 0 ];then
            check_install_log "NVIDIA"
            return 0
        else
            pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep driver |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "Driver-${1} downloading, it takes 30 seconds or more. Remaining installation time 15 to 20 minutes!"
                check_download ${DOWNLOAD_DRIVER}
            fi

            pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep cuda |grep -v nccl |grep -v rapids |grep -v perseus |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "CUDA-${2} downloading, it takes 3 minutes or more. Remaining installation time 14 - 19 minutes!"
                while true
                do
                    check_download "cuda"
                    sleep 1
                    pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep cuda |grep -v nccl |grep -v rapids |grep -v perseus |grep -v grep | wc -l)
                    if [ $pid_num -eq 0 ];then
                        break
                    fi
                done
            fi

            pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep cudnn |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "cuDNN-${3} downloading, it tasks 1 minutes or more. Remaining installation time 12 - 16 minutes!"
                check_download "cudnn"
            fi

            #add rapids file download check
            pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep rapids |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "RAPIDS downloading, it tasks 3 minutes or more. Remaining installation time 4 - 6 minutes!"
                check_download "rapids"
            fi

            #add perseus file download check
            pid_num=$(ps -ef | grep ${DOWNLOAD_PROCESS_NAME} |grep perseus |grep miniconda |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "PERSEUS downloading, it tasks 3 minutes or more. Remaining installation time 4 - 6 minutes!"
                check_download "miniconda"
            fi

            pid_num=$(ps -ef | grep "${DRIVER_PROCESS_NAME}" |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo
                echo "Driver-${1} installing, it tasks 1 to 3 minutes. Remaining installation time 11 to 15 minutes!"
                check_install "NVIDIA"
                check_install_log "DRIVER"
            fi
            pid_num=$(ps -ef | grep "${CUDA_PROCESS_NAME}" |grep -v nccl |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "CUDA-${2} installing, it tasks 2 to 5 minutes. Remaining installation time 9 to 12 minutes!"
                check_install "cuda"
                check_install_log "CUDA"
            fi
            pid_num=$(ps -ef | grep ${CUDNN_PROCESS_NAME} |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "cuDNN-${3} installing, it takes about 10 seconds. Remaining installation time 6 to 9 minutes!"
                check_install "cudnn"
                check_install_log "CUDNN"
            fi
            pid_num=$(ps -ef | grep ${NCCL_PROCESS_NAME} |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "NCCL installing, it taskes about 10 seconds. "
                check_install "nccl"
                check_install_log "NCCL"
            fi

            pid_num=$(ps -ef | grep ${RAPIDS_PROCESS_NAME} |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "RAPIDS installing, it taskes about 60 seconds. Installation will be successful soon, please wait......"
                check_install "rapids"
                check_install_log "RAPIDS"
            fi

            pid_num=$(ps -ef | grep ${PERSEUS_PROCESS_NAME} |grep -v grep | wc -l)
            if [ $pid_num -gt 0 ];then
                echo "PERSEUS installing, it taskes about 60 seconds. Installation will be successful soon, please wait......"
                check_install "perseus"
                check_install_log "PERSEUS"
            fi
        fi
        sleep 1
    done
}

create_nvidia_repo_centos()
{
    baseurl_centos=$(curl http://100.100.100.200/latest/meta-data/source-address | head -1)
    #cudaurl=$baseurl_centos"/opsx/ecs/linux/rpm/cuda/${version}/\$basearch/"
    driverurl=$baseurl_centos"/opsx/ecs/linux/rpm/driver/${version}/\$basearch/"
    #echo "[ecs-cuda]" > /etc/yum.repos.d/nvidia.repo
    #echo "name=ecs cuda - \$basearch" >> /etc/yum.repos.d/nvidia.repo
    #echo "baseurl=$cudaurl" >> /etc/yum.repos.d/nvidia.repo
    #echo "enabled=1" >> /etc/yum.repos.d/nvidia.repo
    #echo "gpgcheck=0" >> /etc/yum.repos.d/nvidia.repo
    echo "[ecs-driver]" >> /etc/yum.repos.d/nvidia.repo
    echo "name=ecs driver - \$basearch" >> /etc/yum.repos.d/nvidia.repo
    echo "baseurl=$driverurl" >> /etc/yum.repos.d/nvidia.repo
    echo "enabled=1" >> /etc/yum.repos.d/nvidia.repo
    echo "gpgcheck=0" >> /etc/yum.repos.d/nvidia.repo
    yum clean all >> $log 2>&1
    yum makecache >> $log 2>&1
}

disable_nouveau_centos()
{
    if  [ ! -f /etc/modprobe.d/blacklist-nouveau.conf ];then
        echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
        echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
    fi
    content=$(lsmod |grep nouveau)
    if [ -n "$content" ];then
        rmmod nouveau
        echo "***exec \"dracut --force\" to regenerate the kernel initramfs"
        dracut --force
    fi
}

disable_nouveau_alinux()
{
    if [ ! -f /etc/modprobe.d/blacklist-nouv.conf ]; then
        echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouv.conf
        echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouv.conf
    fi
    if lsmod | grep -q nouveau; then
        rmmod nouveau
        echo "***exec \"dracut --force\" to regenerate the kernel initramfs"
        dracut --force
    fi
}

disable_nouveau_ubuntu()
{
    if  [ ! -f /etc/modprobe.d/blacklist-nouveau.conf ];then
        echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
        echo "blacklist lbm-nouveau" >> /etc/modprobe.d/blacklist-nouveau.conf
        echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
    fi
    content=$(lsmod |grep nouveau)
    if [ -n "$content" ];then
        rmmod nouveau
        echo "***exec \"update-initramfs -u\" to regenerate the kernel initramfs"
        update-initramfs -u
    fi
}
install_kernel_centos()
{
    kernel_version=$(uname -r)
    kernel_devel_num=$(rpm -qa | grep kernel-devel | grep $kernel_version | wc -l)
    if [ $kernel_devel_num -eq 0 ];then
        echo "******exec \"yum install -y kernel-devel-$kernel_version\""
        yum install -y kernel-devel-$kernel_version
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: install kernel-devel fail!!!"
            return 1
        fi
    fi
    return 0
}
install_kernel_alinux()
{
    kernel_version=$(uname -r)
    if ! rpm -qa | grep kernel-devel | grep -q $kernel_version; then
        echo "******exec \"yum install -y kernel-devel-$kernel_version\""
        yum install -y kernel-devel-$kernel_version
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: install kernel-devel fail!!!"
            return 1
        fi
    fi
    return 0
}
install_kernel_sles()
{
    kernel_version=$(uname -r|awk -F'-' '{print $1"-"$2}')
    kernel_devel_num=$(rpm -qa | grep kernel-default-devel | wc -l)
    if [ $kernel_devel_num -eq 0 ];then
        echo "***exec \"zypper install -y kernel-default-devel=$kernel_version\""
        zypper install -y kernel-default-devel=$kernel_version
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: install kernel-default-devel fail!!!"
            return 1
        fi
    fi
}
install_kernel_ubuntu()
{
    kernel_version=$(uname -r)
    linux_headers_num=$(dpkg --list |grep linux-headers | grep $kernel_version | wc -l)
    if [ $linux_headers_num -eq 0 ];then
        echo "***exec \"apt-get install -y --allow-unauthenticated linux-headers-$kernel_version\""
        apt-get install -y --allow-unauthenticated linux-headers-$kernel_version
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: install linux-headers fail!!!"
            return 1
        fi
    fi
}

download()
{
    cd ${AUTO_INSTALL}
    wget -t 100 --timeout=10 ${download_url}/nvidia/driver/${driver_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: Download driver fail!!! return: $?"
        return 1
    fi

    if [ "$os" = "centos" -a "$version" = "6" ];then
        if [ "${cuda_big_version}" = "8.0" -o "${cuda_big_version}" = "9.0" -o "${cuda_big_version}" = "9.2" \
             -o "${cuda_big_version}" = "10.0" ];then

            ar=$(curl ${download_url}/nvidia/cuda/${cuda_version}/ > ./tmp)
            echo "${download_url}/nvidia/cuda/${cuda_version}/"
            cudafilelist=$(cat ./tmp | perl -n -e'/>(cuda[^<]*)</ && print "$1 \n"' | grep -v ubuntu)
        else
            ar=$(curl ${download_url}/nvidia/cuda/${cuda_version}/rhel6/ > ./tmp)
            cudafilelist=$(cat ./tmp | perl -n -e'/>(cuda[^<]*)</ && print "$1 \n"')
        fi
    else
        ar=$(curl ${download_url}/nvidia/cuda/${cuda_version}/ > ./tmp)
        echo "${download_url}/nvidia/cuda/${cuda_version}/"
        cudafilelist=$(cat ./tmp | perl -n -e'/>(cuda[^<]*)</ && print "$1 \n"' | grep -v ubuntu)
    fi

    if [ -z "$cudafilelist" ]; then
        echo "INSTALL_ERROR: Download CUDA fail!!! get cuda-${cuda_version} filename fail!!"
        return 1
    fi

    cd ${CUDA_DIR}
    echo $cudafilelist
    for cudafile in $cudafilelist
    do
        sleep 1
        if [ "$os" = "centos" -a "$version" = "6" ];then
            if [ "${cuda_big_version}" = "8.0" -o "${cuda_big_version}" = "9.0" -o "${cuda_big_version}" = "9.2" \
                 -o "${cuda_big_version}" = "10.0" ];then
                wget -t 100 --timeout=10 ${download_url}/nvidia/cuda/${cuda_version}/$cudafile
            else
                wget -t 100 --timeout=10 ${download_url}/nvidia/cuda/${cuda_version}/rhel6/$cudafile
            fi
        else
            wget -t 100 --timeout=10 ${download_url}/nvidia/cuda/${cuda_version}/$cudafile
        fi
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: Download CUDA fail!!! wget $cudafile fail! return: $?"
            return 1
        fi
    done
    chmod +x ${CUDA_DIR}/*

    cd ${AUTO_INSTALL}
    wget -t 100 --timeout=10 ${download_url}/nvidia/cudnn/${cuda_big_version}/${cudnn_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: Download cuDNN fail!!! return :$?"
        return 1
    fi

    chmod +x ${AUTO_INSTALL}/*
    echo "$DOWNLOAD_SUCCESS_STR !"
    return 0
}

download_ubuntu()
{
    cd ${AUTO_INSTALL}

    ar=$(curl ${download_url}/nvidia/ubuntu/driver/ > ./tmp)
    driver_file=$(cat ./tmp | perl -n -e'/(nvidia[^"]*)">/ && print "$1 \n"' |grep $ubuntu_version | grep ${driver_version})
    echo "driver file: ${driver_file}"

    wget -t 100 --timeout=10 ${download_url}/nvidia/ubuntu/driver/${driver_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: Download driver fail!!! return: $?"
        return 1
    fi
    rm -f ./tmp

    cd ${CUDA_DIR}
    ar=$(curl ${download_url}/nvidia/ubuntu/cuda/${cuda_version}/ > ./tmp)
    #download file begin with cuda
    cudafilelist=$(cat ./tmp | perl -n -e'/(cuda[^"]*)">/ && print "$1 \n"' |grep $ubuntu_version)
    if [ -z "$cudafilelist" ]; then
        echo "INSTALL_ERROR: Download CUDA fail!!! get cuda-${cuda_version} filename fail!!"
        return 1
    fi

    echo $cudafilelist
    for cudafile in $cudafilelist
    do
        sleep 1
        wget -t 100 --timeout=10 ${download_url}/nvidia/ubuntu/cuda/${cuda_version}/$cudafile
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: Download CUDA fail!!! wget $cudafile fail! return: $?"
            return 1
        fi
    done
    chmod +x ${CUDA_DIR}/*

    cd ${AUTO_INSTALL}
    wget -t 100 --timeout=10 ${download_url}/nvidia/cudnn/${cuda_big_version}/${cudnn_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: Download cuDNN fail!!! return :$?"
        return 1
    fi

    chmod +x ${AUTO_INSTALL}/*
    echo "$DOWNLOAD_SUCCESS_STR !"
    return 0

}
install_driver_ubuntu()
{
    cd ${AUTO_INSTALL}
    echo "******exec \"apt-key add /var/nvidia*driver*${driver_version}/*.pub\""
    echo "******exec \"apt-get update && apt-get install -y --allow-unauthenticated cuda-drivers\" "
    dpkg -i ${driver_file} && apt-key add /var/nvidia*driver-local-repo-${driver_version}/7fa2af80.pub && apt-get update && apt-get install  --allow-unauthenticated cuda-drivers -y

    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: driver install fail!!!"
        return 1
    fi
    return 0
}

install_cuda_ubuntu()
{
    cd ${CUDA_DIR}
    cuda_bin_file="cuda-${ubuntu_version}.pin"
    if [ -f "${cuda_bin_file}" ];then
        echo "move cuda_bin_file:${cuda_bin_file} to /etc/apt/preferences.d/cuda-repository-pin-600"
        mv ${cuda_bin_file} /etc/apt/preferences.d/cuda-repository-pin-600
    fi

    cuda_file=$(ls -S | grep cuda | grep $cuda_version | head -1)
    echo "cuda file: "${cuda_file}
    if [ -z "${cuda_file}" ]
    then
        echo "INSTALL_ERROR: cuda file is null, cuda install fail!!!"
        return 1
    fi

    dpkg -i ${cuda_file}
    cuda_patchfile=$(ls | grep cuda | grep -v ${cuda_file})
    for cuda_patch in ${cuda_patchfile}
    do
        echo "install cuda patch file: "${cuda_patch}
        dpkg -i ${cuda_patch}
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: cuda patch install fail!!!"
            return 1
        fi
    done

    echo "******exec \"apt-get update && apt-get install -y --allow-unauthenticated cuda\" "
    apt-key add /var/cuda-repo-*/7fa2af80.pub
    apt-get update && apt-get install --allow-unauthenticated cuda -y
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: cuda install fail!!!"
        return 1
    fi
    echo "CUDA $cuda_version install OK !"
    return 0
}
install_driver()
{
    ${AUTO_INSTALL}/${driver_file} --silent
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: driver install fail!!!"
        return 1
    fi
    echo "DRIVER $driver_version install OK !"
    return 0
}

install_cuda()
{
    cd ${CUDA_DIR}
    cuda_file=$(ls -S | grep cuda | grep $cuda_version | head -1)
    echo "cuda file: "$cuda_file
    if [ -z "$cuda_file" ]
    then
        echo "INSTALL_ERROR: cuda file is null, cuda install fail!!!"
        return 1
    fi

    sh ${CUDA_DIR}/$cuda_file --silent --toolkit --samples --samplespath=/root
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: cuda install fail!!!"
        return 1
    fi

    cuda_patchfile=$(ls | grep cuda | grep $cuda_version | grep -v ${cuda_file})
    for cuda_patch in $cuda_patchfile
    do
        echo "install cuda patch file: "$cuda_patch
        sh ${CUDA_DIR}/${cuda_patch} --silent --installdir=/usr/local/cuda --accept-eula
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: cuda patch install fail!!!"
            return 1
        fi
    done
    echo "CUDA $cuda_version install OK !"
    return 0
}

install_cudnn()
{
    tar zxvf ${AUTO_INSTALL}/$cudnn_file -C /usr/local
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: CUDNN INSTALL FAIL !!!"
        return 1
    fi
    echo "CUDNN $cudnn_version install OK !"
    return 0
}

install_nccl()
{
    cd ${AUTO_INSTALL}
    #download nccl
    curl ${download_url}/nvidia/nccl/${cuda_big_version}/ > ./tmp
    br=$(cat ./tmp | perl -n -e'/>nccl_(.*)-1\+cuda.*/ && print "$1 \n"')
    cr=$(echo "${br}" | sort -rV | head -n1)
    nccl_version=$(echo ${cr} | awk -F ' ' '{print $1}')
    echo "max nccl version:$nccl_version"
    nccl_dir="nccl_${nccl_version}-1+cuda${cuda_big_version}_x86_64"
    nccl_file="${nccl_dir}.txz"

    echo $nccl_file
    wget -t 100 --timeout=10 ${download_url}/nvidia/nccl/${cuda_big_version}/${nccl_file}
    chmod +x $nccl_file
    tar xf ${AUTO_INSTALL}/${nccl_file} && cp -r ${nccl_dir} /usr/local/nccl
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: NCCL INSTALL FAIL !!!"
        return 1
    fi
    echo "NCCL $nccl_version install OK !"
    return 0
}

enable_pm()
{
    cd /usr/share/doc/NVIDIA_GLX-1.0/sample*
    if [ "$os" = "centos" -o "$os" = "alinux" ];then
        yum install bzip2 -y
    fi

    bunzip2 nvidia-persistenced-init.tar.bz2
    tar xvf nvidia-persistenced-init.tar
    cd nvidia-persistenced-init && sh install.sh -u root
}

enable_pm_ubuntu()
{
    echo "#!/bin/bash" | tee -a /etc/init.d/enable_pm.sh
    echo "nvidia-smi -pm 1" | tee -a /etc/init.d/enable_pm.sh
    echo "exit 0" | tee -a /etc/init.d/enable_pm.sh

    chmod +x /etc/init.d/enable_pm.sh

    str=$(tail -1 $filename |grep "exit")
    if [ -z "$str" ]; then
        echo "/etc/init.d/enable_pm.sh" | tee -a $filename
    else
        sed -i '$i\/etc/init.d/enable_pm.sh' $filename
    fi
    chmod +x $filename
}


set_env()
{
    env_path="/usr/local/bin:/usr/local/cuda-${cuda_big_version}/bin:"
    #env_library="/usr/local/cuda-${cuda_big_version}/lib64:/usr/local/nccl/lib:"
    env_library="/usr/local/lib:/usr/local/cuda-${cuda_big_version}/lib64:"
    env1="export PATH=${env_path}\$PATH"
    env2="export LD_LIBRARY_PATH=${env_library}\$LD_LIBRARY_PATH"

    echo $env1 >> ${env_file}
    echo $env2 >> ${env_file}

}

install_dependencies()
{
    cd ${AUTO_INSTALL}

    curl ${download_url}/perseus/ > ./tmp
    if [ "$os" = "ubuntu" ]; then
        #download the latest openmpi pkg
        br=$(cat ./tmp | perl -n -e'/>openmpi_(.*)_amd64.deb/ && print "$1 \n"')
        cr=$(echo "${br}" | sort -rV | head -n1)
        openmpi_version=$(echo ${cr} | awk -F ' ' '{print $1}')
        openmpi_file=openmpi_${openmpi_version}_amd64.deb

        wget -t 100 --timeout=10 ${download_url}/perseus/${openmpi_file}
        dpkg -i ${openmpi_file}
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: Openmpi INSTALL FAIL !!!"
            return 1
        fi

        mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real
        echo "#!/bin/bash" > /usr/local/bin/mpirun
        echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/local/bin/mpirun
        chmod a+x /usr/local/bin/mpirun

        mkdir -p /root/.openmpi
        echo "hwloc_base_binding_policy=none" >> /root/.openmpi/mca-params.conf

        apt-get update
        apt-get install -y curl openssh-client openssh-server

    elif [ "$os" = "centos" ]; then
        #yum -y update
        yum clean all
        yum -y install epel-release
        yum -y install perl openssh-clients openssh-server openblas-devel


        #download the latest openmpi pkg
        br=$(cat ./tmp | perl -n -e'/>openmpi-(.*).el7.x86_64.rpm/ && print "$1 \n"')
        cr=$(echo "${br}" | sort -rV | head -n1)
        openmpi_version=$(echo ${cr} | awk -F ' ' '{print $1}')
        openmpi_file=openmpi-${openmpi_version}.el7.x86_64.rpm

        wget -t 100 --timeout=10 ${download_url}/perseus/${openmpi_file}
        rpm -Uivh ${openmpi_file}
        if [ $? -ne 0 ]; then
            echo "INSTALL_ERROR: Openmpi INSTALL FAIL !!!"
            return 1
        fi

        mv /usr/bin/mpirun /usr/bin/mpirun.real
        echo '#!/bin/bash' > /usr/bin/mpirun
        echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/bin/mpirun
        chmod a+x /usr/bin/mpirun

        mkdir -p /root/.openmpi
        echo "hwloc_base_binding_policy=none" >> /root/.openmpi/mca-params.conf
    fi
    echo "PERSEUS install_dependencies OK !"
    rm -f ./tmp
    return 0
}
install_perseus()
{
    cd ${AUTO_INSTALL}

    #download the latest perseus pkg
    #curl ${download_url}/perseus/cuda${cuda_big_version}/ > ./tmp
    curl ${download_url}/perseus/cuda${cuda_big_version}/ > ./tmp
    br=$(cat ./tmp | perl -n -e'/>miniconda-cuda.*-perseus(.*).tgz/ && print "$1 \n"')
    cr=$(echo "${br}" | sort -rV | head -n1)
    perseus_version=$(echo ${cr} | awk -F ' ' '{print $1}')
    if [ -z "${perseus_version}" ]; then
        echo "INSTALL_ERROR: PERSEUS INSTALL FAIL! get perseus package name fail!!! return :$?"
        return 1
    fi

    perseus_file="miniconda-cuda${cuda_big_version}-perseus${perseus_version}.tgz"
    perseus_env_file="perseus_cuda${cuda_big_version}_env_${perseus_version}"
    echo "perseus_version=${perseus_version}"
    echo "perseus_file=${perseus_file}"
    echo "perseus_env_file=${perseus_env_file}"

    wget -t 100 --timeout=10 ${download_url}/perseus/cuda${cuda_big_version}/${perseus_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: PERSEUS INSTALL FAIL! Download perseus env package fail!!! return :$?"
        return 1
    fi

    wget -t 100 --timeout=10 ${download_url}/perseus/cuda${cuda_big_version}/${perseus_env_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: PERSEUS INSTALL FAIL! Download perseus env package fail!!! return :$?"
        return 1
    fi

    chmod +x ${AUTO_INSTALL}/*
    tar zxvf ${AUTO_INSTALL}/${perseus_file} -C /root && cat ${AUTO_INSTALL}/${perseus_env_file} >> /root/.bashrc
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: PERSEUS INSTALL FAIL! INSTALL perseus env package fail!!! return :$?"
        return 1
    fi

    echo "PERSEUS unpack OK !"

    install_dependencies
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: PERSEUS INSTALL FAIL! INSTALL dependencies fail!!! return :$?"
        return 1
    fi
    rm -f ./tmp
    echo "PERSEUS ENV INSTALL OK !"


    cd /root
    wget -t 100 --timeout=10 ${download_url}/perseus/ali-perseus-demos.tgz
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: PERSEUS download demo fail!!! "
        return 1
    fi
    return 0
}

install_rapids()
{
    cd ${AUTO_INSTALL}
    #rapids_file="rapids0.8_py3.6_cuda${cuda_big_version}.tar.gz"
    rapids_env_file="env_add_to_bashrc.log"

    #download the latest rapids pkg
    curl ${download_url}/rapids/cuda${cuda_big_version}/ > ./tmp
    br=$(cat ./tmp | perl -n -e'/>rapids(.*)_miniconda(.*)_cuda.*_py(.*).tar.gz/ && print "$1 $2 $3\n"')
    cr=$(echo "${br}" | sort -rV | head -n1)

    rapids_version=$(echo ${cr} | awk -F ' ' '{print $1}')
    if [ -z "${rapids_version}" ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL! get rapids package name fail!!! return :$?"
        return 1
    fi

    miniconda_version=$(echo ${cr} | awk -F ' ' '{print $2}')
    if [ -z "${miniconda_version}" ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL! get rapids package name fail!!! return :$?"
        return 1
    fi

    py_version=$(echo ${cr} | awk -F ' ' '{print $3}')
    if [ -z "${py_version}" ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL! get rapids package name fail!!! return :$?"
        return 1
    fi
    rapids_file="rapids${rapids_version}_miniconda${miniconda_version}_cuda${cuda_big_version}_py${py_version}.tar.gz"

    wget -t 100 --timeout=10 ${download_url}/rapids/cuda${cuda_big_version}/${rapids_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL! Download rapids package fail!!! return :$?"
        return 1
    fi

    wget -t 100 --timeout=10 ${download_url}/rapids/cuda${cuda_big_version}/${rapids_env_file}
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL!Download rapids package fail!!! return :$?"
        return 1
    fi

    chmod +x ${AUTO_INSTALL}/*
    tar zxvf ${AUTO_INSTALL}/${rapids_file} -C /root && cat ${AUTO_INSTALL}/${rapids_env_file} >> /root/.bashrc
    #cat ${AUTO_INSTALL}/${rapids_env_file} >> /root/.bashrc && source .bashrc
    if [ $? -ne 0 ]; then
        echo "INSTALL_ERROR: RAPIDS INSTALL FAIL! Install rapids package fail!!! return :$?"
        return 1
    fi
    echo "RAPIDS INSTALL OK !"

}

if [ -f "/etc/os-release" ];then
    os=$(cat /etc/os-release |grep "^ID="|awk -F '=' '{print $2}'|sed 's/\"//g')
    if [ "$os" = "ubuntu" ];then
        profile_file="/root/.profile"
        env_file="/root/.bashrc"
    elif [ "$os" = "centos" ];then
        profile_file="/root/.bash_profile"
        env_file="/root/.bashrc"
    elif [ "$os" = "alinux" ];then
        profile_file="/root/.bash_profile"
        env_file="/root/.bashrc"
    elif [ "$os" = "sles" ];then
        env_file="/root/.bash_profile"
        profile_file="/root/.bash_profile"
    fi
else
    issue=$(cat /etc/issue | grep CentOS)
    if [ -n "$issue" ];then
        os="centos"
        env_file="/root/.bashrc"
        profile_file="/root/.bash_profile"
    fi
fi


if [ "$1" = "check" ];then
    check_install_process $2 $3 $4 $5 $6
    sed -i '/auto_install/d' $profile_file
    exit 0
else
    echo "begin to install, driver: $driver_version, cuda: $cuda_version, cudnn: $cudnn_version " >> $log 2>&1
    driver_file="NVIDIA-Linux-x86_64-"${driver_version}".run"
    cuda_big_version=$(echo $cuda_version | awk -F'.' '{print $1"."$2}')
    cudnn_file="cudnn-"${cuda_big_version}"-linux-x64-v"${cudnn_version}".tgz"

    echo "sh ${PROCESS_NAME} check $driver_version $cuda_version $cudnn_version ${is_install_perseus} ${is_install_rapids}" | tee -a $profile_file
    #echo "sh ${PROCESS_NAME} check $driver_version $cuda_version $cudnn_version ${is_install_perseus}" | tee -a $profile_file
fi
echo "os:$os" >> $log 2>&1
if [ "$os" = "ubuntu" ]; then
    disable_nouveau_ubuntu >> $log 2>&1
    apt-get update

    version=$(cat /etc/os-release |grep "VERSION_ID=" | awk -F '=' '{print $2}'|sed 's/\"//g')
    if [ "$version" = "16.04" ]; then
        ubuntu_version="ubuntu1604"
    elif [ "$version" = "18.04" ];then
        ubuntu_version="ubuntu1804"
    else
        echo "ERROR: Ubuntu version $version is not supported!" >> $log 2>&1
        exit 1
    fi

elif [ "$os" = "centos" ]; then
    disable_nouveau_centos >> $log 2>&1

    if [ ! -f "/usr/bin/gcc" ]; then
        yum install -y gcc
    fi


    if [ -f "/etc/os-release" ];then
        version=$(cat /etc/os-release |grep "VERSION_ID=" | awk -F '=' '{print $2}'|sed 's/\"//g')
    else
        if [ ! -f "/usr/bin/lsb_release" ]; then
            pkgname=$(yum provides /usr/bin/lsb_release |grep centos|grep x86_64 |head -1 |awk -F: '{print $1}')
            if [ -z "$pkgname" ]; then
                echo "INSTALL_ERROR: /usr/bin/lsb_release pkg not exists!" >> $log 2>&1
                exit 1
            fi
            yum install -y $pkgname >> $log 2>&1
        fi
        str=$(lsb_release -r | awk -F'[:.]' '{print $2}')
        version=$(echo $str | sed 's/ //g')

    fi

    if [ "$version" = "8" ]; then
       echo "no nvidia source, install elfutils-libelf-devel"
       yum install elfutils-libelf-devel -y
    fi
    create_nvidia_repo_centos

elif [ "$os" = "alinux" ]; then
    disable_nouveau_alinux >> $log 2>&1

    if [ ! -f "/usr/bin/gcc" ]; then
        yum install -y gcc
    fi

    version=$(cat /etc/os-release | grep "VERSION_ID=" | awk -F '=' '{print $2}' | sed 's/\"//g' | cut -d. -f1)
fi

baseurl=$(curl http://100.100.100.200/latest/meta-data/source-address | head -1)
download_url="${baseurl}/opsx/ecs/linux/binary"


install_kernel_${os} >> $log 2>&1
if [ $? -ne 0 ]; then
    echo "INSTALL_ERROR: kernel-devel install fail!!!" >> $log 2>&1
    exit 1
fi


begin_download=$(date '+%s')

if [ "$os" = "ubuntu" ];then
    echo "ubuntu_version: $ubuntu_version" >> $log 2>&1
    download_ubuntu >> $log 2>&1
else
    download >> $log 2>&1
fi
if [ $? -ne 0 ]; then
    exit 1
fi
end_download=$(date '+%s')
time_download=$((end_download-begin_download))
echo "NVIDIA download OK! Using time $time_download s !!" >> $log 2>&1

begin=$(date '+%s')
if [ "$os" = "ubuntu" ];then
    echo "ubuntu_version: $ubuntu_version" >> $log 2>&1
    install_driver_ubuntu >> $log 2>&1
    if [ $? -ne 0 ]; then
        exit 1
    fi
    if [ "$ubuntu_version" = "ubuntu1604" ];then
        echo "add enable_pm ......" >> $log 2>&1
        filename="/etc/rc.local"
        enable_pm_ubuntu
    fi

else
    install_driver >> $log 2>&1
    if [ $? -ne 0 ]; then
        exit 1
    fi
    enable_pm >> $log 2>&1
fi

echo "NVIDIA install driver OK!!!" >> $log 2>&1

if [ "$os" = "ubuntu" ];then
    install_cuda_ubuntu >> $log 2>&1
else
    install_cuda >> $log 2>&1
fi
if [ $? -ne 0 ]; then
    exit 1
fi
echo "NVIDIA install cuda OK!!"  >> $log 2>&1

install_cudnn >> $log 2>&1
if [ $? -ne 0 ]; then
    exit 1
fi
echo "NVIDIA install cudnn OK!!!" >> $log 2>&1
#install_nccl >> $log 2>&1
#if [ $? -ne 0 ]; then
#    exit 1
#fi


set_env
rm -f ${AUTO_INSTALL}/tmp

if [ "${is_install_perseus}" = "TRUE" ]; then
    install_perseus >> $log 2>&1
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "PERSEUS ENV install OK!!!" >> $log 2>&1
fi


if [ "${is_install_rapids}" = "TRUE" ]; then
    install_rapids >> $log 2>&1
    if [ $? -ne 0 ]; then
        exit 1
    fi
    echo "RAPIDS install OK!!!" >> $log 2>&1
fi

end=$(date '+%s')
time_install=$((end-begin))
echo "Install using time $time_install !"
echo "Install using time $time_install !" >> $log 2>&1
echo "SUCCESS_STR" >> $log 2>&1

lsmod |grep nvidia >> $log 2>&1
nvidia-smi >> $log 2>&1

echo  ${SUCCESS_STR} >> $log 2>&1
ldconfig
echo "reboot......" >> $log 2>&1
sleep 60
reboot

