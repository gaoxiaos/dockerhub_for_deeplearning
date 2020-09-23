# dockerhub_for_deeplearning

## 使用说明<br />
这里维护的镜像根据各官方版本（如 torch、tensorflow官方仓库）以hook形式自动更新维护<br />并直接支持作为天池大赛docker提交的基础镜像使用<br />
## <br />自动构建在原官方镜像上做的更改：
<br />1.添加了curl等天池平台要求的软件<br />2.修改用户权限为root.方便算法同学修改环境<br />3.替换镜像源为阿里云镜像源，安装速度<br />4.更新pip镜像源为阿里云镜像源<br />
<br />自行修改pytorch dockerfile 并构建基础镜像：<br />1.git clone [https://github.com/gaoxiaos/dockerhub_for_deeplearning.git](https://github.com/gaoxiaos/dockerhub_for_deeplearning.git)<br />2.cd [dockerhub_for_deeplearning](https://github.com/gaoxiaos/dockerhub_for_deeplearning.git)/pytorch<br />3.vim Dockerfile<br />4.docker build -t yourimage:0.1 .<br />
## <br />自动构建镜像链接（版本号默认为latest）：
<br />命名方式参见“天池镜像仓库”，传送门：[https://tianchi.aliyun.com/forum/postDetail?postId=67720](https://tianchi.aliyun.com/forum/postDetail?postId=67720)<br />如registry.cn-shanghai.aliyuncs.com/tcc-public/实物名：实物版本号-cuda版本号-python版本号<br />
## <br />简单的使用方法：<br />
`FROM registry.cn-shanghai.aliyuncs.com/tcc-public/python:3`<br />`##安装依赖包,pip包请在requirements.txt添加`<br />`RUN pip install --no-cache-dir -r requirements.txt -i `[`https://pypi.tuna.tsinghua.edu.cn/simple`](https://pypi.tuna.tsinghua.edu.cn/simple)<br />`## 把当前文件夹里的文件构建到镜像的根目录下,并设置为默认工作目录`<br />`ADD . /`<br />`WORKDIR /`<br />`## 镜像启动后统一执行 sh run.sh`<br />`CMD ["sh", "run.sh"]`<br />
## <br />链接：<br />
pytorch git源:[https://github.com/pytorch/pytorch/blob/master/docker/pytorch/Dockerfile](https://github.com/pytorch/pytorch/blob/master/docker/pytorch/Dockerfile)<br />tensorflow git源：[https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/devel-gpu.Dockerfile](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/devel-gpu.Dockerfile)<br />tensorflow jupyter git源：[https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/gpu-jupyter.Dockerfile](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/gpu-jupyter.Dockerfile)<br />caffe2 git源：[https://github.com/pytorch/pytorch/blob/master/docker/caffe2/ubuntu-16.04-gpu-tutorial/Dockerfile](https://github.com/pytorch/pytorch/blob/master/docker/caffe2/ubuntu-16.04-gpu-tutorial/Dockerfile)<br />

