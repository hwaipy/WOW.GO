import AppKit
import ScreenCaptureKit
import ApplicationServices
import CoreImage
import CoreMedia

struct GoError: LocalizedError { let message: String; init(_ s:String) {message=s}; var errorDescription:String? {message} }
let wowBundle = "com.blizzard.worldofwarcraft"
struct Region: Codable, Equatable {
    var x:Double = 0.06, y:Double = 0.18, w:Double = 0.70, h:Double = 0.48
    func contains(_ p:CGPoint) -> Bool { p.x >= x && p.y >= y && p.x <= x+w && p.y <= y+h }
}
struct FishSettings: Codable {
    var castKey = "1"
    var region = Region()
    var redRatio:Double = 1.6
    var minRed:Double = 90
    var splashThreshold:Double = 0.10
    var motionThreshold:Double = 0.08
    var settle:Double = 2.5
    var timeout:Double = 28
    var radius:Double = 0.025
    var manualX:Double? = nil
    var manualY:Double? = nil
}
struct Step: Codable {
    var action:String
    var key:String?
    var modifiers:[String]?
    var seconds:Double?
    var x:Double?
    var y:Double?
    var button:String?
    var count:Int?
    var steps:[Step]?
}
struct Program: Codable {
    var name:String
    var steps:[Step]
    static func parse(_ text:String) throws -> Program {
        let p = try JSONDecoder().decode(Program.self,from:Data(text.utf8))
        var budget = 0
        func check(_ steps:[Step], _ depth:Int) throws {
            guard depth < 8, !steps.isEmpty, steps.count <= 1000 else {throw GoError("脚本层级或步骤数量超限")}
            for s in steps {
                budget += 1; guard budget <= 2000 else {throw GoError("脚本太大")}
                switch s.action {
                case "key":
                    guard let k = s.key, keyCodes[k.lowercased()] != nil else {throw GoError("未知按键：\(s.key ?? "空")")}
                    if let d = s.seconds, !(0.01...0.5).contains(d) {throw GoError("按键时长须为 0.01–0.5 秒")}
                    guard (s.modifiers ?? []).allSatisfy({["shift","ctrl","alt","cmd"].contains($0)}) else {throw GoError("修饰键支持 shift / ctrl / alt / cmd")}
                case "click":
                    guard let x=s.x, let y=s.y, (0..<1).contains(x), (0..<1).contains(y), ["left","right"].contains(s.button ?? "left") else {throw GoError("点击需要 0–1 的 x/y 和 left/right")}
                case "wait": guard let d=s.seconds, (0...3600).contains(d) else {throw GoError("等待时间须为 0–3600 秒")}
                case "repeat": guard let n=s.count, (1...10000).contains(n), let nested=s.steps else {throw GoError("repeat 需要 count (1–10000) 和 steps")}; try check(nested,depth+1)
                case "capture", "fish": break
                default: throw GoError("未知动作：\(s.action)")
                }
            }
        }
        try check(p.steps,0); return p
    }
}
let keyCodes:[String:UInt16] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,"enter":36,"l":37,"j":38,"k":40,"n":45,"m":46,"tab":48,"space":49,"delete":51,"esc":53,"f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,"f7":98,"f8":100,"f9":101,"f10":109,"f11":103,"f12":111,"left":123,"right":124,"down":125,"up":126]

