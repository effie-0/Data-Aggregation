README for centerNode
==
Author/Contact:
[@matinjugou]("https://github.com/matinjugou") [@zhaosm]("https://github.com/zhaosm"), [@effie-0]("https://github.com/effie-0")

### centerNode节点烧录
1. 将节点连接电脑
2. 在当前目录打开控制台，输入`motelist`判断是否连接成功，并且记录连接的端口号
3. 输入`make telosb`进行编译
4. 输入`sudo -s`使用root权限
5. 进行烧录
`make telosb install,55 bsl,/dev/ttyUSB0`，
其中55表示基站节点的编号(group_id*3+1, group_id=18)，`/dev/ttyUSB0`是通过 `motelist` 得到的端口
6. 现在节点就能够正常的工作了
