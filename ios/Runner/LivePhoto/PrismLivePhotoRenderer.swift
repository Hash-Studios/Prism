import CoreVideo
import Metal
import MetalKit

/// Renders one frame of a live style into a BGRA pixel buffer on the GPU.
///
/// The styles mirror the Android shaders in `live_shader_sources.dart`, but every motion is a function of
/// `sin(phase)` and `sin(2 phase)`. So the first, middle and last frames show the same picture, and the key photo
/// (the middle frame) matches where the clip starts and ends.
final class PrismLivePhotoRenderer {
  private struct Uniforms {
    var tint: SIMD4<Float>
    var phase: Float
    var aspect: Float
    var padding: SIMD2<Float> = .zero
  }

  private let queue: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  private let textureCache: CVMetalTextureCache
  private let photo: MTLTexture
  private let depth: MTLTexture?
  private let tint: SIMD4<Float>

  init(style: LivePhotoStyle, photoURL: URL, depthURL: URL?, tint: SIMD4<Float>) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw PrismLivePhotoFailure.renderFailed
    }
    if style == .depth && depthURL == nil { throw PrismLivePhotoFailure.invalidRequest }
    var cache: CVMetalTextureCache?
    guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess, let cache else {
      throw PrismLivePhotoFailure.renderFailed
    }
    do {
      let library = try device.makeLibrary(source: Self.source, options: nil)
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name: "live_vertex")
      descriptor.fragmentFunction = library.makeFunction(name: Self.fragmentName(style))
      descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
      pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
      let loader = MTKTextureLoader(device: device)
      let options: [MTKTextureLoader.Option: Any] = [
        .SRGB: false,
        .origin: MTKTextureLoader.Origin.topLeft,
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
      ]
      photo = try loader.newTexture(URL: photoURL, options: options)
      depth = try depthURL.map { try loader.newTexture(URL: $0, options: options) }
    } catch {
      throw PrismLivePhotoFailure.renderFailed
    }
    self.queue = queue
    self.textureCache = cache
    self.tint = tint
  }

  /// Draws the frame at [phase] (0 to 1 over the clip) and waits for the GPU.
  func render(phase: Float, into pixelBuffer: CVPixelBuffer) throws {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    var cvTexture: CVMetalTexture?
    guard CVMetalTextureCacheCreateTextureFromImage(
      nil, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTexture
    ) == kCVReturnSuccess,
      let cvTexture, let target = CVMetalTextureGetTexture(cvTexture),
      let commands = queue.makeCommandBuffer()
    else { throw PrismLivePhotoFailure.renderFailed }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .dontCare
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      throw PrismLivePhotoFailure.renderFailed
    }
    var uniforms = Uniforms(tint: tint, phase: phase, aspect: Float(width) / Float(height))
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
    encoder.setFragmentTexture(photo, index: 0)
    encoder.setFragmentTexture(depth ?? photo, index: 1)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()
    withExtendedLifetime(cvTexture) {}
    if commands.status != .completed { throw PrismLivePhotoFailure.renderFailed }
  }

  private static func fragmentName(_ style: LivePhotoStyle) -> String {
    switch style {
    case .drift: return "live_drift"
    case .breathe: return "live_breathe"
    case .shimmer: return "live_shimmer"
    case .depth: return "live_depth"
    }
  }

  // `uv` has its origin at the bottom left, as in the GLSL sources. Textures have theirs at the top left.
  private static let source = """
  #include <metal_stdlib>
  using namespace metal;

  constant float TAU = 6.2831853;

  struct VOut {
    float4 position [[position]];
    float2 uv;
  };

  struct Uniforms {
    float4 tint;
    float phase;
    float aspect;
    float2 padding;
  };

  constexpr sampler linearClamp(filter::linear, address::clamp_to_edge);

  float3 photoAt(texture2d<float> t, float2 st) {
    return t.sample(linearClamp, float2(st.x, 1.0 - st.y)).rgb;
  }

  vertex VOut live_vertex(uint id [[vertex_id]]) {
    float2 p = float2(float((id << 1) & 2), float(id & 2));
    VOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    out.uv = p;
    return out;
  }

  fragment float4 live_drift(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                             texture2d<float> photo [[texture(0)]]) {
    float a = TAU * u.phase;
    float zoom = 1.12 + 0.03 * sin(a);
    float2 pan = float2(sin(a), sin(2.0 * a)) * 0.022;
    float2 st = (in.uv - 0.5) / zoom + 0.5 + pan;
    return float4(photoAt(photo, st), 1.0);
  }

  fragment float4 live_breathe(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                               texture2d<float> photo [[texture(0)]]) {
    float pulse = sin(TAU * u.phase);
    float zoom = 1.08 + 0.025 * pulse;
    float2 st = (in.uv - 0.5) / zoom + 0.5;
    float3 col = photoAt(photo, st) * (1.0 + 0.035 * pulse);
    return float4(clamp(col, 0.0, 1.0), 1.0);
  }

  // Two sweeps. The band is off screen at the start, the middle and the end, so the key photo has no glow.
  fragment float4 live_shimmer(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                               texture2d<float> photo [[texture(0)]]) {
    float2 uv = in.uv;
    float2 st = (uv - 0.5) / 1.05 + 0.5;
    float3 col = photoAt(photo, st);
    float sweep = smoothstep(0.0, 1.0, fract(u.phase * 2.0));
    float centre = -0.6 + sweep * 2.6;
    float diag = uv.x * 0.6 + uv.y * 0.8;
    float k = (diag - centre) * 5.0;
    float band = exp(-k * k);
    float3 glow = mix(float3(1.0), u.tint.rgb, 0.25) * band * 0.2;
    col = 1.0 - (1.0 - col) * (1.0 - glow);
    return float4(clamp(col, 0.0, 1.0), 1.0);
  }

  // The largest shift is strength / 2, under the 0.019 margin the 4% zoom leaves.
  fragment float4 live_depth(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                             texture2d<float> photo [[texture(0)]], texture2d<float> depthMap [[texture(1)]]) {
    float a = TAU * u.phase;
    float2 uv = (in.uv - 0.5) / 1.04 + 0.5;
    float2 motion = float2(sin(a), 0.5 * sin(2.0 * a));
    float depth = photoAt(depthMap, uv).r;
    float2 st = uv + (depth - 0.5) * 0.03 * motion;
    return float4(photoAt(photo, st), 1.0);
  }
  """
}