final class FrameReceiver:NSObject,SCStreamOutput,SCStreamDelegate {
    private let lock=NSLock()
    private let context=CIContext(options:[.cacheIntermediates:false])
    private var frame:CGImage?
    private var stamp=Date.distantPast
    private var failure:Error?
    func stream(_ stream:SCStream,didOutputSampleBuffer buffer:CMSampleBuffer,of type:SCStreamOutputType) {
        guard type == .screen,buffer.isValid,
              let attachments=CMSampleBufferGetSampleAttachmentsArray(buffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              let raw=attachments.first?[.status] as? Int,SCFrameStatus(rawValue:raw) == .complete,
              let pixel=CMSampleBufferGetImageBuffer(buffer) else {return}
        let ci=CIImage(cvPixelBuffer:pixel)
        guard let image=context.createCGImage(ci,from:ci.extent) else {return}
        lock.lock();frame=image;stamp=Date();lock.unlock()
    }
    func stream(_ stream:SCStream,didStopWithError error:Error) {lock.lock();failure=error;lock.unlock()}
    func latest() throws -> (CGImage?,Date) {lock.lock();defer {lock.unlock()};if let error=failure {throw error};return (frame,stamp)}
}
@MainActor class GameIO {
    var app:NSRunningApplication?
    var window:SCWindow?
    var filter:SCContentFilter?
    var diagnostic = "未连接"
    var stream:SCStream?
    var receiver:FrameReceiver?
    var lastDelivered=Date.distantPast
    func connect() async throws {
        guard CGPreflightScreenCaptureAccess() else {throw GoError("需要屏幕录制权限：点击「授权」，在系统设置中允许 WowGo，然后重启应用。")}
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier:wowBundle)
        guard apps.count == 1, let a=apps.first else {throw GoError("请运行一个魔兽世界客户端（当前 \(apps.count) 个）")}
        let content = try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:false)
        let candidates=content.windows.filter {$0.owningApplication?.processID == a.processIdentifier && $0.windowLayer == 0 && $0.frame.width > 200 && $0.frame.height > 200}
        let titled=candidates.filter { !($0.title ?? "").isEmpty }
        let eligible=titled.isEmpty ? candidates : titled
        guard eligible.count == 1, let w=eligible.first else {throw GoError("无法唯一确定游戏主窗口，请关闭额外游戏窗口后重试")}
        if let previous=stream {try? await previous.stopCapture()}
        stream=nil;receiver=nil
        app=a; window=w; filter=SCContentFilter(desktopIndependentWindow:w)
        let c=SCStreamConfiguration()
        c.width=1280;c.height=Int(1280 * filter!.contentRect.height / filter!.contentRect.width)
        c.showsCursor=false;c.ignoreShadowsSingleWindow=true;c.queueDepth=3
        c.minimumFrameInterval=CMTime(value:1,timescale:12)
        let output=FrameReceiver()
        let fresh=SCStream(filter:filter!,configuration:c,delegate:output)
        try fresh.addStreamOutput(output,type:.screen,sampleHandlerQueue:DispatchQueue(label:"com.hwaipy.wowgo.frames",qos:.userInitiated))
        try await fresh.startCapture()
        receiver=output;stream=fresh;lastDelivered=Date.distantPast
        diagnostic="PID \(a.processIdentifier) · 窗口 \(w.windowID) · \(Int(w.frame.width))×\(Int(w.frame.height)) pt"
    }
    func checkIdentity() throws {
        guard let a=app, !a.isTerminated, NSRunningApplication(processIdentifier:a.processIdentifier)?.bundleIdentifier == wowBundle else {throw GoError("游戏已退出，请重新连接")}
    }
    func capture() async throws -> CGImage {
        try checkIdentity()
        guard let receiver=receiver else {throw GoError("未连接窗口")}
        let deadline=Date().addingTimeInterval(3)
        while Date()<deadline {
            try Task.checkCancellation()
            let (image,time)=try receiver.latest()
            if let image=image,time>lastDelivered {lastDelivered=time;return image}
            try await Task.sleep(nanoseconds:30_000_000)
        }
        throw GoError("游戏画面超过 3 秒未更新；请确保游戏未最小化，并开启后台帧率后重连")
    }

    func checkInput() throws -> NSRunningApplication {
        try checkIdentity()
        guard AXIsProcessTrusted() else {throw GoError("需要辅助功能权限：请在系统设置中允许 WowGo")}
        guard let a=app, !a.isActive else {throw GoError("游戏进入前台，已停止输入。切回其他 App 后可重新运行。")}
        return a
    }
    func send(_ down:CGEvent, _ up:CGEvent, duration:Double) async throws {
        try Task.checkCancellation()
        let a=try checkInput()
        down.postToPid(a.processIdentifier)
        // Cancellation must still release the same key/button to the same process.
        do { try await Task.sleep(nanoseconds:UInt64(duration*1e9)) }
        catch { if !a.isTerminated {up.postToPid(a.processIdentifier)}; throw error }
        if !a.isTerminated {up.postToPid(a.processIdentifier)}
    }
    func key(_ name:String, modifiers:[String]=[], duration:Double=0.08) async throws {
        guard let code=keyCodes[name.lowercased()], let src=CGEventSource(stateID:.privateState), let d=CGEvent(keyboardEventSource:src,virtualKey:code,keyDown:true), let u=CGEvent(keyboardEventSource:src,virtualKey:code,keyDown:false) else {throw GoError("无法构造按键 \(name)")}
        var flags:CGEventFlags=[]
        for m in modifiers {switch m {case "shift":flags.insert(.maskShift);case "ctrl":flags.insert(.maskControl);case "alt":flags.insert(.maskAlternate);case "cmd":flags.insert(.maskCommand);default:break}}
        d.flags=flags; u.flags=flags
        try await send(d,u,duration:duration)
    }
    func click(_ point:CGPoint, right:Bool) async throws {
        _ = try checkInput()
        // Refresh geometry before each click: moving the window must not stale coordinates.
        guard let wid=window?.windowID else {throw GoError("无游戏窗口")}
        let content=try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:false)
        guard let w=content.windows.first(where:{$0.windowID==wid && $0.owningApplication?.processID == app?.processIdentifier}) else {throw GoError("游戏窗口已变化，请重新连接")}
        guard (0..<1).contains(point.x), (0..<1).contains(point.y) else {throw GoError("点击超出窗口")}
        let p=CGPoint(x:w.frame.minX+point.x*w.frame.width,y:w.frame.minY+point.y*w.frame.height)
        guard let src=CGEventSource(stateID:.privateState) else {throw GoError("无法构造鼠标事件源")}
        let local=NSPoint(x:point.x*w.frame.width,y:(1-point.y)*w.frame.height)
        func mouse(_ type:NSEvent.EventType,pressure:Float) throws -> CGEvent {
            guard let ns=NSEvent.mouseEvent(with:type,location:local,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:Int(wid),context:nil,eventNumber:1,clickCount:1,pressure:pressure),let e=ns.cgEvent else {throw GoError("无法构造窗口鼠标事件")}
            e.setSource(src);e.location=p;e.flags=[]
            e.setIntegerValueField(.mouseEventSubtype,value:3)
            typealias WindowLocationSetter = @convention(c) (CGEvent, CGPoint) -> Void
            guard let symbol=dlsym(UnsafeMutableRawPointer(bitPattern:-2),"CGEventSetWindowLocation") else {throw GoError("当前系统缺少后台窗口坐标接口，已拒绝点击")}
            let setWindowLocation=unsafeBitCast(symbol,to:WindowLocationSetter.self)
            setWindowLocation(e,CGPoint(x:point.x*w.frame.width,y:point.y*w.frame.height))
            e.setIntegerValueField(.mouseEventButtonNumber,value:right ? 1:0)
            e.setIntegerValueField(.mouseEventWindowUnderMousePointer,value:Int64(wid))
            e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,value:Int64(wid))
            return e
        }
        let d=try mouse(right ? .rightMouseDown:.leftMouseDown,pressure:1)
        let u=try mouse(right ? .rightMouseUp:.leftMouseUp,pressure:0)
        // Some games resolve clicks from their last mouse-move event rather than
        // from the button event's location. Deliver movement only to the process.
        guard let move=CGEvent(mouseEventSource:src,mouseType:.mouseMoved,mouseCursorPosition:p,mouseButton:.left) else {throw GoError("无法构造窗口内鼠标位置")}
        move.flags=[]
        move.setIntegerValueField(.mouseEventWindowUnderMousePointer,value:Int64(wid))
        move.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,value:Int64(wid))
        try Task.checkCancellation()
        let a=try checkInput()
        let before=CGEvent(source:nil)?.location
        let front=NSWorkspace.shared.frontmostApplication?.processIdentifier
        move.postToPid(a.processIdentifier)
        try await Task.sleep(nanoseconds:50_000_000)
        try await send(d,u,duration:0.25)
        print("INPUT AUDIT front=\(String(describing:front))->\(String(describing:NSWorkspace.shared.frontmostApplication?.processIdentifier)) cursor=\(String(describing:before))->\(String(describing:CGEvent(source:nil)?.location))")
    }
}

