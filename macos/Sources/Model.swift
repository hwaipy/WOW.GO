import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

let sampleScript = """
{
  "name": "钓鱼 · 10 次",
  "steps": [
    { "action": "repeat", "count": 10, "steps": [
      { "action": "fish" },
      { "action": "wait", "seconds": 2 }
    ] }
  ]
}
"""
let testScript = """
{
  "name": "后台按键测试",
  "steps": [
    { "action": "key", "key": "m" },
    { "action": "wait", "seconds": 1 },
    { "action": "capture" },
    { "action": "key", "key": "m" }
  ]
}
"""
@MainActor final class GoModel: ObservableObject {
    @Published var tab="脚本"
    @Published var drag:CGPoint?
    @Published var image:NSImage?
    @Published var connected=false
    @Published var connecting=false
    @Published var running=false
    @Published var preview=true
    @Published var dryRun=true
    @Published var status="准备就绪"
    @Published var connection="尚未连接游戏"
    @Published var script=sampleScript
    @Published var settings=FishSettings()
    @Published var logs:[String]=[]
    @Published var target:CGPoint?
    @Published var pickMode="识别区域"
    @Published var phase="等待运行"
    @Published var motion=0.0
    @Published var splash=0.0
    @Published var casts=0
    @Published var bites=0
    @Published var timeouts=0
    @Published var lastFrame="—"
    @Published var lastPoint:CGPoint?
    @Published var simulated=false
    var io:GameIO
    var task:Task<Void,Never>?
    var previewTask:Task<Void,Never>?
    var lastCG:CGImage?
    let home:URL
    var frozenSettings=FishSettings()
    var runDry=true
    var traceDir:URL?
    init(io:GameIO? = nil) {
        self.io=io ?? GameIO()
        home=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("WowGo")
        try? FileManager.default.createDirectory(at:home,withIntermediateDirectories:true)
        if let d=try? Data(contentsOf:home.appendingPathComponent("settings.json")), let s=try? JSONDecoder().decode(FishSettings.self,from:d) {settings=s}
        if let s=try? String(contentsOf:home.appendingPathComponent("script.json"),encoding:.utf8) {script=s}
        log("仅游戏窗口截图 · 仅游戏进程输入 · 切到游戏前台会停止运行")
    }
    func log(_ s:String) {let f=DateFormatter();f.dateFormat="HH:mm:ss";logs.append("\(f.string(from:Date()))  \(s)");if logs.count>300 {logs.removeFirst(logs.count-300)}}
    func save() {
        do {try script.write(to:home.appendingPathComponent("script.json"),atomically:true,encoding:.utf8);try JSONEncoder().encode(settings).write(to:home.appendingPathComponent("settings.json"));log("脚本和识别参数已保存")}
        catch {log("保存失败：\(error.localizedDescription)")}
    }
    func authorize() {
        _ = CGRequestScreenCaptureAccess()
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary)
        log("请在系统设置中允许 WowGo 的屏幕录制与辅助功能权限；授权后重新打开应用")
    }
    func connect() {
        guard !running && !connecting else {return}
        connecting=true
        Task {defer {connecting=false};previewTask?.cancel();await previewTask?.value;do {try await io.connect();simulated=false;connected=true;connection=io.diagnostic;status="已连接";log(connection);try await refresh();startPreview()} catch {connected=false;status=error.localizedDescription;log(status)}}
    }
    func startPreview() {
        previewTask?.cancel()
        previewTask=Task {
            while !Task.isCancelled {
                if preview && !running && connected {
                    do {try await refresh()} catch is CancellationError {break} catch {status=error.localizedDescription;connected=false;log(status);break}
                }
                do {try await Task.sleep(nanoseconds:500_000_000)} catch {break}
            }
        }
    }
    func refresh() async throws {
        let cg=try await io.capture();publish(cg)
    }
    func publish(_ cg:CGImage) {lastCG=cg;image=NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height));lastFrame=Date().formatted(date:.omitted,time:.standard)}
    func validate() {do {let p=try Program.parse(script);status="脚本有效：\(p.name)";log(status)} catch {status=error.localizedDescription;log(status)}}
    func stop() {task?.cancel();status="正在停止…";log("停止请求：释放当前按键/鼠标后终止")}
    func check() throws {try Task.checkCancellation(); if !runDry {_ = try io.checkInput()}}
    func wait(_ seconds:Double) async throws {
        let end=Date().addingTimeInterval(seconds)
        while Date()<end {try check();try await Task.sleep(nanoseconds:UInt64(min(0.1,max(0,end.timeIntervalSinceNow))*1e9))}
        try check()
    }
    func key(_ key:String,mods:[String]=[],seconds:Double=0.08) async throws {
        try check();log("\(runDry ? "[演练] ":"")按键 \(mods.joined(separator:"+"))\(mods.isEmpty ? "":"+")\(key)")
        if !runDry {try await io.key(key,modifiers:mods,duration:seconds)}
    }
    func click(_ p:CGPoint,right:Bool) async throws {
        try check();log(String(format:"%@%@点击 (%.3f, %.3f)",runDry ? "[演练] ":"",right ? "右键":"左键",p.x,p.y))
        if !runDry {try await io.click(p,right:right)}
    }
    func run(persist:Bool = true) {
        guard !running else {return}
        do {
            let program=try Program.parse(script)
            guard keyCodes[settings.castKey.lowercased()] != nil else {throw GoError("钓鱼按键无效")}
            guard connected else {throw GoError("请先连接游戏")}
            runDry=dryRun;frozenSettings=settings
            if !runDry {_ = try io.checkInput()}
            let lease=try RunLease(home.appendingPathComponent("run.lock"))
            if persist {save()};running=true;casts=0;bites=0;timeouts=0;target=nil;simulated=false
            task=Task {
                defer {lease.release();running=false;phase="等待运行";target=nil}
                do {log("开始：\(program.name) · \(runDry ? "演练，不发输入":"真实后台输入")");try await execute(program.steps);status="执行完成";log(status)}
                catch is CancellationError {status="已停止";log(status)}
                catch {status=error.localizedDescription;log("已终止：\(status)")}
            }
        } catch {status=error.localizedDescription;log(status)}
    }
    func execute(_ steps:[Step]) async throws {
        for s in steps {
            try check()
            status="执行：\(s.action)"
            switch s.action {
            case "key":try await key(s.key!,mods:s.modifiers ?? [],seconds:s.seconds ?? 0.08)
            case "click":try await click(CGPoint(x:s.x!,y:s.y!),right:s.button == "right")
            case "wait":try await wait(s.seconds!)
            case "capture":try await refresh();try saveFrame()
            case "repeat":for i in 1...s.count! {log("循环 \(i)/\(s.count!)");try await execute(s.steps!)}
            case "fish":try await fish()
            default:throw GoError("未知指令")
            }
        }
    }
    func saveFrame() throws {
        guard let cg=lastCG else {throw GoError("尚无截图")}
        let folder=home.appendingPathComponent("Captures");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let url=folder.appendingPathComponent("wow-\(Int(Date().timeIntervalSince1970*1000)).png")
        guard let dst=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else {throw GoError("无法创建截图")}
        CGImageDestinationAddImage(dst,cg,nil);guard CGImageDestinationFinalize(dst) else {throw GoError("无法保存截图")};log("截图：\(url.lastPathComponent)")
    }
    func fish() async throws {
        let s=frozenSettings
        casts+=1;target=nil;motion=0;splash=0;phase="抛竿"
        try await key(s.castKey);try await wait(s.settle)
        phase="搜索浮漂"
        var trace=["seconds,motion,splash,texture,x,y"]
        var maxMotion=0.0,maxSplash=0.0
        defer {
            if let dir=traceDir {try? trace.joined(separator:"\n").write(to:dir.appendingPathComponent("trace.csv"),atomically:true,encoding:.utf8)}
            log(String(format:"本轮峰值：变化 %.3f / 水花 %.3f",maxMotion,maxSplash))
        }
        let start=Date();var stable=0;var previous:CGPoint?;var detector=BiteDetector();var lockedAt:Date?
        while Date().timeIntervalSince(start)<s.timeout {
            try check();try await refresh()
            guard let cg=lastCG else {throw GoError("无游戏画面")}
            let pixels=try Pixels(cg)
            if target == nil {
                let candidate:CGPoint?
                if let x=s.manualX,let y=s.manualY {candidate=CGPoint(x:x,y:y)} else {candidate=pixels.candidate(s)}
                if let c=candidate {
                    if let p=previous,hypot(p.x-c.x,p.y-c.y)<0.02 {stable+=1} else {stable=1};previous=c
                    if stable>=3 {target=c;lockedAt=Date();if let dir=traceDir {try? writeJPEG(cg,to:dir.appendingPathComponent("locked.jpg"))};phase="监测咬钩";log(String(format:"锁定浮漂 (%.3f, %.3f)",c.x,c.y))}
                } else {stable=0;previous=nil}
                if Date().timeIntervalSince(start)>8 && target == nil {log("未找到稳定浮漂，请缩小识别区域或手动标定");break}
            }
            if let p=target {
                let hit=detector.feed(pixels.patch(p,radius:s.radius),settings:s)
                motion=detector.motion;splash=detector.splash
                trace.append("\(Date().timeIntervalSince(start)),\(motion),\(splash),\(detector.texture),\(p.x),\(p.y)")
                if motion>maxMotion {maxMotion=motion;if let dir=traceDir {try? writeJPEG(cg,to:dir.appendingPathComponent("max-motion.jpg"))}}
                if splash>maxSplash {maxSplash=splash;if let dir=traceDir {try? writeJPEG(cg,to:dir.appendingPathComponent("max-splash.jpg"))}}
                if hit, let t=lockedAt,Date().timeIntervalSince(t)>1.5 {
                    phase="咬钩 → 收竿";bites+=1;log("检测到连续水花，执行收竿（不代表已获得物品）")
                    try await click(p,right:true);try await wait(1.5);return
                }
            }
            try await wait(0.06)
        }
        timeouts+=1;phase="超时";log("本轮超时，不点击；下一轮重新抛竿")
    }
    func pick(from:CGPoint,to:CGPoint) {
        guard !running else {return}
        let clamp:(CGFloat)->Double={min(0.999,max(0,Double($0)))}
        if pickMode == "识别区域" {
            let r=Region(x:clamp(min(from.x,to.x)),y:clamp(min(from.y,to.y)),w:Double(abs(to.x-from.x)),h:Double(abs(to.y-from.y)))
            if r.w>0.02 && r.h>0.02 {settings.region=r;settings.manualX=nil;settings.manualY=nil;target=nil;log("已更新浮漂搜索区域")}
        } else {
            let p=CGPoint(x:clamp(to.x),y:clamp(to.y));lastPoint=p
            if pickMode == "手动浮漂" {settings.manualX=p.x;settings.manualY=p.y;target=p;log("已设置固定浮漂坐标（每次抛竿位置变化时需重新标定）")}
            else {log(String(format:"坐标：x=%.4f, y=%.4f",p.x,p.y))}
        }
    }
    func importScript() {let p=NSOpenPanel();p.allowedContentTypes=[.json];if p.runModal() == .OK,let u=p.url {do {let s=try String(contentsOf:u,encoding:.utf8);_ = try Program.parse(s);script=s;log("已导入 \(u.lastPathComponent)")} catch {log(error.localizedDescription)}}}
    func exportScript() {let p=NSSavePanel();p.allowedContentTypes=[.json];p.nameFieldStringValue="sequence.json";if p.runModal() == .OK,let u=p.url {do {try script.write(to:u,atomically:true,encoding:.utf8);log("已导出脚本")} catch {log(error.localizedDescription)}}}
    func demo() {
        guard !running else {return}
        previewTask?.cancel();simulated=true;running=true;casts=1;bites=0;timeouts=0;target=nil;status="合成画面闭环演示 · 不发送输入"
        task=Task {
            defer {running=false;phase="等待运行";if connected {startPreview()}}
            var detector=BiteDetector();var s=FishSettings();s.region=Region(x:0.1,y:0.1,w:0.8,h:0.8)
            do {
                for i in 0..<35 {
                    try Task.checkCancellation()
                    let cg=fixture(splash:i>=25);publish(cg)
                    let pixels=try Pixels(cg)
                    target=pixels.candidate(s);phase=i<5 ? "搜索浮漂":"监测咬钩"
                    if let p=target {
                        let hit=detector.feed(pixels.patch(p,radius:s.radius),settings:s);motion=detector.motion;splash=detector.splash
                        if hit {bites=1;phase="识别成功";log("[合成演示] 浮漂定位 → 水花识别 → 计划右键收竿；未发输入");try await Task.sleep(nanoseconds:1_000_000_000);break}
                    }
                    try await Task.sleep(nanoseconds:120_000_000)
                }
                status=bites==1 ? "合成闭环通过":"合成闭环失败"
            } catch {status="演示已停止"}
        }
    }
}
func fixture(splash:Bool) -> CGImage {
    let w=640,h=400
    let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red:0.07,green:0.2,blue:0.28,alpha:1));ctx.fill(CGRect(x:0,y:0,width:w,height:h))
    if splash {ctx.setFillColor(CGColor(gray:0.95,alpha:1));ctx.fillEllipse(in:CGRect(x:308,y:188,width:25,height:25))}
    ctx.setFillColor(CGColor(red:0.9,green:0.06,blue:0.04,alpha:1));ctx.fill(CGRect(x:317,y:197,width:7,height:7))
    return ctx.makeImage()!
}

func writeJPEG(_ image:CGImage,to url:URL) throws {
    guard let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.jpeg.identifier as CFString,1,nil) else {throw GoError("无法保存诊断图")}
    CGImageDestinationAddImage(dest,image,[kCGImageDestinationLossyCompressionQuality:0.8] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {throw GoError("诊断图写入失败")}
}

final class RunLease {
    private var fd:Int32
    init(_ url:URL) throws {
        fd=Darwin.open(url.path,O_CREAT|O_RDWR,S_IRUSR|S_IWUSR)
        guard fd>=0 else {throw GoError("无法建立运行锁")}
        guard flock(fd,LOCK_EX|LOCK_NB)==0 else {Darwin.close(fd);fd = -1;throw GoError("已有另一实例正在运行脚本，请先停止它")}
    }
    func release() {if fd>=0 {flock(fd,LOCK_UN);Darwin.close(fd);fd = -1}}
    deinit {release()}
}
