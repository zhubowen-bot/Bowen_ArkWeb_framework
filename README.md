## Bowen_ArkWeb框架 正式版v1.0

**这是一个基于ArkWeb深度开发的html嵌入式鸿蒙软件框架，即使你没有学过编程，你也可以零基础零编程构建自己的鸿蒙应用**  

目前，Bowen_ArkWeb框架已经实现的功能有：  

* 网页web/本地web自由嵌入；    
* 底部安全区（小横条附近）沉浸式效果适配；    
* 鸿蒙安全访问文件控件；鸿蒙安全访问相机控件；鸿蒙安全保存控件； 
* 扩展右键菜单，包括图片右键下载菜单、复制链接等
* 下载监听和下载框适配，支持安全保存文件
* 支持mailto等协议，支持跳转系统邮箱、电话；支持跳转豆包等部分APP；支持跳转应用系统权限页；   
* 系统相机和麦克风权限申请，网页获取系统相机和麦克风权限，采用二次权限申请以保护安全；  
* 获取系统网络状态，并反馈给网页；    
* 深色、浅色模式获取，并反馈给网页；   
* 依据设备型号自动精确向网页申请与设备匹配的UA。
* 内置demo链接（网页和rawfile的本地引用示例）和许多软件图标
* 内置demo权限共5个，设置了ohos.permission.CAMERA（允许应用使用相机），ohos.permission.GET_NETWORK_INFO（允许应用获取数据网络信息），ohos.permission.INTERNET（允许使用Internet网络），ohos.permission.MICROPHONE（允许应用使用麦克风），ohos.permission.PRINT（允许应用获取打印框架的能力）

## 部署项目：

* 使用DevEco studio导入项目，选择打开文件夹整体导入
* entry/src/main/ets/pages/Index.ets: 顶部代码修改指向的链接
* 其中如果是本地化html可把链接改为引用，如$rawfile('index.html')，html文件请存储在rawfile文件夹中
* app.json5处修改包名bundlename，修改版本号versionname和versioncode
* module.json5修改权限使用，修改应用启动页图标，"startWindowIcon": "$media:name"，其中name为resources/base/media文件夹的png图标文件名
* entry\src\main\resources\base\element\string.json处修改软件名EntryAbility_label，也可修改权限说明的描述
* layered_image.json修改软件图标，存储位置依然在media文件夹
* AppScope\resources\base\element\string.json处修改软件名app_name，注意两处都要修改
* 左上角横条-项目结构-signing configs处勾选自动签名，生成临时调试签名
* 右上角靶标图标可切换build mode为debug和release，锤子图标可编译hap和app，存放于build或entry\build里面的相关文件夹
* devices选择处可选择打开了开发者选项和有线调试的USB调试设备，也可在设备管理器内选择镜像下载启动
* 右上角甲虫或开始符号点击构建或运行

**没学过编程的零基础小白可以这样开发鸿蒙应用：**  
使用AI生成html文件，保存到上方rawfile文件夹，并按上述步骤部署

## 网页元素避让安全区适配

* Web组件启用沉浸式效果时，渲染内容可能与非安全区域重叠，影响用户的阅读和交互。非安全区域包括顶部状态栏、屏幕挖孔区和底部导航条。在沉浸式效果下，网页的标题栏被屏幕挖孔区遮挡，底部的Tab区域与导航条发生重叠。

* 网页开发者可利用env(safe-area-inset-*)定义CSS样式，确保文字、图片和交互组件避让非安全区域。在以下示例中，通过env(safe-area-inset-*)更新了index.html的CSS样式，使网页主要内容避让非安全区域：

* `.title-bar {`
  
      align-items: center;
      justify-content: center;
      top: 0;
      height: 40px;
      padding-top: env(safe-area-inset-top); /* 设置padding-top避让上方非安全区域 */
  
  `}
  .content {`
  
      margin: 8px;
      padding-top: calc(env(safe-area-inset-top) + 40px); /* 同步title-bar增加padding-top高度 */
  
  `}
  .tabs {`
  
      justify-content: space-around;
      bottom: 0;
      height: calc(env(safe-area-inset-bottom) + 40px); /* 增加tab区域高度以避让下方非安全区域 */
  
  `}`

* 具体内容见开发文档：[文档中心](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-safe-area-insets)

## 关于不支持深色模式的web页面顶部状态栏适配

目前顶部状态栏安全区背景延伸适配的工作尚未完成。如果你的web不支持深色模式，在开启深色模式状态下顶部状态栏会呈现黑色，影响视觉观感。这时，你只需要在index.ets文件的最后几行代码：

`.width('100%')`

`.height('100%')`

后添加一行：

`.background('#F0F4F8')`

即可

## 致谢

<<<<<<< Updated upstream

* B站UP主[零炻] -开源仓库 https://github.com/littlestone0806/WebApp-ohos
* 本项目基于这份初始代码深度优化开发而成
