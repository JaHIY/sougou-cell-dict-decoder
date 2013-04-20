# sougou-cell-dict-decoder

``` bash
$ main.sh -l 化学化工词汇大全【官方推荐】.scel
词库名：化学化工词汇大全【官方推荐】                        
词库类型：化学
描述信息：官方推荐，词库来源于网友上传！
词库示例：奥济酸
 八氯萘
 八氧化三铀
 安全漏斗
 白蛋白 巴西棕榈蜡
```

输出格式为：
```
按空格分割的拼音
中文词组
词频
```
``` bash
$ main.sh 化学化工词汇大全【官方推荐】.scel
a ben da zuo
阿苯哒唑
4134

a bi song zhi
阿比松脂
4135

a ding cheng
吖啶橙
4127
```

可以利用 `awk` 的多行模式将解码输出的内容重新格式化成汝等想要的格式。

例1：将搜狗细胞词库转换成 rime 词库
已知，rime 词库文件的格式为：`中文词组\t以空格分割的拼音组\t词频`。
``` bash
$ ./main.sh ~/Downloads/化学化工词汇大全【官方推荐】.scel | awk 'BEGIN{FS="\n";RS="";OFS="\t";}{print $2,$1,$3;}' 
阿苯哒唑	a ben da zuo	4134
阿比松脂	a bi song zhi	4135
吖啶橙	a ding cheng	4127
```
由于不同平台上的 `awk` 有所差异，有的版本需要将上述命令中的 `\t` 替换成真正的 Tab 键 -> `    `。

例2: 暂时木有～

Tips: 搜狗细胞词库可以在 http://pinyin.sogou.com/dict/ 下载到。
