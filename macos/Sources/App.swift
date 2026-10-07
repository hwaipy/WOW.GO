import SwiftUI
import AppKit

struct Panel<Content:View>:View {
    var title:String
    @ViewBuilder var content:Content
    var body:some View {VStack(alignment:.leading,spacing:12) {Text(title).font(.system(size:12,weight:.semibold)).foregroundStyle(.secondary);content}.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius:12))}
}
struct ContentView:View {
    @ObservedObject var m:GoModel
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:14) {
                Image(systemName:"fish.fill").font(.system(size:26)).foregroundStyle(.cyan)
                VStack(alignment:.leading,spacing:3) {Text("WOW.GO").font(.system(size:20,weight:.bold,design:.rounded));Text("WINDOW CONTROL / macOS").font(.system(size:9,weight:.medium,design:.monospaced)).foregroundStyle(.secondary)}
                Spacer()
                Circle().fill(m.connected ? Color.green:Color.orange).frame(width:7,height:7)
                Text(m.connected ? "游戏已连接":"等待游戏").font(.system(size:12))
                Button(m.connecting ? "连接中…":"连接",action:m.connect).disabled(m.running || m.connecting)
                Button("授权",action:m.authorize).disabled(m.running)
                Divider().frame(height:24)
                Toggle("演练模式",isOn:$m.dryRun).toggleStyle(.switch).disabled(m.running).help("演练模式捕获真实游戏画面，但不发送按键或点击；识别演示使用合成画面")
                Button(action:{m.run()}) {Label("运行",systemImage:"play.fill")}.tint(.cyan).buttonStyle(.borderedProminent).disabled(m.running || !m.connected)
                Button(action:m.stop) {Label("停止",systemImage:"stop.fill")}.tint(.red).disabled(!m.running).keyboardShortcut(".",modifiers:.command)
            }.padding(.horizontal,22).padding(.vertical,18)
            Divider()
            HSplitView {
                VStack(alignment:.leading,spacing:14) {
                    Panel(title:"任务") {
                        Text(m.phase).font(.system(size:20,weight:.semibold))
                        Text(m.connection).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack {stat("抛竿",m.casts);stat("咬钩",m.bites);stat("超时",m.timeouts)}
                    }
                    Panel(title:"快捷操作") {
                        Button("载入钓鱼脚本") {m.script=sampleScript}.disabled(m.running)
                        Button("载入按键测试") {m.script=testScript}.disabled(m.running)
                        Button("合成识别演示",action:m.demo).disabled(m.running)
                        Button("保存参数和脚本",action:m.save)
                        Button("打开截图目录") {let u=m.home.appendingPathComponent("Captures");try? FileManager.default.createDirectory(at:u,withIntermediateDirectories:true);NSWorkspace.shared.open(u)}
                    }
                    Spacer()
                    VStack(alignment:.leading,spacing:8) {
                        Label("游戏专用窗口捕获",systemImage:"rectangle.dashed")
                        Label("进程定向输入",systemImage:"scope")
                        Label("前台游戏自动停止",systemImage:"pause.circle")
                    }.font(.system(size:11)).foregroundStyle(.secondary)
                    Text("不会调用全局鼠标移动或前台激活。实际点击是否生效需在当前客户端验证。").font(.system(size:10)).foregroundStyle(.secondary)
                }.padding(16).frame(minWidth:190,idealWidth:215,maxWidth:240)
                VStack(spacing:12) {
                    HStack {Text("游戏画面").font(.headline);if m.simulated {Text("合成演示").foregroundStyle(.orange)};Spacer();Text(m.lastFrame).font(.caption).foregroundStyle(.secondary);Toggle("预览",isOn:$m.preview).toggleStyle(.switch).controlSize(.small)}
                    Preview(m:m).frame(minHeight:220,idealHeight:360)
                    HStack {
                        Picker("标定",selection:$m.pickMode) {Text("框选区域").tag("识别区域");Text("点选浮漂").tag("手动浮漂");Text("拾取坐标").tag("拾取坐标")}.pickerStyle(.segmented).frame(maxWidth:370).disabled(m.running)
                        Spacer()
                        Button("自动定位") {m.settings.manualX=nil;m.settings.manualY=nil;m.target=nil}.disabled(m.running)
                    }
                    HStack {Text("拖动预览框选水面；点选浮漂使用固定位置。").font(.caption).foregroundStyle(.secondary);Spacer();if let p=m.lastPoint {Text(String(format:"x %.3f · y %.3f",p.x,p.y)).font(.system(size:10,design:.monospaced))}}
                    Picker("内容",selection:$m.tab) {Text("控制脚本").tag("脚本");Text("运行日志").tag("日志")}.pickerStyle(.segmented)
                    if m.tab == "脚本" {
                        TextEditor(text:$m.script).font(.system(size:12,design:.monospaced)).scrollContentBackground(.hidden).padding(8).background(Color.black.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius:8)).disabled(m.running).frame(minHeight:160)
                        HStack {Button("校验",action:m.validate);Button("导入",action:m.importScript).disabled(m.running);Button("导出",action:m.exportScript);Spacer();Text("JSON · key / click / wait / repeat / capture / fish").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)}
                    } else {
                        ScrollViewReader {reader in ScrollView {LazyVStack(alignment:.leading,spacing:5) {ForEach(Array(m.logs.enumerated()),id:\.offset) {i,line in Text(line).font(.system(size:11,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).id(i)}}.padding(10)}.background(Color.black.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius:8)).onChange(of:m.logs.count) { if let last=m.logs.indices.last {reader.scrollTo(last,anchor:.bottom)}}}.frame(minHeight:190)
                    }
                }.padding(18).frame(minWidth:520,maxWidth:.infinity)
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        Panel(title:"钓鱼识别") {
                            HStack {Text("抛竿按键");Spacer();TextField("1",text:$m.settings.castKey).frame(width:65).textFieldStyle(.roundedBorder)}
                            parameter("稳定等待",value:$m.settings.settle,range:1...5,suffix:"s")
                            parameter("每轮超时",value:$m.settings.timeout,range:10...45,suffix:"s")
                            Divider()
                            parameter("红色比例",value:$m.settings.redRatio,range:1.1...4,suffix:"×")
                            parameter("红色亮度下限",value:$m.settings.minRed,range:40...220,suffix:"")
                            parameter("水花增量阈值",value:$m.settings.splashThreshold,range:0.01...0.5,suffix:"")
                            parameter("变化比例阈值",value:$m.settings.motionThreshold,range:0.02...0.5,suffix:"")
                            parameter("检测半径",value:$m.settings.radius,range:0.01...0.08,suffix:"")
                        }.disabled(m.running)
                        Panel(title:"实时检测") {
                            meter("局部变化",m.motion,.cyan)
                            meter("水花增量",m.splash,.orange)
                            Text(m.settings.manualX == nil ? "浮漂：自动红色连通区域":"浮漂：手动固定位置").font(.caption)
                            Text(String(format:"ROI %.2f / %.2f / %.2f / %.2f",m.settings.region.x,m.settings.region.y,m.settings.region.w,m.settings.region.h)).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
                        }
                        Text("先框选水面，排除角色、动作条和红色 UI。检测到连续两帧水花增量后右键收竿；超时跳过。运行时参数固定，停止后再修改。").font(.caption).foregroundStyle(.secondary)
                    }.padding(16)
                }.frame(minWidth:245,idealWidth:265,maxWidth:290)
            }
            Divider()
            HStack {Circle().fill(m.running ? Color.cyan:Color.gray).frame(width:6,height:6);Text(m.status).lineLimit(2);Spacer();Text(m.running ? "RUNNING":"IDLE").font(.system(size:10,design:.monospaced))}.font(.system(size:11)).padding(.horizontal,20).padding(.vertical,10).background(Color.black.opacity(0.15))
        }.background(Color(red:0.055,green:0.075,blue:0.10)).preferredColorScheme(.dark).frame(minWidth:1080,minHeight:740)
    }
    func stat(_ label:String,_ n:Int)->some View {VStack(alignment:.leading,spacing:4) {Text("\(n)").font(.system(size:23,weight:.medium,design:.rounded));Text(label).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)}
    func parameter(_ label:String,value:Binding<Double>,range:ClosedRange<Double>,suffix:String)->some View {VStack(spacing:4) {HStack {Text(label);Spacer();Text(String(format:range.upperBound>5 ? "%.0f%@":"%.2f%@",value.wrappedValue,suffix)).foregroundStyle(.secondary)}.font(.system(size:11));Slider(value:value,in:range).controlSize(.small)}}
    func meter(_ label:String,_ n:Double,_ color:Color)->some View {VStack {HStack {Text(label);Spacer();Text(String(format:"%.1f%%",n*100)).monospacedDigit()}.font(.caption);ProgressView(value:min(1,n)).tint(color)}}
}
struct Preview:View {
    @ObservedObject var m:GoModel
    var body:some View {
        GeometryReader {g in
            let aspect=(m.image?.size.width ?? 16)/(m.image?.size.height ?? 10)
            let w=min(g.size.width,g.size.height*aspect),h=w/aspect
            ZStack {
                Color.black.opacity(0.4)
                if let img=m.image {
                    ZStack(alignment:.topLeading) {
                        Image(nsImage:img).resizable().frame(width:w,height:h)
                        let r=m.settings.region
                        Rectangle().stroke(Color.cyan,lineWidth:1.5).background(Color.cyan.opacity(0.035)).frame(width:w*r.w,height:h*r.h).offset(x:w*r.x,y:h*r.y)
                        if let p=m.target {Circle().stroke(Color.orange,lineWidth:2).frame(width:max(20,w*m.settings.radius*2),height:max(20,w*m.settings.radius*2)).position(x:p.x*w,y:p.y*h)}
                        if let d=m.drag {Circle().fill(Color.cyan).frame(width:6,height:6).position(d)}
                    }.frame(width:w,height:h).contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged {v in m.drag=v.startLocation}.onEnded {v in
                        m.pick(from:CGPoint(x:v.startLocation.x/w,y:v.startLocation.y/h),to:CGPoint(x:min(w,max(0,v.location.x))/w,y:min(h,max(0,v.location.y))/h));m.drag=nil
                    })
                } else {VStack(spacing:12) {Image(systemName:"rectangle.on.rectangle").font(.system(size:40)).foregroundStyle(.secondary);Text("连接游戏，显示专用窗口画面").foregroundStyle(.secondary);Text("也可先运行「合成识别演示」").font(.caption).foregroundStyle(.secondary)}}
            }.frame(width:g.size.width,height:g.size.height).clipShape(RoundedRectangle(cornerRadius:10))
        }
    }
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow?
    var model:GoModel?
    func applicationDidFinishLaunching(_ notification:Notification) {
        let m=GoModel();model=m
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:1260,height:850),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        w.title="WOW.GO · Background Control";w.contentView=NSHostingView(rootView:ContentView(m:m));w.center();w.setFrameAutosaveName("WowGoMain");w.makeKeyAndOrderFront(nil);window=w
        let menu=NSMenu();let app=NSMenuItem();menu.addItem(app);let submenu=NSMenu();submenu.addItem(withTitle:"退出 WOW.GO",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");app.submenu=submenu
        let edit=NSMenuItem();edit.title="编辑";let em=NSMenu(title:"编辑");em.addItem(withTitle:"撤销",action:Selector(("undo:")),keyEquivalent:"z");em.addItem(withTitle:"剪切",action:#selector(NSText.cut(_:)),keyEquivalent:"x");em.addItem(withTitle:"复制",action:#selector(NSText.copy(_:)),keyEquivalent:"c");em.addItem(withTitle:"粘贴",action:#selector(NSText.paste(_:)),keyEquivalent:"v");em.addItem(withTitle:"全选",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a");edit.submenu=em;menu.addItem(edit);NSApplication.shared.mainMenu=menu
        if CommandLine.arguments.contains("--demo") {m.demo()}
        if CommandLine.arguments.contains("--connect") {m.connect()}
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        guard let m=model,m.running else {return .terminateNow}
        m.stop()
        Task {await m.task?.value;NSApplication.shared.reply(toApplicationShouldTerminate:true)}
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
@main struct Launcher {
    @MainActor static func main() {
        let app=NSApplication.shared
        if CommandLine.arguments.contains("--self-test") {do {try selfTest();exit(0)} catch {print("FAIL: \(error)");exit(1)}}
        if CommandLine.arguments.contains("--integration-test") {
            Task {do {try await integrationTest();exit(0)} catch {print("FAIL: \(error)");exit(1)}}
            app.run();return
        }
        if let index=CommandLine.arguments.firstIndex(of:"--run-script"),index+1<CommandLine.arguments.count {
            Task {do {
                let m=GoModel();m.script=try String(contentsOfFile:CommandLine.arguments[index+1],encoding:.utf8)
                _ = try Program.parse(m.script)
                try await m.io.connect();m.connected=true;m.dryRun = !CommandLine.arguments.contains("--real")
                if let ti=CommandLine.arguments.firstIndex(of:"--trace-dir"),ti+1<CommandLine.arguments.count {
                    m.traceDir=URL(fileURLWithPath:CommandLine.arguments[ti+1]);try FileManager.default.createDirectory(at:m.traceDir!,withIntermediateDirectories:true)
                }
                m.run(persist:false);await m.task?.value
                for line in m.logs {print(line)}
                if let stream=m.io.stream {try? await stream.stopCapture()}
                exit(m.status == "执行完成" ? 0:1)
            } catch {print("RUN FAILED: \(error)");exit(1)}}
            app.run();return
        }
        if CommandLine.arguments.contains("--probe") {
            Task {do {
                let io=GameIO();try await io.connect();print(io.diagnostic)
                for i in 0..<12 {
                    let frame=try await io.capture();let px=try Pixels(frame);let p=px.candidate(FishSettings())
                    print("FRAME \(i) \(frame.width)x\(frame.height) candidate=\(String(describing:p))")
                }
                if let stream=io.stream {try await stream.stopCapture()};print("PROBE PASSED");exit(0)
            } catch {print("PROBE FAILED: \(error)");exit(1)}}
            app.run();return
        }
        app.setActivationPolicy(.regular)
        let delegate=AppDelegate();app.delegate=delegate;app.run()
    }
}
