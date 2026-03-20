//这个框架是github框架上载框架

import { webview } from '@kit.ArkWeb';
import { BusinessError, pasteboard, deviceInfo } from '@kit.BasicServicesKit';
import { window, promptAction } from '@kit.ArkUI';
import { abilityAccessCtrl, common, Permissions, Want } from '@kit.AbilityKit';
import { DownloadConfirmDialog } from '../component/DownloadConfirmDialog'
import { IAbstractDownloadHandler } from '../delegate/IWebDownloadFile'
import { WebDownloadFileHelper } from '../delegate/WebDownloadFileImpl'
import { EmitterUtil } from '../utiles/EmitterUtil'
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { call } from '@kit.TelephonyKit';  // 新增：用于拨打电话


//const url = "https://web.feishu.cn"; //飞书
//const url = "https://music.163.com";  //网易云音乐
//const url = "https://www.bilibili.com";  //B站
//const url = "https://chat.deepseek.com";  //deepseek
//const url = "https://www.iconfont.cn";  //阿里巴巴矢量图库
const url = "https://chat.qwen.ai";
//const url = $rawfile('index.html')
//const url = "https://oc.sjtu.edu.cn";
//const url = "https://shuiyuan.sjtu.edu.cn";

// UA设置（修改为更精准的移动端标识）
const forceMobileUA = false;  // 强制手机UA开关设置为true
const mobileUserAgent = "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"; // 增强移动端标识
const pcUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"; // 更新PC UA版本
const titleBlankHeight = 0;  //空白标题栏的高度，如果你的网页最上面一排没有按钮和需要点击的内容，可以设置为0

// 定义菜单类型枚举
enum MenuType {
  IMAGE = "IMAGE",
  LINK = "LINK",
  EDITABLE = "EDITABLE",
  SELECTION = "SELECTION"
}


@Entry
@Component
struct WebComponent {
  @State permissionsGranted: boolean = false;
  needReloadWhenVisible: boolean = false;
  webIsVisible: boolean = false;
  renderReloadMaxForCrashed: number = 5;
  renderReloadCountForCrashed: number = 0;
  renderReloadMaxForOthers: number = 10;
  renderReloadCountForOthers: number = 0;
  controller: webview.WebviewController = new webview.WebviewController();
  @State webDownloadFile: IAbstractDownloadHandler = new WebDownloadFileHelper()
  downloadWebLoading: CustomDialogController = new CustomDialogController({
    builder: DownloadConfirmDialog(),
    customStyle: true,
    alignment: DialogAlignment.Bottom,
    autoCancel: false,
    isModal: false,
    openAnimation: {
      duration: 200,
      curve: Curve.Ease,
      delay: 0,
      playMode: PlayMode.Normal,
    }
  })
  private result: WebContextMenuResult | undefined = undefined;
  @State linkUrl: string = '';
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State window_width: number = 0;
  @State window_height: number = 0;
  @State menu_height: number = 0;
  @State showMenu: boolean = false;
  @State currentMenuType: MenuType = MenuType.IMAGE;
  @State imageUrl: string = '';
  uiContext: UIContext = this.getUIContext();
  context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  // 从网络URL加载并保存图片到相册
  async saveNetworkImageToGallery(url: string): Promise<boolean> {
    if (!url) {
      console.error('图片URL为空');
      return false;
    }

    try {
      // 1. 通过HTTP请求下载图片
      const httpInstance = http.createHttp();
      const response = await httpInstance.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 60000,
        readTimeout: 60000
      });

      if (response.responseCode !== http.ResponseCode.OK) {
        console.error(`HTTP请求失败，状态码: ${response.responseCode}`);
        return false;
      }

      const imageData: ArrayBuffer = response.result as ArrayBuffer;
      if (!imageData || imageData.byteLength === 0) {
        console.error('获取到的图片数据为空');
        return false;
      }

      // 2. 创建图片源并获取PixelMap
      const imageSource: image.ImageSource = image.createImageSource(imageData);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();

