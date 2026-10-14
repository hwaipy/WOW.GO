import Foundation
import AppKit
import ImageIO
func selfTest() throws {
    func expect(_ condition:Bool,_ label:String) throws {guard condition else {throw GoError(label)};print("PASS \(label)")}
    let p=try Program.parse(sampleScript);try expect(p.steps[0].count==10,"nested fishing script")
    _ = try Program.parse(testScript)
    for bad in ["{\"name\":\"x\",\"steps\":[{\"action\":\"key\",\"key\":\"invalid\"}]}","{\"name\":\"x\",\"steps\":[{\"action\":\"click\",\"x\":2,\"y\":0}]}","{\"name\":\"x\",\"steps\":[{\"action\":\"wait\",\"seconds\":-1}]}","{\"name\":\"x\",\"steps\":[{\"action\":\"repeat\",\"count\":0,\"steps\":[]}]}"] {
        do {_ = try Program.parse(bad);throw GoError("bad script accepted")} catch is DecodingError {} catch let e as GoError {if e.message=="bad script accepted" {throw e}}
    }
    print("PASS invalid scripts rejected before execution")
    var s=FishSettings();s.region=Region(x:0.1,y:0.1,w:0.8,h:0.8)
    let quiet=try Pixels(fixture(splash:false)),splash=try Pixels(fixture(splash:true))
    guard let point=quiet.candidate(s) else {throw GoError("bobber not detected")}
    try expect(abs(point.x-0.5)<0.02 && abs(point.y-0.5)<0.02,"bobber center and image orientation")
    s.region=Region(x:0,y:0,w:0.1,h:0.1)
    try expect(quiet.candidate(s)==nil,"ROI excludes other red objects")
    s.region=Region(x:0.1,y:0.1,w:0.8,h:0.8)
    var d=BiteDetector()
    for _ in 0..<12 {try expect(!d.feed(quiet.patch(point,radius:s.radius),settings:s),"quiet frame does not trigger")}
    try expect(!d.feed(splash.patch(point,radius:s.radius),settings:s),"single splash frame does not trigger")
    try expect(d.feed(splash.patch(point,radius:s.radius),settings:s),"two splash frames trigger retrieval")
    var single=BiteDetector()
    for _ in 0..<8 {_ = single.feed(quiet.patch(point,radius:s.radius),settings:s)}
    _ = single.feed(splash.patch(point,radius:s.radius),settings:s)
    try expect(!single.feed(quiet.patch(point,radius:s.radius),settings:s),"transient splash resets streak")
    let resources=Bundle.main.resourceURL!.appendingPathComponent("fixtures")
    for (before,after,shouldBite) in [("bobber-before","bite",true),("wave-before","wave",false)] {
        func frame(_ name:String) throws -> Pixels {
            guard let src=CGImageSourceCreateWithURL(resources.appendingPathComponent(name+".png") as CFURL,nil),let img=CGImageSourceCreateImageAtIndex(src,0,nil) else {throw GoError("missing real fixture")}
            return try Pixels(img)
        }
        let a=try frame(before),b=try frame(after)
        guard let p=a.candidate(s) else {throw GoError("real bobber not found")}
        var detector=BiteDetector()
        for _ in 0..<10 {_ = detector.feed(a.patch(p,radius:s.radius),settings:s)}
        _ = detector.feed(b.patch(p,radius:s.radius),settings:s)
        let hit=detector.feed(b.patch(p,radius:s.radius),settings:s)
        try expect(hit==shouldBite,"real frame regression: \(after)")
    }
    let lockURL=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("fishgo-test-\(UUID().uuidString).lock")
    let first=try RunLease(lockURL)
    do {let second=try RunLease(lockURL);second.release();throw GoError("duplicate run accepted")} catch let e as GoError {if e.message=="duplicate run accepted" {throw e}}
    first.release();let next=try RunLease(lockURL);next.release();try? FileManager.default.removeItem(at:lockURL)
    print("PASS single-run lock and release")
    print("ALL TESTS PASSED")
}

@MainActor final class FakeIO:GameIO {
    var actions:[String]=[]
    var frames=0
    override func checkInput() throws -> NSRunningApplication {NSRunningApplication.current}
    override func key(_ name:String,modifiers:[String]=[],duration:Double=0.08) async throws {try Task.checkCancellation();actions.append("key:\(name)")}
    override func click(_ point:CGPoint,right:Bool) async throws {try Task.checkCancellation();actions.append(right ? "right":"left")}
    override func capture() async throws -> CGImage {frames+=1;return fixture(splash:frames>=18)}
}
@MainActor func integrationTest() async throws {
    let io=FakeIO(),m=GoModel(io:nil)
    m.io=io;m.runDry=false;m.frozenSettings=FishSettings();m.frozenSettings.settle=0;m.frozenSettings.timeout=5
    let program=try Program.parse("""
    {"name":"integration","steps":[
      {"action":"repeat","count":2,"steps":[{"action":"key","key":"m"},{"action":"wait","seconds":0.01}]},
      {"action":"click","x":0.5,"y":0.5},
      {"action":"fish"}
    ]}
    """)
    try await m.execute(program.steps)
    guard io.actions == ["key:m","key:m","left","key:1","right"],m.bites==1,m.timeouts==0 else {throw GoError("sequence/fishing integration failed: \(io.actions)")}
    print("PASS exact action order: repeat → key → click → cast → detect → retrieve")
    let before=io.actions.count
    let t=Task {try await m.execute([Step(action:"wait",seconds:30),Step(action:"key",key:"m")])}
    try await Task.sleep(nanoseconds:50_000_000);t.cancel()
    do {try await t.value;throw GoError("cancel not propagated")} catch is CancellationError {}
    guard io.actions.count==before else {throw GoError("input after cancel")}
    print("PASS cancellation interrupts wait and prevents subsequent input")
    print("INTEGRATION TESTS PASSED")
}
