import SwiftUI
import RealityKit
import Combine

/// Scene input stays out of persisted memorial data.
final class ParkControls: ObservableObject {
    var movement = SIMD2<Float>.zero
    var active = true
    var destination: SIMD3<Float>?
    @Published var selected: Int?
    @Published var nearest: Int?
    @Published var autoWalk = false
    @Published var petSitting = false
    @Published var petMessage: String?
    var petRequest = 0
    @Published var venue: TownPlace?
    @Published var nearbyPlace: TownPlace?
    var ballRequest = 0
}

enum ParkLayout {
    static let count = 48
    static func position(_ index: Int) -> SIMD3<Float> {
        let column = index % 6
        let x = column < 3 ? Float(column) * 2.8 - 9 : Float(column - 3) * 2.8 + 3.4
        return [x, 0, Float(index / 6) * -3.0 + 6]
    }
    static func arrival(_ index:Int)->SIMD3<Float> { position(index)+[0,0,1.2] }
    static func isWalkable(_ p: SIMD3<Float>) -> Bool {
        guard abs(p.x) < (p.z > 11 ? 19 : 12), p.z > -19, p.z < 29 else { return false }
        if TownPlace.allCases.filter({ $0 == .memories || $0 == .post }).contains(where: { abs(p.x - $0.center.x) < 3.4 && abs(p.z - $0.center.z) < 2.7 }) { return false }
        if simd_distance(p, SIMD3<Float>(0,0,18)) < 1.95 { return false }
        for x:Float in [-4.7,4.7] {
            for z:Float in [13,20,26] { if abs(p.x-x)<0.95 && abs(p.z-z)<0.65 { return false } }
            if abs(p.x-x)<1.1 && abs(p.z-16)<0.6 { return false }
            for z:Float in [14.5,24.5] { if abs(p.x-x)<0.35 && abs(p.z-z)<0.35 { return false } }
        }
        return !(0..<count).contains { index in
            let d = p - position(index)
            return abs(d.x) < 0.92 && abs(d.z) < 0.8
        }
    }
}

