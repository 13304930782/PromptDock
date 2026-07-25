import { useEffect, useRef } from 'react';
import { Renderer, Program, Mesh, Triangle } from 'ogl';
import './Plasma.css';

const hexToRgb = (hex) => {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if (!result) return [0.45, 0.78, 0.36];
  return [
    parseInt(result[1], 16) / 255,
    parseInt(result[2], 16) / 255,
    parseInt(result[3], 16) / 255,
  ];
};

const vertex = `#version 300 es
precision highp float;
in vec2 position;
in vec2 uv;
out vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = vec4(position, 0.0, 1.0);
}`;

const fragment = `#version 300 es
precision highp float;
uniform vec2 iResolution;
uniform float iTime;
uniform vec3 uCustomColor;
uniform float uSpeed;
uniform float uScale;
uniform float uOpacity;
uniform vec2 uMouse;
uniform float uMouseInteractive;
uniform float uQuality;
uniform float uStepScale;
out vec4 fragColor;

void mainImage(out vec4 o, vec2 C) {
  vec2 center = iResolution.xy * 0.5;
  C = (C - center) / uScale + center;
  vec2 mouseOffset = (uMouse - center) * 0.0002;
  C += mouseOffset * length(C - center) * step(0.5, uMouseInteractive);
  float i, d, z, T = iTime * uSpeed;
  vec3 O, p, S;
  for (vec2 r = iResolution.xy, Q; ++i < 60.0; O += o.w/d*o.xyz) {
    p = z*normalize(vec3(C-.5*r,r.y));
    p.z -= 4.;
    S = p;
    d = p.y-T;
    p.x += .4*(1.+p.y)*sin(d + p.x*0.1)*cos(.34*d + p.x*0.05);
    Q = p.xz *= mat2(cos(p.y+vec4(0,11,33,0)-T));
    z += d = (abs(sqrt(length(Q*Q)) - .25*(5.+S.y))/3.+8e-4) * uStepScale;
    o = 1.+sin(S.y+p.z*.5+S.z-length(S-p)+vec4(2,1,0,8));
    if (i >= uQuality) break;
  }
  o.xyz = tanh(O/1e4);
}

bool finite1(float x){ return !(isnan(x) || isinf(x)); }
vec3 sanitize(vec3 c){
  return vec3(finite1(c.r) ? c.r : 0.0, finite1(c.g) ? c.g : 0.0, finite1(c.b) ? c.b : 0.0);
}

void main() {
  vec4 o = vec4(0.0);
  mainImage(o, gl_FragCoord.xy);
  vec3 rgb = sanitize(o.rgb);
  float intensity = (rgb.r + rgb.g + rgb.b) / 3.0;
  vec3 finalColor = intensity * uCustomColor;
  float alpha = length(rgb) * uOpacity;
  fragColor = vec4(finalColor, alpha);
}`;

