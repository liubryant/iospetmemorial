import SwiftUI
import RealityKit
import UIKit

/// Original procedural assets: no third-party models, textures or runtime downloads.
struct GardenSceneView: UIViewRepresentable {
    let garden: MemorialGarden?
    var onTap: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }
    func makeUIView(context: Context) -> ARView {
        let view = GardenCanvas(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        view.didLayout = { [weak coordinator = context.coordinator] in coordinator?.positionCamera() }
        context.coordinator.attach(view)
        context.coordinator.refresh(garden)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.refresh(garden)
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.scene.anchors.removeAll() }
    final class Coordinator: NSObject {
        weak var view: ARView?
        var onTap: (String) -> Void
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        var pet = Entity()
        private var signature = ""
        private var azimuth: Float = 0.16
        private var elevation: Float = 0.55
        private var distance: Float = 7.8
        private var jumping = false
        init(onTap: @escaping (String) -> Void) { self.onTap = onTap }
        func attach(_ view: ARView) {
            self.view = view
            view.scene.addAnchor(anchor)
            anchor.addChild(camera)
            camera.camera.fieldOfViewInDegrees = 42
            view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
            view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
            view.accessibilityLabel = "可旋转缩放的三维纪念花园"
            view.accessibilityHint = "单指拖动旋转，双指缩放，轻触宠物互动"
            positionCamera()
        }
        func refresh(_ garden: MemorialGarden?) {
            let newSignature = "\(garden?.species ?? "cat")|\(garden?.theme ?? "sage")|\(garden?.photos.first?.id ?? "")|\(min(garden?.flowerCount ?? 0, 12))|\(min(garden?.candleCount ?? 0, 5))"
            guard signature != newSignature else { return }
            signature = newSignature
            // RealityKit may return different Swift wrappers for the same entity.
            // Reattach the retained camera explicitly after rebuilding content.
            for child in Array(anchor.children) { child.removeFromParent() }
            anchor.addChild(camera)
            positionCamera()
            let night = garden?.theme == "moon"
            let sunset = garden?.theme == "sunset"
            view?.environment.background = .color(night ? UIColor(red: 0.17, green: 0.23, blue: 0.28, alpha: 1) : sunset ? UIColor(red: 0.94, green: 0.85, blue: 0.77, alpha: 1) : UIColor(red: 0.89, green: 0.92, blue: 0.86, alpha: 1))
            view?.environment.lighting.intensityExponent = night ? 0.2 : 1.1
            let light = DirectionalLight()
            light.light.intensity = night ? 1300 : 3500
            light.light.color = sunset ? UIColor(red: 1, green: 0.85, blue: 0.65, alpha: 1) : .white
            light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 15, depthBias: 2)
            light.look(at: [0,0,0], from: [3,7,4], relativeTo: nil)
            anchor.addChild(light)
            let grass = UIColor(red: 0.59, green: 0.70, blue: 0.51, alpha: 1)
            sphere(anchor, at: [0,-0.26,0], scale: [3.1,0.28,2.55], color: UIColor(red: 0.65, green: 0.56, blue: 0.42, alpha: 1))
            sphere(anchor, at: [0,-0.08,0], scale: [3.1,0.14,2.55], color: grass)
            // Stepping stones lead from the entrance to the keepsake frame.
            for i in 0..<7 {
                let z = Float(i) * 0.42 - 0.8
                sphere(anchor, at: [sin(Float(i)*0.7)*0.24,0.055,z], scale: [0.33,0.045,0.22], color: UIColor(red: 0.88, green: 0.84, blue: 0.72, alpha: 1))
            }
            tree(at: [-1.9,0,-1.2], size: 1.0)
            tree(at: [1.9,0,-1.35], size: 0.85)
            tree(at: [-2.3,0,0.25], size: 0.60)
            // Low wooden fence at the back, with rounded posts.
            for i in -3...3 {
                box(anchor, at: [Float(i)*0.52,0.32,-2], size: [0.08,0.65,0.08], color: wood)
            }
            box(anchor, at: [0,0.25,-2], size: [3.3,0.065,0.06], color: wood)
            box(anchor, at: [0,0.53,-2], size: [3.3,0.065,0.06], color: wood)
            // Bench, sized for a quiet visit.
            let bench = Entity(); bench.position = [1.75,0,0.7]; bench.orientation = simd_quatf(angle: -0.35, axis: [0,1,0]); anchor.addChild(bench)
            box(bench, at: [0,0.42,0], size: [1.05,0.1,0.4], color: wood)
            box(bench, at: [0,0.72,-0.2], size: [1.05,0.35,0.07], color: wood)
            for x: Float in [-0.4,0.4] { box(bench, at: [x,0.2,0], size: [0.08,0.4,0.29], color: wood) }
            frame(photo: garden?.photos.first)
            buildPet(dog: garden?.species == "dog")
            // Wildflowers are decorative; offerings grow in their own bed.
            for i in 0..<14 {
                let angle = Float(i) * 2.399
                let x = cos(angle)*2.5, z = sin(angle)*1.9
                flower(at: [x,0.08,z], color: i % 2 == 0 ? UIColor(red: 0.98, green: 0.85, blue: 0.60, alpha: 1) : UIColor(red: 0.90, green: 0.68, blue: 0.66, alpha: 1))
            }
            for i in 0..<min(garden?.flowerCount ?? 0, 12) {
                flower(at: [-0.75 + Float(i%4)*0.16,0.08,-0.8 + Float(i/4)*0.16], color: .white)
            }
            for i in 0..<min(garden?.candleCount ?? 0, 5) {
                let x = 0.55 + Float(i)*0.18
                box(anchor, at: [x,0.18,-0.6], size: [0.1,0.24,0.1], color: UIColor(red: 1, green: 0.94, blue: 0.78, alpha: 1))
                var glow = UnlitMaterial(); glow.color = .init(tint: UIColor(red: 1, green: 0.68, blue: 0.19, alpha: 1))
                let flame = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [glow]); flame.scale = [0.7,1.7,0.7]; flame.position = [x,0.34,-0.6]; anchor.addChild(flame)
            }
        }
        private var wood: UIColor { UIColor(red: 0.61, green: 0.43, blue: 0.29, alpha: 1) }
        @discardableResult private func sphere(_ parent: Entity, at position: SIMD3<Float>, scale: SIMD3<Float>, color: UIColor) -> ModelEntity {
            let entity = ModelEntity(mesh: .generateSphere(radius: 1), materials: [SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)])
            entity.scale = scale; entity.position = position; parent.addChild(entity); return entity
        }
        @discardableResult private func box(_ parent: Entity, at position: SIMD3<Float>, size: SIMD3<Float>, color: UIColor) -> ModelEntity {
            let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(size.x, size.y, size.z)*0.18), materials: [SimpleMaterial(color: color, roughness: 0.85, isMetallic: false)])
            entity.position = position; parent.addChild(entity); return entity
        }
        private func tree(at p: SIMD3<Float>, size: Float) {
            let tree = Entity(); tree.position = p; tree.scale = .init(repeating: size); anchor.addChild(tree)
            box(tree, at: [0,0.7,0], size: [0.19,1.4,0.19], color: wood)
            sphere(tree, at: [0,1.5,0], scale: [0.62,0.75,0.61], color: UIColor(red: 0.35, green: 0.52, blue: 0.38, alpha: 1))
            sphere(tree, at: [0.3,1.3,0.18], scale: [0.45,0.5,0.45], color: UIColor(red: 0.46, green: 0.61, blue: 0.43, alpha: 1))
        }
        private func flower(at p: SIMD3<Float>, color: UIColor) {
            box(anchor, at: p + [0,0.10,0], size: [0.025,0.2,0.025], color: UIColor(red: 0.33, green: 0.46, blue: 0.27, alpha: 1))
            for i in 0..<5 {
                let a = Float(i)*Float.pi*2/5
                sphere(anchor, at: p + [cos(a)*0.065,0.21,sin(a)*0.065], scale: [0.065,0.025,0.065], color: color)
            }
            sphere(anchor, at: p + [0,0.23,0], scale: [0.032,0.025,0.032], color: .systemYellow)
        }
        private func frame(photo: MemoryPhoto?) {
            let frame = Entity(); frame.name = "photo"; frame.position = [0,0.05,-1.15]; anchor.addChild(frame)
            box(frame, at: [0,0.45,0], size: [0.12,0.9,0.12], color: wood)
            box(frame, at: [0,1.1,0], size: [1.04,0.86,0.12], color: wood)
            let surface = box(frame, at: [0,1.1,0.07], size: [0.89,0.71,0.015], color: UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 1))
            if let photo, let data = Data(base64Encoded: photo.imageBase64), let image = UIImage(data: data) {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let cropped = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 400), format: format).image { _ in
                    let ratio = max(500/image.size.width,400/image.size.height)
                    let size = CGSize(width: image.size.width*ratio, height: image.size.height*ratio)
                    image.draw(in: CGRect(x: (500-size.width)/2, y: (400-size.height)/2, width: size.width, height: size.height))
                }
                if let cg = cropped.cgImage, let texture = try? TextureResource.generate(from: cg, options: .init(semantic: .color)) {
                    var material = UnlitMaterial(); material.color = .init(texture: .init(texture))
                    surface.model?.materials = [material]
                }
            } else {
                // Paw motif in the empty picture frame.
                sphere(frame, at: [0,1.04,0.11], scale: [0.15,0.12,0.02], color: wood)
                for x: Float in [-0.18,-0.06,0.06,0.18] { sphere(frame, at: [x,1.22 + (abs(x)<0.1 ? 0.06 : 0),0.11], scale: [0.055,0.07,0.02], color: wood) }
            }
            frame.generateCollisionShapes(recursive: true)
        }
        private func buildPet(dog: Bool) {
            pet = Entity(); pet.name = "pet"; pet.position = [-0.9,0.08,0.55]; pet.orientation = simd_quatf(angle: 0.15, axis: [0,1,0]); anchor.addChild(pet)
            let fur = dog ? UIColor(red: 0.80, green: 0.61, blue: 0.40, alpha: 1) : UIColor(red: 0.93, green: 0.82, blue: 0.64, alpha: 1)
            sphere(pet, at: [0,0.29,0], scale: [0.28,0.36,0.32], color: fur)
            sphere(pet, at: [0,0.67,0.12], scale: [0.32,0.29,0.28], color: fur)
            sphere(pet, at: [0,0.56,0.34], scale: [0.20,0.12,0.12], color: .init(white: 0.97, alpha: 1))
            for x: Float in [-0.15,0.15] {
                sphere(pet, at: [x,0.08,0.2], scale: [0.12,0.08,0.18], color: fur)
                let ear = sphere(pet, at: [x*1.5, dog ? 0.69 : 0.93,0.07], scale: dog ? [0.105,0.23,0.14] : [0.12,0.19,0.08], color: fur)
                ear.orientation = simd_quatf(angle: x*2, axis: [0,0,1])
                sphere(pet, at: [x*0.85,0.70,0.365], scale: [0.035,0.044,0.025], color: UIColor(white: 0.16, alpha: 1))
                sphere(pet, at: [x*0.85-0.009,0.715,0.386], scale: [0.009,0.012,0.008], color: .white)
            }
            sphere(pet, at: [0,0.60,0.455], scale: [0.038,0.026,0.02], color: dog ? .darkGray : .systemPink)
            let tail = sphere(pet, at: [0.28,0.26,-0.3], scale: [0.08,0.09,0.36], color: fur)
            tail.orientation = simd_quatf(angle: -0.6, axis: [1,0,0])
            sphere(pet, at: [0,0.40,0.01], scale: [0.27,0.04,0.30], color: UIColor(red: 0.37, green: 0.53, blue: 0.44, alpha: 1))
            sphere(pet, at: [0,0.37,0.30], scale: [0.045,0.05,0.018], color: .systemYellow)
            pet.generateCollisionShapes(recursive: true)
        }
        func positionCamera() {
            let size = view?.bounds.size ?? .zero
            let aspect = size.height > 0 ? Float(size.width / size.height) : 0.9
            let fittedDistance = distance * max(1, 0.9 / max(0.35, aspect))
            camera.look(at: [0,0.55,0], from: [sin(azimuth)*fittedDistance*cos(elevation), sin(elevation)*fittedDistance, cos(azimuth)*fittedDistance*cos(elevation)], relativeTo: nil)
        }
        @objc private func pan(_ gesture: UIPanGestureRecognizer) {
            let delta = gesture.translation(in: view)
            azimuth -= Float(delta.x)*0.007
            elevation = max(0.18, min(1.12, elevation + Float(delta.y)*0.004))
            gesture.setTranslation(.zero, in: view); positionCamera()
        }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
            distance = max(4.2,min(11,distance/Float(gesture.scale))); gesture.scale = 1; positionCamera()
        }
        @objc private func tap(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            var target = view.entity(at: gesture.location(in: view))
            while let entity = target {
                if entity.name == "photo" { onTap("photo"); return }
                if entity.name == "pet" {
                    onTap("pet")
                    guard !jumping else { return }
                    jumping = true
                    let resting = pet.transform
                    var raised = resting; raised.translation.y += 0.2; raised.scale = [1.05,1.05,1.05]
                    pet.move(to: raised, relativeTo: anchor, duration: 0.25, timingFunction: .easeOut)
                    let animatedPet = pet
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { [weak self, weak animatedPet] in
                        guard let self else { return }
                        animatedPet?.move(to: resting, relativeTo: self.anchor, duration: 0.3, timingFunction: .easeInOut)
                        self.jumping = false
                    }
                    return
                }
                target = entity.parent
            }
        }
    }
}

private final class GardenCanvas: ARView {
    var didLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        didLayout?()
    }
}
