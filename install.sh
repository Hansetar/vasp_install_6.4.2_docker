#!/bin/bash

# 使用方法:
# ./install_docker.sh [工作目录]
# 如果没有提供工作目录，默认使用 /home/src

# 默认工作目录
default_dir_src="/opt/vasp"

# 检查是否提供了参数
if [ "$#" -eq 1 ]; then
    dir_src=$1
else
    dir_src=$default_dir_src
fi

# 如果目录不存在，则创建
if [ ! -d "$dir_src" ]; then
    mkdir -p $dir_src
fi

# 复制必要的文件到工作目录
cp -n ./l_BaseKit_p_2024.2.1.100_offline.sh $dir_src
cp -n ./l_HPCKit_p_2024.2.1.79_offline.sh $dir_src
cp -n ./vasp.6.4.2.tgz $dir_src
cp -n ./vaspkit.1.3.5.linux.x64.tar.gz $dir_src
cp -n ./pot_database.zip $dir_src

# 安装编译环境
cd $dir_src
#复制赝势库
unzip pot_database.zip -d  /pot
export TERM=xterm
sh ./l_BaseKit_p_2024.2.1.100_offline.sh -a --silent --cli --eula accept
sh ./l_HPCKit_p_2024.2.1.79_offline.sh -a --silent --cli --eula accept

# 写道bashrc中
echo 'source /opt/intel/oneapi/setvars.sh ' >> ~/.bashrc
source ~/.bashrc

# 修改MKL路径和权限
cd /opt/intel/oneapi/mkl/2024.2/share/mkl/interfaces/fftw3xf
chmod 777 ../fftw3xf
chmod 777 ./*
make libintel64

# 安装vasp
cd $dir_src
tar -zxvf vasp.6.4.2.tgz
cd vasp.6.4.2
cp arch/makefile.include.intel makefile.include
sed -i 's/CC_LIB      = icc/CC_LIB      = icx/g' makefile.include
sed -i 's/CXX_PARS    = icpc/CXX_PARS    = icpx/g' makefile.include

# 检测CPU架构
if [[ $(lscpu | grep 'Vendor\ ID' | awk '{print$3}') == "AuthenticAMD" ]]; then 
    # 如果是AMD CPU，执行sed命令
    sed -i 's/FC          = mpiifort/FC          = mpiifx/' makefile.include && 
    sed -i 's/FCL         = mpiifort/FCL         = mpiifx/' makefile.include && 
    sed -i 's/MKLROOT    ?= \/path\/to\/your\/mkl\/installation/MKLROOT    ?=  \/opt\/intel\/oneapi\/mkl\/2024.2/' makefile.include && 
    sed -i 's/INCS        =-I$(MKLROOT)\/include\/fftw/INCS        =-I$(MKLROOT)\/include\/fftw   -I\/opt\/intel\/oneapi\/mpi\/2021.13\/include/' makefile.include && 
    sed -i 's/FCL        += -qmkl=sequential/FCL        += -qmkl=sequential    -xCORE-Avx2/' makefile.include; 
fi

# 编译
source /opt/intel/oneapi/setvars.sh --force
make

# 安装vaspkit
cd $dir_src
tar -xzvf vaspkit.1.3.5.linux.x64.tar.gz
cd vaspkit.1.3.5

bash setup.sh


echo "export PATH=\$PATH:$(echo $dir_src)/vasp.6.4.2/bin" >> ~/.bashrc