struct MemorialParkScene: UIViewRepresentable {
    @ObservedObject var controls: ParkControls
    let garden: MemorialGarden?
    let plots: [PublicMonument]
    func makeCoordinator() -> Coordinator { Coordinator(controls) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        context.coordinator.attach(view)
        context.coordinator.refresh(garden, plots: plots)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { context.coordinator.refresh(garden, plots: plots) }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.subscription?.cancel(); coordinator.controls.movement = .zero
        view.scene.anchors.removeAll()
    }
    final class Coordinator: NSObject {
        let controls: ParkControls
        weak var view: ARView?
        let root = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        let player = Entity()
        let monuments = Entity()
        let pet = Entity()
        let petTail = Entity()
        let affection = Entity()
        var petLegs:[Entity] = []
        var petSpecies = ""
        var lastPetRequest = 0
        let ball = Entity()
        var lastBallRequest = 0
        var fetchTime: Float = 0
        var fetchStart = SIMD3<Float>.zero
        var fetchTarget = SIMD3<Float>.zero
        var affectionTime:Float = 0
        var breadcrumbs:[SIMD3<Float>] = []
        var strollNorth = true
        let sunlight = DirectionalLight()
        var limbs: [Entity] = []
        var subscription: Cancellable?
        var yaw: Float = 0
        var distance: Float = 10.5
        var phase: Float = 0
        var signature = ""
        var nearestTick: Float = 0
        var waterDrops:[Entity] = []
        var fountainTime:Float = 0
        var fountainAccumulator:Float = 0
        let sharedSphere = MeshResource.generateSphere(radius:1)
        var boxMeshes:[SIMD3<Float>:MeshResource] = [:]
        var plazaLights:[PointLight] = []
        var lampGlow:[ModelEntity] = []
        init(_ controls: ParkControls) { self.controls = controls }
        func attach(_ view: ARView) {
            self.view = view; view.scene.addAnchor(root)
            root.addChild(camera); root.addChild(monuments); root.addChild(player);root.addChild(pet);root.addChild(affection)
            camera.camera.fieldOfViewInDegrees = 58
            view.environment.background = .color(UIColor(red: 0.85, green: 0.91, blue: 0.86, alpha: 1))
            view.environment.lighting.intensityExponent = 1
            let light = sunlight; light.light.intensity = 2800
            light.shadow = .init(maximumDistance: 40, depthBias: 2)
            light.look(at: .zero, from: [8,18,8], relativeTo: nil); root.addChild(light)
            box(root, [0,-0.15,-3.5], [26,0.3,34], UIColor(red: 0.66, green: 0.75, blue: 0.52, alpha: 1))
            let path = UIColor(red: 0.91, green: 0.86, blue: 0.73, alpha: 1)
            box(root, [0,0.015,-3.5], [3.4,0.03,33], path)
            for row in 0..<9 { box(root, [0,0.02,7.5-Float(row)*3], [24,0.04,1.15], path) }
            // Repeated low-poly trees frame the park without remote asset loads.
            for side: Float in [-1,1] {
                for n in 0..<8 {
                    let x = side*12.3, z = 9-Float(n)*4
                    box(root, [x,0.8,z], [0.24,1.6,0.24], .brown)
                    sphere(root, [x,2.0,z], [0.85,1.2,0.85], UIColor(red: 0.39, green: 0.57, blue: 0.40, alpha: 1))
                }
            }
            // Rainbow arch at the park entrance.
            let colors: [UIColor] = [.systemPink,.systemOrange,.systemYellow,.systemGreen,.systemTeal]
            for (band, color) in colors.enumerated() {
                let radius = Float(2.0) + Float(band)*0.13
                for step in 0...30 {
                    let a = Float(step)/30 * .pi
                    sphere(root, [cos(a)*radius,1+sin(a)*radius,10], [0.09,0.11,0.09], color)
                }
                for side: Float in [-1,1] { box(root,[side*radius,0.5,10],[0.15,1,0.15],color) }
            }
            makeTown()
            makePlayer(); player.position = TownPlace.plaza.arrival
            view.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(pan(_:))))
            view.addGestureRecognizer(UIPinchGestureRecognizer(target:self,action:#selector(pinch(_:))))
            view.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(tap(_:))))
            view.accessibilityLabel = "可以行走的三维纪念园"
            view.accessibilityIdentifier = "parkScene"
            view.isAccessibilityElement = true
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in self?.step(Float(event.deltaTime)) }
            updateCamera()
        }
        func refresh(_ garden: MemorialGarden?, plots: [PublicMonument]) {
            let key = plots.map { "\($0.index)|\($0.name)|\($0.photo.hashValue)|\($0.flowers ?? 0)|\($0.candles ?? 0)" }.joined(separator:",") + "|\(garden?.theme ?? "sage")|\(garden?.name ?? "")|\(garden?.photos.first?.id ?? "")|\(garden?.flowerCount ?? 0)|\(garden?.candleCount ?? 0)"
            let species=garden?.species ?? ""
            if species != petSpecies { petSpecies=species;makePet(species);pet.position=player.position+[0.6,0,0.6] }
            pet.isEnabled = garden != nil
            guard key != signature else { return }; signature = key
            let night = garden?.theme == "moon", sunset = garden?.theme == "sunset"
            view?.environment.background = .color(night ? UIColor(red:0.15,green:0.22,blue:0.3,alpha:1) : sunset ? UIColor(red:0.95,green:0.81,blue:0.71,alpha:1) : UIColor(red:0.85,green:0.91,blue:0.86,alpha:1))
            sunlight.light.intensity = night ? 1000 : 2800
            for light in plazaLights { light.light.intensity = night ? 450 : sunset ? 200 : 0 }
            for glow in lampGlow { glow.model?.materials = [UnlitMaterial(color: night || sunset ? UIColor(red:1,green:0.79,blue:0.42,alpha:1) : UIColor(red:1,green:0.95,blue:0.78,alpha:1))] }
            sunlight.light.color = sunset ? UIColor(red:1,green:0.78,blue:0.60,alpha:1) : .white
            for child in Array(monuments.children) { child.removeFromParent() }
            for index in 0..<ParkLayout.count {
                let stone = Entity(); stone.name = "plot-\(index)"; stone.position = ParkLayout.position(index); monuments.addChild(stone)
                box(stone,[0,0.07,0],[1.65,0.14,1.35],UIColor(red:0.89,green:0.85,blue:0.72,alpha:1))
                sphere(stone,[0,0.2,-0.1],[0.72,0.26,0.55],UIColor(red:0.53,green:0.66,blue:0.43,alpha:1))
                let cream = UIColor(red:0.95,green:0.92,blue:0.82,alpha:1)
                box(stone,[0,0.65,0],[0.86,0.95,0.36],cream)
                sphere(stone,[0,1.1,0],[0.43,0.4,0.18],cream)
                let monument = plots.first { $0.index == index }
                let own = monument?.isMine == true
                plaque(stone, title: monument?.name ?? String(format:"%02d · 空位",index+1), photo: monument?.memoryPhoto)
                if monument != nil {
                    for n in 0..<min((monument?.flowers ?? 0) + (own ? garden?.flowerCount ?? 0 : 0),6) {
                        let x = Float(n)*0.18-0.45
                        box(stone,[x,0.26,0.43],[0.025,0.26,0.025],.systemGreen)
                        sphere(stone,[x,0.41,0.43],[0.09,0.05,0.09],.white)
                    }
                    if (monument?.candles ?? 0) + (own ? garden?.candleCount ?? 0 : 0) > 0 {
                        box(stone,[0.6,0.25,0.4],[0.15,0.3,0.15],.white)
                        sphere(stone,[0.6,0.45,0.4],[0.05,0.1,0.05],.systemOrange)
                    }
                }
                stone.generateCollisionShapes(recursive:true)
            }
        }
        func plaque(_ parent: Entity, title: String, photo: MemoryPhoto?) {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size:CGSize(width:256,height:320),format:format).image { context in
                UIColor(red:0.96,green:0.94,blue:0.88,alpha:1).setFill(); context.fill(CGRect(x:0,y:0,width:256,height:320))
                if let photo, let data = Data(base64Encoded:photo.imageBase64), let source = UIImage(data:data) {
                    let factor = min(220/source.size.width,220/source.size.height)
                    let size = CGSize(width:source.size.width*factor,height:source.size.height*factor)
                    source.draw(in:CGRect(x:(256-size.width)/2,y:20+(220-size.height)/2,width:size.width,height:size.height))
                } else {
                    let symbol = UIImage(systemName:"pawprint.fill")?.withTintColor(.init(red:0.50,green:0.59,blue:0.44,alpha:1),renderingMode:.alwaysOriginal)
                    symbol?.draw(in:CGRect(x:78,y:65,width:100,height:100))
                }
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
                (title as NSString).draw(in:CGRect(x:8,y:265,width:240,height:45),withAttributes:[.font:UIFont.systemFont(ofSize:24,weight:.medium),.foregroundColor:UIColor.darkGray,.paragraphStyle:paragraph])
            }
            let surface = ModelEntity(mesh:.generatePlane(width:0.65,height:0.81),materials:[UnlitMaterial(color:.white)])
            surface.position = [0,0.8,0.19]
            if let cg = image.cgImage, let texture = try? TextureResource.generate(from:cg,options:.init(semantic:.color)) {
                var material = UnlitMaterial(); material.color = .init(texture:.init(texture)); surface.model?.materials = [material]
            }
            parent.addChild(surface)
        }
        func makePlayer() {
            let skin = UIColor(red:0.92,green:0.75,blue:0.59,alpha:1)
            sphere(player,[0,1.23,0],[0.34,0.35,0.32],skin)
            sphere(player,[0,1.40,0.02],[0.36,0.24,0.34],UIColor(red:0.25,green:0.18,blue:0.14,alpha:1))
            box(player,[0,0.72,0],[0.48,0.55,0.32],UIColor(red:0.40,green:0.59,blue:0.51,alpha:1))
            for side: Float in [-1,1] {
                let leg = Entity(); leg.position = [side*0.14,0.48,0]; player.addChild(leg)
                box(leg,[0,-0.18,0],[0.18,0.35,0.19],.init(white:0.35,alpha:1)); sphere(leg,[0,-0.39,-0.06],[0.12,0.10,0.19],.init(white:0.95,alpha:1)); limbs.append(leg)
                let arm = Entity(); arm.position = [side*0.32,0.9,0]; player.addChild(arm)
                sphere(arm,[0,-0.2,0],[0.10,0.27,0.10],skin); limbs.append(arm)
                sphere(player,[side*0.12,1.25,-0.29],[0.025,0.035,0.025],.black)
            }
        }
        func cone(height:Float,radius:Float)->MeshResource {
            var positions:[SIMD3<Float>]=[[0,height/2,0],[0,-height/2,0]]
            for i in 0..<12 { let a=Float(i)/12 * .pi*2;positions.append([cos(a)*radius,-height/2,sin(a)*radius]) }
            var indices:[UInt32]=[]
            for i in 0..<12 { let a=UInt32(i+2),b=UInt32((i+1)%12+2);indices += [0,b,a,1,a,b] }
            var descriptor=MeshDescriptor();descriptor.positions=MeshBuffers.Positions(positions);descriptor.primitives = .triangles(indices)
            return (try? MeshResource.generate(from:[descriptor])) ?? .generateSphere(radius:radius)
        }
        func makePet(_ species:String) {
            for child in Array(pet.children) { child.removeFromParent() };petLegs=[]
            for child in Array(petTail.children) { child.removeFromParent() }
            for child in Array(affection.children) { child.removeFromParent() }
            pet.name="companion"
            let dog=species=="dog"
            let fur=dog ? UIColor(red:0.77,green:0.57,blue:0.36,alpha:1):UIColor(red:0.9,green:0.82,blue:0.68,alpha:1)
            sphere(pet,[0,0.38,0.05],[0.24,0.22,0.37],fur)
            sphere(pet,[0,0.62,-0.25],[0.25,0.24,0.23],fur)
            sphere(pet,[0,0.53,-0.44],[0.14,0.10,0.10],.init(white:0.97,alpha:1))
            sphere(pet,[0,0.58,-0.51],[0.045,0.033,0.025],.init(red:0.36,green:0.27,blue:0.24,alpha:1))
            for side:Float in [-1,1] {
                sphere(pet,[side*0.105,0.66,-0.45],[0.032,0.044,0.022],.init(white:0.17,alpha:1))
                sphere(pet,[side*0.115,0.68,-0.469],[0.009,0.011,0.008],.white)
                if dog { sphere(pet,[side*0.25,0.66,-0.20],[0.09,0.23,0.13],fur.withAlphaComponent(1)) }
                else {
                    let ear=ModelEntity(mesh:cone(height:0.25,radius:0.115),materials:[SimpleMaterial(color:fur,roughness:0.9,isMetallic:false)])
                    ear.position=[side*0.17,0.88,-0.23];pet.addChild(ear)
                    sphere(pet,[side*0.17,0.85,-0.30],[0.045,0.065,0.015],.systemPink.withAlphaComponent(0.7))
                }
                for z:Float in [-0.17,0.26] {
                    let leg=Entity();leg.position=[side*0.15,0.3,z];pet.addChild(leg)
                    sphere(leg,[0,-0.14,0],[0.065,0.16,0.08],fur);petLegs.append(leg)
                }
            }
            petTail.position=[0,0.45,0.35];pet.addChild(petTail)
            sphere(petTail,[0,0.17,0.1],[0.065,0.24,0.065],fur)
            box(pet,[0,0.48,-0.22],[0.38,0.06,0.20],UIColor(red:0.37,green:0.57,blue:0.46,alpha:1))
            pet.generateCollisionShapes(recursive:true)
            // A small floating heart cluster appears only while being petted.
            for n in 0..<3 {
                let heart=Entity();heart.position=[Float(n-1)*0.22,Float(n%2)*0.18,0];affection.addChild(heart)
                let pink=UIColor(red:0.91,green:0.55,blue:0.57,alpha:1)
                sphere(heart,[-0.035,0.035,0],[0.055,0.06,0.025],pink);sphere(heart,[0.035,0.035,0],[0.055,0.06,0.025],pink)
                let tip=ModelEntity(mesh:cone(height:0.12,radius:0.08),materials:[UnlitMaterial(color:pink)])
                tip.orientation=simd_quatf(angle:.pi,axis:[0,0,1]);tip.position=[0,-0.015,0];heart.addChild(tip)
            }
            affection.isEnabled=false
        }
        func updatePet(_ dt:Float) {
            guard pet.isEnabled else { return }
            if lastBallRequest != controls.ballRequest {
                lastBallRequest = controls.ballRequest; controls.petSitting = false
                fetchStart = player.position; fetchTarget = TownPlace.meadow.arrival + [0,0,-3]
                fetchTime = 4; ball.position = fetchTarget + [0,0.2,0]; ball.isEnabled = true
                controls.petMessage = "去追小球吧，我们在这里等你。"
            }
            if fetchTime > 0 {
                fetchTime = max(0, fetchTime-dt)
                let target = fetchTime > 2 ? fetchTarget : fetchStart + [0.6,0,0]
                let delta = target-pet.position
                if simd_length(delta)>0.08 {
                    pet.position += simd_normalize(delta)*min(simd_length(delta),dt*4)
                    pet.orientation = simd_quatf(angle:atan2(-delta.x,-delta.z),axis:[0,1,0])
                }
                for (i,leg) in petLegs.enumerated() { leg.orientation=simd_quatf(angle:sin(Float(CACurrentMediaTime())*12)*0.4*(i%2==0 ? 1:-1),axis:[1,0,0]) }
                if fetchTime < 2 { ball.position=pet.position+[0,0.3,-0.3] }
                if fetchTime == 0 { ball.isEnabled=false;breadcrumbs=[];controls.petMessage="它把小球带回来了，再陪它玩一次吧。" }
                return
            }
            if lastPetRequest != controls.petRequest {
                lastPetRequest=controls.petRequest
                if simd_distance(pet.position,player.position)<2.2 {
                    affectionTime=3;controls.petMessage="轻轻摸摸你，就像从前一样。"
                    UIImpactFeedbackGenerator(style:.soft).impactOccurred()
                } else { controls.petSitting=false;controls.petMessage="它正向你走来，再等等它。" }
            }
            let last=breadcrumbs.last ?? pet.position
            if simd_distance(last,player.position)>0.18 { breadcrumbs.append(player.position) }
            if breadcrumbs.count>400 { breadcrumbs.removeFirst(breadcrumbs.count-400) }
            var moving=false
            if !controls.petSitting && affectionTime<=0 && simd_distance(pet.position,player.position)>0.85, let target=breadcrumbs.first {
                let delta=target-pet.position
                if simd_length(delta)<0.15 { breadcrumbs.removeFirst() }
                else {
                    let velocity=simd_normalize(delta)*min(simd_length(delta),dt*3.1)
                    let next=pet.position+velocity
                    if ParkLayout.isWalkable(next) { pet.position=next;moving=true }
                    else { breadcrumbs.removeFirst() }
                    pet.orientation=simd_quatf(angle:atan2(-delta.x,-delta.z),axis:[0,1,0])
                }
            }
            pet.scale=controls.petSitting ? [1,0.78,1]:[1,1,1]
            for (i,leg) in petLegs.enumerated() { leg.orientation=simd_quatf(angle:moving ? sin(Float(CACurrentMediaTime())*12)*0.4*(i==0 || i==3 ? 1:-1):0,axis:[1,0,0]) }
            petTail.orientation=simd_quatf(angle:sin(Float(CACurrentMediaTime())*7)*(affectionTime>0 ? 0.65:0.18),axis:[0,0,1])
            affectionTime=max(0,affectionTime-dt);affection.isEnabled=affectionTime>0
            affection.position=pet.position+[0,1.15+(3-affectionTime)*0.12,0]
            affection.orientation=camera.orientation
            if affectionTime==0 && controls.petMessage != nil && simd_distance(pet.position,player.position)<1.1 { controls.petMessage=nil }
        }
        func step(_ elapsed: Float) {
            guard controls.active else { return }
            let dt = min(elapsed,0.05)
            fountainTime += dt
            fountainAccumulator += dt
            let nearFountain=simd_distance(player.position,TownPlace.plaza.center)<16
            let waterInterval:Float = ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0/20 : 1.0/30
            if nearFountain && !UIAccessibility.isReduceMotionEnabled && fountainAccumulator >= waterInterval {
                fountainAccumulator = 0
                for (i,drop) in waterDrops.enumerated() {
                    let t=(fountainTime*0.48+Float(i%4)/4).truncatingRemainder(dividingBy:1)
                    let a=Float(i/4)*Float.pi/4
                    let r:Float=0.12+1.35*t
                    drop.position=[cos(a)*r,1.85+2.5*t-3.9*t*t,sin(a)*r]
                }
            }
            if let destination = controls.destination {
                player.position = destination; controls.destination = nil;controls.autoWalk=false
                pet.position=destination+[0.55,0,0.25];breadcrumbs=[];fetchTime=0;ball.isEnabled=false
            }
            let input = controls.movement
            let forward = SIMD3<Float>(-sin(yaw),0,-cos(yaw))
            let right = SIMD3<Float>(cos(yaw),0,-sin(yaw))
            var movement = right*input.x + forward * -input.y
            if simd_length(movement)>0.02 { controls.autoWalk=false }
            if controls.autoWalk && player.position.z > 11 {
                let target:SIMD3<Float> = strollNorth ? [11,0,14] : [11,0,24]
                let delta=target-player.position
                if simd_length(delta)<0.4 { strollNorth.toggle() }
                movement=simd_length(delta)>0.05 ? simd_normalize(delta)*0.55:.zero
            } else if controls.autoWalk {
                // First return along a clear aisle, then stroll along the central path.
                let rowZ = (round((player.position.z-7.5)/3)*3+7.5)
                let target:SIMD3<Float>
                if abs(player.position.x)>0.3 {
                    target=abs(player.position.z-rowZ)>0.08 ? [player.position.x,0,rowZ] : [0,0,rowZ]
                } else {
                    if player.position.z < -15 { strollNorth=false };if player.position.z > 7 { strollNorth=true }
                    target=[0,0,strollNorth ? -16:8]
                }
                let delta=target-player.position
                movement=simd_length(delta)>0.05 ? simd_normalize(delta)*0.55:.zero
            }
            if simd_length(movement) > 0.02 {
                let delta = movement*dt*2.6
                let px = player.position + [delta.x,0,0]
                if ParkLayout.isWalkable(px) { player.position = px }
                let pz = player.position + [0,0,delta.z]
                if ParkLayout.isWalkable(pz) { player.position = pz }
                player.orientation = simd_quatf(angle:atan2(-movement.x,-movement.z),axis:[0,1,0])
                phase += dt*9
            }
            for (index, limb) in limbs.enumerated() {
                let amplitude: Float = simd_length(movement) > 0.02 ? sin(phase)*0.45 : 0
                limb.orientation = simd_quatf(angle:amplitude * (index == 0 || index == 3 ? 1 : -1),axis:[1,0,0])
            }
            updatePet(dt)
            updateCamera()
            nearestTick += dt
            if nearestTick > 0.2 {
                nearestTick = 0
                let place = TownPlace.allCases.first { simd_distance(player.position,$0.arrival)<3 }
                if controls.nearbyPlace != place { controls.nearbyPlace=place }
                view?.accessibilityValue = String(format:"位置 %.2f, %.2f",player.position.x,player.position.z)
                let near = (0..<ParkLayout.count).min { simd_distance(player.position,ParkLayout.position($0)) < simd_distance(player.position,ParkLayout.position($1)) }
                let value = near.flatMap { simd_distance(player.position,ParkLayout.position($0)) < 2.5 ? $0 : nil }
                if controls.nearest != value { controls.nearest = value }
            }
        }
        func updateCamera() {
            let target = player.position + [0,0.9,0]
            camera.look(at:target,from:target+[sin(yaw)*distance,4.6,cos(yaw)*distance],relativeTo:nil)
        }
        @objc func pan(_ gesture: UIPanGestureRecognizer) { let d=gesture.translation(in:view); yaw -= Float(d.x)*0.006; gesture.setTranslation(.zero,in:view); updateCamera() }
        @objc func pinch(_ gesture: UIPinchGestureRecognizer) { distance=max(4,min(11,distance/Float(gesture.scale))); gesture.scale=1; updateCamera() }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            var entity = view?.entity(at:gesture.location(in:view))
            while let current = entity {
                if current.name.hasPrefix("town-"), let place=TownPlace(rawValue:String(current.name.dropFirst(5))) {
                    controls.movement = .zero; controls.autoWalk=false
                    controls.destination=place.arrival; controls.venue=place; return
                }
                if current.name == "companion" { controls.petRequest += 1;controls.autoWalk=false;controls.movement = .zero;return }
                if current.name.hasPrefix("plot-"), let index=Int(current.name.dropFirst(5)) { controls.movement = .zero; controls.selected=index; return }
                entity = current.parent
            }
        }
        func makeTown() {
            let cream=UIColor(red:0.94,green:0.90,blue:0.79,alpha:1)
            let green=UIColor(red:0.30,green:0.47,blue:0.39,alpha:1)
            box(root,[0,-0.16,19],[40,0.3,20],UIColor(red:0.67,green:0.77,blue:0.56,alpha:1))
            box(root,[0,0.02,19],[8,0.05,19],cream)
            box(root,[0,0.03,22],[32,0.06,3],cream)
            for place in TownPlace.allCases {
                let building=Entity(); building.name="town-"+place.rawValue; building.position=place.center;root.addChild(building)
                if place == .memories || place == .post {
                    let roof=place == .post ? UIColor(red:0.65,green:0.39,blue:0.32,alpha:1):green
                    box(building,[0,1.6,0],[6,3.2,4.6],cream)
                    box(building,[0,3.35,0],[6.6,0.35,5.2],roof)
                    let top=ModelEntity(mesh:cone(height:1.6,radius:4.3),materials:[SimpleMaterial(color:roof,roughness:0.9,isMetallic:false)])
                    top.position=[0,4.1,0];top.scale=[1,1,0.8];building.addChild(top)
                    box(building,[0,1.1,2.34],[1.3,2.2,0.1],green)
                    for x:Float in [-2,2] {
                        box(building,[x,1.75,2.34],[1.1,1.3,0.12],.white)
                        box(building,[x,1.75,2.42],[0.9,1.1,0.08],UIColor(red:0.61,green:0.78,blue:0.78,alpha:1))
                    }
                    box(building,[0,0.12,3],[3,0.24,1.2],.white)
                } else if place == .plaza {
                    makeFountain(building)
                } else {
                    for side:Float in [-1,1] {
                        box(building,[side*3,1.2,0],[0.25,2.4,0.25],.brown)
                        sphere(building,[side*3,3,0],[1.4,1.7,1.4],green)
                    }
                }
                let sign=ModelEntity(mesh:.generateText(place.title,extrusionDepth:0.015,font:.systemFont(ofSize:0.35,weight:.semibold)),materials:[SimpleMaterial(color:green,roughness:1,isMetallic:false)])
                sign.position=[-1.5,place == .memories || place == .post ? 2.7:0.8,place == .memories || place == .post ? 2.5:2]
                if place != .plaza { building.addChild(sign) }
                // One simple hit target per destination; decorative water has no collision work.
                let size:SIMD3<Float> = place == .memories || place == .post ? [6,3.5,5] : [3.6,2.5,3.6]
                building.components.set(CollisionComponent(shapes:[ShapeResource.generateBox(size:size).offsetBy(translation:[0,size.y/2,0])]))
            }
            decoratePlaza()
            for x:Float in [-4.7,4.7] {
                box(root,[x,0.55,16],[1.8,0.15,0.6],.brown)
                box(root,[x,0.9,15.75],[1.8,0.6,0.1],.brown)
                for dx:Float in [-0.65,0.65] { box(root,[x+dx,0.25,16],[0.12,0.5,0.5],green) }
            }
            sphere(ball,.zero,[0.22,0.22,0.22],.systemOrange);root.addChild(ball);ball.isEnabled=false
        }
        func ring(_ parent:Entity, radius:Float, y:Float, thickness:Float, height:Float, color:UIColor) {
            // A single indexed mesh replaces forty separate rounded-box entities.
            var positions:[SIMD3<Float>]=[]
            var indices:[UInt32]=[]
            let segments=48
            for i in 0...segments {
                let a=Float(i)*Float.pi*2/Float(segments)
                for (r,h) in [(radius-thickness/2,y-height/2),(radius+thickness/2,y-height/2),(radius+thickness/2,y+height/2),(radius-thickness/2,y+height/2)] {
                    positions.append([sin(a)*r,h,cos(a)*r])
                }
            }
            for i in 0..<segments { for side in 0..<4 {
                let a=UInt32(i*4+side),b=UInt32(i*4+(side+1)%4),c=b+4,d=a+4
                indices += [a,c,b,a,d,c]
            } }
            var descriptor=MeshDescriptor();descriptor.positions=MeshBuffers.Positions(positions);descriptor.primitives = .triangles(indices)
            guard let mesh=try? MeshResource.generate(from:[descriptor]) else { return }
            parent.addChild(ModelEntity(mesh:mesh,materials:[SimpleMaterial(color:color,roughness:0.65,isMetallic:false)]))
        }
        func makeFountain(_ parent:Entity) {
            let stone=UIColor(red:0.84,green:0.81,blue:0.70,alpha:1)
            let trim=UIColor(red:0.96,green:0.92,blue:0.81,alpha:1)
            sphere(parent,[0,0.09,0],[1.78,0.12,1.78],stone)
            ring(parent,radius:1.63,y:0.3,thickness:0.22,height:0.42,color:trim)
            let water=ModelEntity(mesh:.generateSphere(radius:1),materials:[SimpleMaterial(color:UIColor(red:0.32,green:0.65,blue:0.65,alpha:1),roughness:0.25,isMetallic:false)])
            water.scale=[1.51,0.025,1.51];water.position=[0,0.30,0];parent.addChild(water)
            sphere(parent,[0,0.55,0],[0.42,0.35,0.42],stone)
            box(parent,[0,1,0],[0.23,1.1,0.23],trim)
            sphere(parent,[0,1.42,0],[0.72,0.10,0.72],stone)
            ring(parent,radius:0.65,y:1.48,thickness:0.10,height:0.15,color:trim)
            sphere(parent,[0,1.55,0],[0.58,0.025,0.58],UIColor(red:0.43,green:0.76,blue:0.75,alpha:1))
            sphere(parent,[0,1.75,0],[0.12,0.23,0.12],trim)
            // Reuse mesh/material for 32 droplets, updated at 30 Hz only near the fountain.
            let mesh=sharedSphere
            let material=SimpleMaterial(color:UIColor(red:0.65,green:0.88,blue:0.89,alpha:1),roughness:0.25,isMetallic:false)
            for i in 0..<32 {
                let drop=ModelEntity(mesh:mesh,materials:[material]);drop.position=[0,1.85,0];drop.scale=[0.035,0.07,0.035]
                parent.addChild(drop);waterDrops.append(drop)
                if UIAccessibility.isReduceMotionEnabled { let a=Float(i/4)*Float.pi/4,t=Float(i%4)/4;drop.position=[cos(a)*(0.12+1.35*t),1.85+2.5*t-3.9*t*t,sin(a)*(0.12+1.35*t)] }
            }
            ring(parent,radius:1.05,y:0.335,thickness:0.018,height:0.012,color:UIColor(red:0.70,green:0.86,blue:0.81,alpha:1))
            ring(parent,radius:0.8,y:0.335,thickness:0.012,height:0.012,color:UIColor(red:0.70,green:0.86,blue:0.81,alpha:1))
        }
        func decoratePlaza() {
            let stone=UIColor(red:0.79,green:0.76,blue:0.66,alpha:1)
            let green=UIColor(red:0.30,green:0.46,blue:0.34,alpha:1)
            let paving=Entity();paving.position=[0,0,18];root.addChild(paving)
            ring(paving,radius:2.5,y:0.055,thickness:0.12,height:0.025,color:stone)
            ring(paving,radius:3.6,y:0.055,thickness:0.14,height:0.025,color:stone)
            for x in -3...3 {
                box(root,[Float(x),0.055,19.5],[0.012,0.008,16],stone)
            }
            for x:Float in [-4.7,4.7] {
                for z:Float in [13,20,26] {
                    box(root,[x,0.18,z],[1.55,0.36,0.95],stone)
                    box(root,[x,0.38,z],[1.35,0.08,0.76],green)
                    for n in 0..<7 {
                        let px=x-0.53+Float(n%4)*0.34,pz=z-0.21+Float(n/4)*0.4
                        box(root,[px,0.56,pz],[0.035,0.36,0.035],green)
                        sphere(root,[px,0.76,pz],[0.14,0.08,0.14],n%2==0 ? UIColor(red:0.89,green:0.66,blue:0.62,alpha:1):UIColor(red:0.97,green:0.88,blue:0.65,alpha:1))
                        sphere(root,[px,0.81,pz],[0.05,0.025,0.05],.white)
                    }
                }
                for z:Float in [14.5,24.5] {
                    box(root,[x,1.35,z],[0.09,2.7,0.09],green)
                    box(root,[x,0.1,z],[0.42,0.2,0.42],stone)
                    let glow=ModelEntity(mesh:.generateBox(size:[0.32,0.48,0.32],cornerRadius:0.08),materials:[UnlitMaterial(color:.white)])
                    glow.position=[x,2.75,z];root.addChild(glow);lampGlow.append(glow)
                    box(root,[x,3.03,z],[0.48,0.09,0.48],green)
                    box(root,[x,2.49,z],[0.44,0.07,0.44],green)
                    if z == 24.5 {
                        let light=PointLight();light.position=[x,2.6,z];light.light.color=UIColor(red:1,green:0.79,blue:0.48,alpha:1);light.light.attenuationRadius=8;light.light.intensity=0
                        root.addChild(light);plazaLights.append(light)
                    }
                }
            }
        }
        func box(_ parent:Entity,_ p:SIMD3<Float>,_ size:SIMD3<Float>,_ color:UIColor) {
            let mesh:MeshResource
            if let cached=boxMeshes[size] { mesh=cached } else {
                mesh = .generateBox(size:size,cornerRadius:min(size.x,size.y,size.z)*0.2);boxMeshes[size]=mesh
            }
            let e=ModelEntity(mesh:mesh,materials:[SimpleMaterial(color:color,roughness:0.9,isMetallic:false)]); e.position=p; parent.addChild(e)
        }
        func sphere(_ parent:Entity,_ p:SIMD3<Float>,_ size:SIMD3<Float>,_ color:UIColor) {
            let e=ModelEntity(mesh:sharedSphere,materials:[SimpleMaterial(color:color,roughness:0.9,isMetallic:false)]); e.position=p; e.scale=size; parent.addChild(e)
        }
    }
}

