# git指南

by zhangao

### gitlab是基于git的在线仓库版本管理

#### 1. 创建新账号，对远程仓库中已有的项目进行开发：

1. 本地创建git仓库: git init
2. 配置远程仓库地址： git remote add origin http://192.168.150.188/dev/reli.git
3. 将项目分支拉取到本地： git pull origin develop:origin/develop （develop是远程仓库中需要开发的分支，冒号后的origin/develop是在本地创建的新分支的名字）
4. 对拉取到本地的分支进行开发，开发后将代码提交到本地仓库分支：git add . （添加所有文件到暂存区）； git commit -m“ ”（提交到本地仓库）
5. 将修改后的代码push到远程仓库对应分支：git push origin origin/develop:develop
6. **开发中每次修改时**，要先备份好自己修改的文件，备份好后：先pull （确保别的文件不会被干掉），然后在拉取到本地的远程branch的基础上加上修改，再add、commit、push



原始信息：

使用时需要本地和远程仓库结合起来使用。

首先将代码拿到之后，在本地创建git仓库

在仓库路径下使用：git init

将项目的远程仓库地址配置好： git remote add origin http://192.168.150.188/dev/reli.git

代码修改完毕之后，使用：git add . （添加所有文件到暂存区）

之后： git commit -m“ ”（提交到本地仓库）

本地仓库提交之后：git push origin <本地分支名>:<远程分支名> （推送到远程仓库）

对于本项目： git push origin master:develop

但是这时可能会遇到报错：![image-20240625161802454](C:\Users\lenovo\AppData\Roaming\Typora\typora-user-images\image-20240625161802454.png)

这是因为git不支持http协议，只支持https协议。

解决方式：

git remote set-url origin https://192.168.150.188/dev/reli.git

（改变远程仓库的url）

需要从远程仓库拉新代码时：git pull origin <远程分支名>:<本地分支名>