export default function Plasma({
  color = '#75c866',
  speed = 0.45,
  scale = 1.08,
  opacity = 0.72,
  mouseInteractive = true,
  renderScale = 0.55,
  maxDpr = 1.5,
  targetFps = 30,
  iterations = 48,
}) {
  const containerRef = useRef(null);
  const pendingMouse = useRef(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    let renderer;
    try {
      renderer = new Renderer({
        webgl: 2,
        alpha: true,
        antialias: false,
        dpr: Math.min(window.devicePixelRatio || 1, maxDpr),
      });
    } catch {
      container.dataset.fallback = 'true';
      return undefined;
    }

    const gl = renderer.gl;
    if (!gl) return undefined;
    const canvas = gl.canvas;
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    container.appendChild(canvas);

    const geometry = new Triangle(gl);
    const colorValue = hexToRgb(color);
    const program = new Program(gl, {
      vertex,
      fragment,
      uniforms: {
        iTime: { value: 0 },
        iResolution: { value: new Float32Array([1, 1]) },
        uCustomColor: { value: new Float32Array(colorValue) },
        uSpeed: { value: speed * 0.4 },
        uScale: { value: scale },
        uOpacity: { value: opacity },
        uMouse: { value: new Float32Array([0, 0]) },
        uMouseInteractive: { value: mouseInteractive ? 1 : 0 },
        uQuality: { value: iterations },
        uStepScale: { value: 60 / iterations },
      },
    });
    const mesh = new Mesh(gl, { geometry, program });

    const setSize = () => {
      const rect = container.getBoundingClientRect();
      renderer.setSize(
        Math.max(1, Math.floor(rect.width * renderScale)),
        Math.max(1, Math.floor(rect.height * renderScale)),
      );
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      program.uniforms.iResolution.value[0] = gl.drawingBufferWidth;
      program.uniforms.iResolution.value[1] = gl.drawingBufferHeight;
    };

    let resizeFrame = 0;
    const resizeObserver = new ResizeObserver(() => {
      cancelAnimationFrame(resizeFrame);
      resizeFrame = requestAnimationFrame(setSize);
    });
    resizeObserver.observe(container);
    setSize();

    const onMouseMove = (event) => {
      const rect = container.getBoundingClientRect();
      pendingMouse.current = {
        x: event.clientX - rect.left,
        y: rect.height - (event.clientY - rect.top),
      };
    };
    if (mouseInteractive) container.addEventListener('mousemove', onMouseMove, { passive: true });

    let raf = 0;
    let visible = true;
    let tabVisible = document.visibilityState !== 'hidden';
    let contextLost = false;
    let lastFrame = 0;
    const startedAt = performance.now();
    const frameInterval = 1000 / targetFps;

    const render = (time) => {
      if (contextLost || !visible || !tabVisible) return;
      if (time - lastFrame < frameInterval) {
        raf = requestAnimationFrame(render);
        return;
      }
      lastFrame = time;
      if (pendingMouse.current) {
        program.uniforms.uMouse.value[0] = pendingMouse.current.x;
        program.uniforms.uMouse.value[1] = pendingMouse.current.y;
        pendingMouse.current = null;
      }
      program.uniforms.iTime.value = (time - startedAt) * 0.001;
      renderer.render({ scene: mesh });
      raf = requestAnimationFrame(render);
    };

    const renderStatic = () => {
      program.uniforms.iTime.value = 0;
      renderer.render({ scene: mesh });
    };
    const onContextLost = (event) => {
      event.preventDefault();
      contextLost = true;
      cancelAnimationFrame(raf);
      container.dataset.fallback = 'true';
    };
    const onContextRestored = () => {
      contextLost = false;
      delete container.dataset.fallback;
      if (!reducedMotion && visible && tabVisible) raf = requestAnimationFrame(render);
    };
    canvas.addEventListener('webglcontextlost', onContextLost);
    canvas.addEventListener('webglcontextrestored', onContextRestored);

    const intersection = new IntersectionObserver(([entry]) => {
      const wasVisible = visible;
      visible = entry.isIntersecting;
      if (visible && !wasVisible && !reducedMotion && tabVisible && !contextLost) {
        raf = requestAnimationFrame(render);
      } else if (!visible) {
        cancelAnimationFrame(raf);
      }
    });
    intersection.observe(container);

    const onVisibility = () => {
      tabVisible = document.visibilityState !== 'hidden';
      if (tabVisible && visible && !reducedMotion && !contextLost) {
        lastFrame = 0;
        raf = requestAnimationFrame(render);
      } else {
        cancelAnimationFrame(raf);
      }
    };
    document.addEventListener('visibilitychange', onVisibility);

    if (reducedMotion) renderStatic();
    else raf = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(raf);
      cancelAnimationFrame(resizeFrame);
      resizeObserver.disconnect();
      intersection.disconnect();
      document.removeEventListener('visibilitychange', onVisibility);
      canvas.removeEventListener('webglcontextlost', onContextLost);
      canvas.removeEventListener('webglcontextrestored', onContextRestored);
      if (mouseInteractive) container.removeEventListener('mousemove', onMouseMove);
      canvas.remove();
    };
  }, [color, speed, scale, opacity, mouseInteractive, renderScale, maxDpr, targetFps, iterations]);

  return <div ref={containerRef} className="plasma-container" aria-hidden="true" />;
}
