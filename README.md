# GoMake

使用Lua编写的简单的维护特定组织格式的Go语言项目的脚本。

## 使用

### 环境要求

- UNIX/Linux操作系统
- Lua/Luajit
- git
- GNU make

### 安装

GoMake可以放在任意可读位置，或放在项目自身目录中。为方便使用，可以在/usr/bin或/usr/local/bin等系统PATH中创建指向gomake.lua的连接，并给予gomake.lua可执行权限。

### 帮助

执行gomake.lua help

输出当前支持的子命令信息。如果终端完整支持VT100或其它颜色模式，输出内容为彩色的。

### 格式

```bash
gomake <命令> [目录]
```

### 命令

- init : 创建一个项目。
- vendor : 扫描并获取项目中使用的第三方包
- makefile : 生成Makefile
- dockerfile : 生成Dockerfile
- help : 打印帮助信息

#### init

```bash
gomake init new-project
```

在new-project目录中创建项目。init会创建对应目录，并在其中创建src子目录，创建.gitignore文件，并执行git init

#### vendor

```bash
gomake vendor new-project
```

扫描new-project目录中/src子目录下的.go文件，分析import的包含域名的三方包，并尝试拉取，如果三方包已经存在于/src/vendor中，会尝试执行git pull获取更新的版本。

vendor支持递归，即同时会拉取vendor中再次引用的包，与go get的行为类似。

vendor替换了一些在中国大陆无法直接访问的地址，比如官方的x包，转而使用github镜像。

如省略目标目录，将使用当前目录。

#### makefile

```bash
gomake makefile new-project
```

扫描new-project中/src下（排除vendor）的main包main函数，并尝试生成目标二进制名，然后生成相应的Makefile。

makefile支持项目中多个二进制目标，即多个main。

Makefile中包含fmt（尝试调用gofmt进行代码格式检查）、build、clean、install（复制二进制文件到/usr/bin）、uninstall，可以直接使用gnu make工具。

如省略目标目录，将使用当前目录。

#### dockerfile

```bash
gomake dockerfile new-project
```

dockerfile实现不完整。