struct ParkJoystick: View {
    let controls: ParkControls
    @State private var offset = CGSize.zero
    var body: some View {
        Circle().fill(.regularMaterial).frame(width:116,height:116)
            .overlay(Circle().stroke(.white.opacity(0.6),lineWidth:2))
            .overlay(Circle().fill(Palette.green.opacity(0.8)).frame(width:48,height:48).offset(offset))
            .gesture(DragGesture(minimumDistance:0).onChanged { value in
                controls.autoWalk = false
                controls.active = true
                let x=value.translation.width, y=value.translation.height
                let length=max(1,sqrt(x*x+y*y)/36)
                offset=CGSize(width:x/length,height:y/length)
                controls.movement=[Float(offset.width/36),Float(offset.height/36)]
            }.onEnded { _ in offset = .zero; controls.movement = .zero })
            .accessibilityElement(children: .ignore).accessibilityIdentifier("parkJoystick").accessibilityLabel("行走摇杆").accessibilityHint("拖动摇杆在纪念园中行走")
            .onDisappear { controls.movement = .zero }
    }
}

/// Town destinations are separate from the shared, stable monument indices.
enum TownPlace: String, CaseIterable, Identifiable {
    case plaza, memories, post, meadow
    var id:String { rawValue }
    var title:String { switch self { case .plaza:"入口广场"; case .memories:"记忆小屋"; case .post:"时光邮局"; case .meadow:"陪伴草地" } }
    var icon:String { switch self { case .plaza:"map";case .memories:"photo.on.rectangle.angled";case .post:"envelope";case .meadow:"pawprint" } }
    var detail:String { switch self { case .plaza:"从这里出发，去看看想念的伙伴";case .memories:"翻开照片，重温一起生活的日子";case .post:"把没说完的话，写进私密信箱";case .meadow:"散步、抚摸、追球，陪它待一会儿" } }
    var center:SIMD3<Float> { switch self { case .plaza:[0,0,18];case .memories:[-10,0,17];case .post:[-10,0,25];case .meadow:[11,0,18] } }
    var arrival:SIMD3<Float> { switch self { case .plaza:[0,0,24];case .memories:[-10,0,21];case .post:[-10,0,28];case .meadow:[11,0,22] } }
}