      // 3. 打包为JPEG格式
      const imagePackerApi = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 98 };
      const buffer: ArrayBuffer = await imagePackerApi.packToData(pixelMap, packOpts);

      // 4. 保存到相册
      const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.write(file.fd, buffer);
      await fs.close(file.fd);

      // 5. 释放资源
      pixelMap.release();
      httpInstance.destroy();

      return true;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`保存图片失败。Code: ${err.code}, message: ${err.message}`);
      return false;
    }
  }

  // 图片菜单构建器 - 直接包含 SaveButton
  @Builder
  ImageMenuBuilder() {
    Column() {
      // 使用系统安全控件 SaveButton，点击直接保存
      SaveButton()
        .fontSize(14)
        .fontColor('#FFFFFF')           // 深色字体
        .backgroundColor('#000000')     // 浅灰背景
        .width(100)
        .height(45)
        .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
          this.showMenu = false;
          if (result === SaveButtonOnClickResult.SUCCESS) {
            const success = await this.saveNetworkImageToGallery(this.imageUrl);
            if (success) {
              promptAction.showToast({ message: '已保存至相册！' });
            } else {
              promptAction.showToast({ message: '保存失败，请重试' });
            }
          } else {
            promptAction.showToast({ message: '授权失败' });
          }
        })
    }
    .width(100)
    .backgroundColor(Color.Black)
    .borderRadius(8)
    .shadow({
      radius: 10,
      color: '#33000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 链接菜单构建器
  @Builder
  LinkMenuBuilder() {
    Menu() {
      MenuItem({ content: '复制链接' })
        .width(100)
        .height(50)
        .onClick(() => {
          let pasteData = pasteboard.createData('text/plain', this.linkUrl);
          pasteboard.getSystemPasteboard().setData(pasteData, (error) => {
            if (error) {
              return;
            }
          })
          this.showMenu = false;
        })
    }
    .width(100)
    .height(50)
  }

  // 可编辑区域菜单构建器
  @Builder
  EditableMenuBuilder() {
    Menu() {
      MenuItem({ content: '剪切' })
        .width(100)
        .height(50)
        .onClick(() => {
          this.result?.cut();
          this.showMenu = false;
        })
      MenuItem({ content: '复制' })
        .width(100)
        .height(50)
        .onClick(() => {
          this.result?.copy();
          this.showMenu = false;
        })
      MenuItem({ content: '粘贴' })
        .width(100)
        .height(50)
        .onClick(() => {
          this.result?.paste();
          this.showMenu = false;
        })
      MenuItem({ content: '全选' })
        .width(100)
        .height(50)
        .onClick(() => {
          this.result?.selectAll();
          this.showMenu = false;
        })
    }
    .width(100)
    .height(200)
  }

  // 选中文本菜单构建器
  @Builder
  SelectionMenuBuilder() {
    Menu() {
      MenuItem({ content: '复制' })
        .width(100)
        .height(50)
        .onClick(() => {
          this.result?.copy();
          this.showMenu = false;
        })
    }
    .width(100)
    .height(50)
  }

  // 动态菜单构建器
  @Builder
  MenuBuilder() {
    if (this.currentMenuType === MenuType.IMAGE) {
      this.ImageMenuBuilder();
    } else if (this.currentMenuType === MenuType.LINK) {
      this.LinkMenuBuilder();
    } else if (this.currentMenuType === MenuType.EDITABLE) {
      this.EditableMenuBuilder();
    } else if (this.currentMenuType === MenuType.SELECTION) {
      this.SelectionMenuBuilder();
    }
  }

  onBackPress() {
    if (this.controller.accessStep(-1)) {
      this.controller.backward();
      return true
    } else {
      return false
    }
  }

  private toSysSettingPage() {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.startAbility({
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'application_info_entry',
        parameters: {
          pushParams: context.abilityInfo.bundleName
        }
      }).then(() => {
        console.info('跳转到设置页面成功');
      }).catch((err: BusinessError) => {
        console.error(`跳转到设置页面失败: ${err.code}, ${err.message}`);
        promptAction.showToast({ message: '跳转失败，请手动前往设置' });
      });
    } catch (error) {
      console.error('跳转到设置页面异常:', JSON.stringify(error));
      promptAction.showToast({ message: '跳转失败，请手动前往设置' });
    }
  }

  aboutToAppear(): void {
    EmitterUtil.on<number>('affffa', (event) => {
      if (event?.data === 1) {
        this.downloadWebLoading.open()
      } else {
        this.downloadWebLoading.close()
      }
    })
  }

  aboutToDisappear(): void {
    EmitterUtil.off<number>('affffa', (event) => {
    })
    webview.WebCookieManager.saveCookieAsync((error) => {
      if (error) {
        console.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
      }
    })
  }

  private windowStage = AppStorage.get('window') as window.WindowStage;

  build() {
    Column() {
      Web({ src: url, controller: this.controller })
        .layoutWeight(1)
        .hitTestBehavior(HitTestMode.Transparent)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          window.getLastWindow(this.uiContext.getHostContext()).then((data) => {
            const properties = data?.getWindowProperties();
            this.window_width = properties.windowRect.width;
            this.window_height = properties.windowRect.height - titleBlankHeight;
          });
        })
        // ==================== 新增：处理url scheme跳转外部应用 ====================
        .onLoadIntercept((event) => {
          if (event) {
            let requestUrl: string = event.data.getRequestUrl();
            console.info(`拦截到URL: ${requestUrl}`);

            // 处理 mailto: 链接 - 拉起邮件应用
            if (requestUrl.indexOf('mailto:') === 0) {
              let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              let want: Want = {
                action: 'ohos.want.action.sendToData',
                uri: requestUrl
              };
              context.startAbility(want).then((data) => {
                console.info(`拉起邮件应用成功: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`拉起邮件应用失败: ${err.code}, ${err.message}`);
                promptAction.showToast({ message: '拉起邮件应用失败，请检查是否安装邮件应用' });
              });
              return true;  // 拦截该请求，不加载页面
            }

            // 处理 tel:// 链接 - 拉起拨号界面
            if (requestUrl.indexOf('tel://') === 0) {
              let phoneNumber = requestUrl.substring(6);  // 去掉 "tel://" 前缀
              call.makeCall(phoneNumber, (err) => {
                if (!err) {
                  console.info('拉起拨号界面成功');
                } else {
                  console.error(`拉起拨号界面失败: ${JSON.stringify(err)}`);
                  promptAction.showToast({ message: '拉起拨号界面失败' });
                }
              });
              return true;
            }

            // 处理 tel: 链接（有些网页可能使用 tel: 而非 tel://）
            if (requestUrl.indexOf('tel:') === 0 && requestUrl.indexOf('tel://') !== 0) {
              let phoneNumber = requestUrl.substring(4);  // 去掉 "tel:" 前缀
              call.makeCall(phoneNumber, (err) => {
                if (!err) {
                  console.info('拉起拨号界面成功');
                } else {
                  console.error(`拉起拨号界面失败: ${JSON.stringify(err)}`);
                  promptAction.showToast({ message: '拉起拨号界面失败' });
                }
              });
              return true;
            }

            // 处理 sms: 链接 - 拉起短信应用
            if (requestUrl.indexOf('sms:') === 0) {
              let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              let want: Want = {
                bundleName: 'com.ohos.mms',
                action: 'ohos.want.action.viewData',
                uri: requestUrl
              };
              context.startAbility(want).then((data) => {
                console.info(`拉起短信应用成功: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`拉起短信应用失败: ${err.code}, ${err.message}`);
                promptAction.showToast({ message: '拉起短信应用失败' });
              });
              return true;
            }

            // 处理 jaccount: 链接 - 拉起交我办APP
            if (requestUrl.indexOf('jaccount:') === 0) {
              let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              let want: Want = {
                bundleName: 'edu.sjtu.jwb',
                action: 'ohos.want.action.viewData',
                uri: requestUrl
              };
              context.startAbility(want).then((data) => {
                console.info(`拉起交我办APP成功: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`拉起交我办APP失败: ${err.code}, ${err.message}`);
                promptAction.showToast({ message: '未安装交我办APP，请先安装' });
              });
              return true;
            }

            // 处理 weixin: 链接 - 拉起微信打开
            if (requestUrl.indexOf('weixin://') === 0) {
              let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              let want: Want = {
                bundleName: 'com.tencent.wechat',
                action: 'ohos.want.action.viewData',
                uri: requestUrl
              };
              context.startAbility(want).then((data) => {
                console.info(`拉起微信成功: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`拉起微信失败: ${err.code}, ${err.message}`);
                promptAction.showToast({ message: '未安装微信，请先安装' });
              });
              return true;
            }

            // 处理 xhsdiscover: 链接 - 拉起小红书打开
            if (requestUrl.indexOf('xhsdiscover://') === 0) {
              let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              let want: Want = {
                bundleName: 'com.xingin.xhs_hos',
                action: 'ohos.want.action.viewData',
                uri: requestUrl
              };
              context.startAbility(want).then((data) => {
                console.info(`拉起小红书成功: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`拉起小红书失败: ${err.code}, ${err.message}`);
                promptAction.showToast({ message: '未安装小红书，请先安装' });
              });
              return true;
            }
          }
          return false;  // 不拦截其他请求，正常加载
        })
        // ====================处理url scheme跳转外部应用 处理结束 ====================
        .onContextMenuShow((event) => {
          if (event) {
            this.result = event.result;
            this.linkUrl = event.param.getLinkUrl();
            const srcUrl = event.param.getSourceUrl();
            if (srcUrl) {
              this.imageUrl = srcUrl;
            }
            if (event.param.isEditable() == false) {
              if (event.param.getMediaType() === 1) {
                this.currentMenuType = MenuType.IMAGE;
                this.menu_height = 100;
              } else {
                if (event.param.getSelectionText() != "") {
                  this.currentMenuType = MenuType.SELECTION;
                  this.menu_height = 50;
                } else {
                  if (event.param.getUnfilteredLinkUrl() != "") {
                    this.currentMenuType = MenuType.LINK;
                    this.menu_height = 50;
                  } else {
                    return false;
                  }
                }
              }
            } else {
              this.currentMenuType = MenuType.EDITABLE;
              this.menu_height = 200;
            }
          }
          this.offsetX = this.uiContext.px2vp(event.param.x() - this.window_width / 2) + 50;
          this.offsetY = this.uiContext.px2vp(event.param.y() - this.window_height / 2) + this.menu_height / 2;
          this.showMenu = true;
          return true;
        })
        .bindPopup(this.showMenu,
          {
            builder: this.MenuBuilder(),
            enableArrow: false,
            placement: Placement.RightBottom,
            offset: { x: this.offsetX, y: this.offsetY },
            mask: false,
            onStateChange: (e) => {
              if (!e.isVisible) {
                this.showMenu = false;
                this.result!.closeContextMenu();
              }
            }
          })
        .onControllerAttached(() => {
          const permissions: Array<Permissions> = ['ohos.permission.CAMERA', 'ohos.permission.MICROPHONE'];
          try {
            abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.getUIContext().getHostContext() as common.UIAbilityContext, permissions).then((data) => {
              console.info('权限申请结果:', JSON.stringify(data));
            }).catch((err: BusinessError) => {
              console.error('申请权限失败:', JSON.stringify(err));
            });
          } catch (error) {
            console.error('捕获到申请权限异常:', JSON.stringify(error));
          }

          // 增强型UA设置（检测设备类型和屏幕尺寸）
          window.getLastWindow(this.uiContext.getHostContext()).then((win) => {
            const rect = win.getWindowProperties().windowRect;
            const deviceType = deviceInfo.deviceType;
            const isLandscape = rect.width > rect.height;
            const screenWidth = rect.width;

            // 判断是否为移动设备：phone或wearable
            const isMobileDevice = deviceType === 'phone' || deviceType === 'wearable';

            // 判断是否为小屏设备（竖屏且宽度小于600px）
            const isSmallScreen = !isLandscape && screenWidth < 600;

            // UA设置逻辑：
            // 1. 强制移动模式 → 移动端UA
            // 2. 手机/可穿戴设备 → 移动端UA（无论屏幕方向）
            // 3. 小屏竖屏设备 → 移动端UA
            // 4. 其他情况（平板/2in1横屏或大屏） → PC端UA
            if (forceMobileUA || isMobileDevice || isSmallScreen) {
              this.controller.setCustomUserAgent(mobileUserAgent + " QwenApp/1.0");
              console.info('使用移动端UA');
            } else {
              this.controller.setCustomUserAgent(pcUserAgent);
              console.info('使用PC端UA');
            }

            // 强制刷新页面应用新UA
            setTimeout(() => {
              this.controller.refresh();
            }, 300);
          });
          this.webDownloadFile.setDownloadDelegate(this.controller)
        })
        .onPageEnd(() => {
          this.controller.setNetworkAvailable(true);
        })
        .onPermissionRequest((event) => {
          if (event) {
            console.info('收到权限请求:', event.request.getOrigin());
            const resources = event.request.getAccessibleResource();
            console.info('请求的资源:', JSON.stringify(resources));

            if (this.permissionsGranted) {
              event.request.grant(resources);
              console.info('自动授予权限');
              return;
            }

            promptAction.showDialog({
              title: '麦克风、相机权限',
              message: '为使用语音输入和音视频通话功能，应用将会访问麦克风、相机。您可以选择拒绝，不会影响其他功能使用。\n\n注意：权限授予需要系统设置和此处双重授权。如果您没有授予系统权限，请前往设置授权后重新启动应用',
              buttons: [
                { text: '拒绝', color: '#666666' },
                { text: '前往设置', color: '#0A59F7' },
                { text: '本次允许', color: '#0A59F7' }
              ]
            }).then((data) => {
              if (data.index === 2) {
                event.request.grant(resources);
                this.permissionsGranted = true;
                console.info('已授予权限');
              } else if (data.index === 1) {
                this.toSysSettingPage();
                console.info('跳转到设置页面');
              } else {
                console.info('用户拒绝授权');
              }
            }).catch((err: Error) => {
              console.error('弹窗异常:', err.message);
            });
          }
        })
        .backgroundColor(Color.Transparent)
        .darkMode(WebDarkMode.Auto)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .imageAccess(true)
        .fileAccess(true)
        .javaScriptAccess(true)
        .databaseAccess(true)
        .copyOptions(CopyOptions.LocalDevice)
        .mixedMode(MixedMode.All)
        .horizontalScrollBarAccess(false)
        .verticalScrollBarAccess(false)
        .onVisibleAreaChange([0, 1.0], (isVisible: boolean) => {
          this.webIsVisible = isVisible;
          if (isVisible && this.needReloadWhenVisible) {
            this.needReloadWhenVisible = false;
            this.controller.loadUrl(url);
          }
        })
        .onRenderExited((event) => {
          if (!event) {
            return;
          }
          if (event.renderExitReason == RenderExitReason.ProcessCrashed) {
            if (this.renderReloadCountForCrashed >= this.renderReloadMaxForCrashed) {
              return;
            }
            console.log('renderReloadCountForCrashed: ' + this.renderReloadCountForCrashed);
            this.renderReloadCountForCrashed++;
          } else {
            if (this.renderReloadCountForOthers >= this.renderReloadMaxForOthers) {
              return;
            }
            console.log('renderReloadCountForOthers: ' + this.renderReloadCountForOthers);
            this.renderReloadCountForOthers++;
          }
          if (this.webIsVisible) {
            this.controller.loadUrl(url);
            return;
          }
          this.needReloadWhenVisible = true;
        })
        .onErrorReceive((event) => {
          console.error('onErrorReceive event:', JSON.stringify(event));
        })
    }
    .width('100%')
    .height('100%')
  }
}