// Small RGB frames; all detector coordinates are normalized to the game image.
struct Pixels {
    let width:Int, height:Int
    var data:[UInt8]
    init(_ image:CGImage) throws {
        width=640; height=max(1,Int(Double(image.height)*640/Double(image.width)))
        data=[UInt8](repeating:0,count:width*height*4)
        let w=width,h=height
        let ok=data.withUnsafeMutableBytes { bytes -> Bool in
            guard let ctx=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {return false}
            ctx.interpolationQuality = .low
            ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h));return true
        }
        guard ok else {throw GoError("无法解码图像")}
    }
    init(width:Int,height:Int,data:[UInt8]) {self.width=width;self.height=height;self.data=data}
    func candidate(_ settings:FishSettings) -> CGPoint? {
        var mask=[Bool](repeating:false,count:width*height)
        for y in 0..<height {for x in 0..<width {
            guard settings.region.contains(CGPoint(x:Double(x)/Double(width),y:Double(y)/Double(height))) else {continue}
            let i=(y*width+x)*4,r=Double(data[i]),g=Double(data[i+1]),b=Double(data[i+2])
            mask[y*width+x]=r >= settings.minRed && r > max(g,b)*settings.redRatio
        }}
        var best:CGPoint?;var bestScore=0.0
        for seed in 0..<mask.count where mask[seed] {
            var queue=[seed],head=0; mask[seed]=false
            var sx=0,sy=0,minX=width,maxX=0,minY=height,maxY=0
            while head<queue.count {
                let i=queue[head];head+=1;let x=i%width,y=i/width
                sx+=x;sy+=y;minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
                for dy in -1...1 {for dx in -1...1 {
                    let nx=x+dx,ny=y+dy
                    if nx>=0 && ny>=0 && nx<width && ny<height {let j=ny*width+nx;if mask[j] {mask[j]=false;queue.append(j)}}
                }}
            }
            let n=queue.count,bw=maxX-minX+1,bh=maxY-minY+1
            guard n>=3,n<=400,bw<=45,bh<=45,Double(max(bw,bh))/Double(max(1,min(bw,bh)))<6 else {continue}
            let score=Double(n)
            if score>bestScore {bestScore=score;best=CGPoint(x:Double(sx)/Double(n*width),y:Double(sy)/Double(n*height))}
        }
        return best
    }
    func patch(_ p:CGPoint,radius:Double) -> [UInt8] {
        let cx=Int(p.x*Double(width)),cy=Int(p.y*Double(height)),r=max(3,Int(radius*Double(width)))
        var out=[UInt8]()
        for y in max(0,cy-r)..<min(height,cy+r+1) {for x in max(0,cx-r)..<min(width,cx+r+1) {let i=(y*width+x)*4;out.append(contentsOf:data[i..<i+3])}}
        return out
    }
}
struct BiteDetector {
    var baseline:[UInt8]=[]
    var samples=0
    var streak=0
    var motion=0.0
    var splash=0.0
    var texture=0.0
    mutating func feed(_ patch:[UInt8], settings:FishSettings) -> Bool {
        guard !patch.isEmpty else {return false}
        guard baseline.count==patch.count else {baseline=patch;samples=1;streak=0;return false}
        var changed=0,brightened=0,textured=0
        for i in stride(from:0,to:patch.count,by:3) {
            let r=Int(patch[i]),g=Int(patch[i+1]),b=Int(patch[i+2])
            let delta=abs(r-Int(baseline[i]))+abs(g-Int(baseline[i+1]))+abs(b-Int(baseline[i+2]))
            if delta>60 {changed+=1}
            let baselineLight=(Int(baseline[i])+Int(baseline[i+1])+Int(baseline[i+2]))/3
            // Water spray can be gray under shaded city lighting. Detect neutral
            // pixels brightening relative to this bobber's baseline, not white.
            if min(r,g,b)>60 && max(r,g,b)-min(r,g,b)<55 && (r+g+b)/3-baselineLight>18 {
                brightened+=1
                if i>=3 && i+5<patch.count {
                    let left=(Int(patch[i-3])+Int(patch[i-2])+Int(patch[i-1]))/3
                    let right=(Int(patch[i+3])+Int(patch[i+4])+Int(patch[i+5]))/3
                    if max(abs((r+g+b)/3-left),abs((r+g+b)/3-right))>9 {textured+=1}
                }
            }
        }
        let n=Double(patch.count/3)
        motion=Double(changed)/n;splash=Double(brightened)/n;texture=Double(textured)/n
        samples+=1
        let strong=motion>settings.motionThreshold && splash>settings.splashThreshold && texture>settings.splashThreshold*0.3
        let continuation=streak>0 && motion>settings.motionThreshold*0.35 && splash>settings.splashThreshold*0.35 && texture>settings.splashThreshold*0.1
        let hit=samples>5 && (strong || continuation)
        streak=hit ? streak+1:0
        // Freeze baseline when a potential splash begins; otherwise slowly adapt to water.
        if !hit {for i in baseline.indices {baseline[i]=UInt8((Double(baseline[i])*0.95+Double(patch[i])*0.05).rounded())}}
        return streak>=2
    }
}
