/**
 * Promo Landing — Background Animation
 * Replicates TwoSpoon.ai style:
 *   • Animated white dot-grid mesh (subtle, crisp)
 *   • Floating warm-yellow/lime glow orbs
 *   • Mouse-repulsion on dots
 *
 * Uses: [data-grid-target="true"] as mount points
 * Self-contained, no external dependencies.
 */
(function (global) {
  'use strict';

  /* ─── Palette & Config ─────────────────────────────────────────────────── */
  var CFG = {
    // Dot grid
    spacing:    28,     // grid spacing in CSS px
    dotR:       1.2,    // dot radius in CSS px
    dotAlpha:   0.28,   // base dot opacity

    // Mouse ripple
    mouseR:     120,    // influence radius (CSS px)
    mousePush:  0.12,   // push strength (fraction of spacing)

    // Floating glow orbs  (matching TwoSpoon palette)
    orbs: [
      { rx: 0.10, ry: 0.62, r: 260, h: 50, s: 85, l: 62, a: 0.48, sp: 0.00030 },
      { rx: 0.88, ry: 0.55, r: 240, h: 54, s: 80, l: 58, a: 0.45, sp: 0.00025 },
      { rx: 0.50, ry: 0.15, r: 200, h: 47, s: 75, l: 66, a: 0.40, sp: 0.00019 },
      { rx: 0.20, ry: 0.88, r: 170, h: 52, s: 78, l: 60, a: 0.38, sp: 0.00036 },
      { rx: 0.80, ry: 0.10, r: 155, h: 56, s: 82, l: 55, a: 0.35, sp: 0.00015 },
    ],
  };

  /* ─── Internal state ────────────────────────────────────────────────────── */
  var instances = [];
  var t0 = performance.now();
  var rafId = null;

  /* ─── Build a canvas inside a container ────────────────────────────────── */
  function mount(container) {
    var cv = document.createElement('canvas');
    cv.style.cssText = [
      'position:absolute',
      'top:0',
      'left:0',
      'width:100%',
      'height:100%',
      'pointer-events:none',
      'display:block',
      'z-index:0',
    ].join(';');
    container.appendChild(cv);

    var mouse = { x: -9999, y: -9999 };

    // Track mouse relative to this container
    document.addEventListener('mousemove', function (e) {
      var rect = container.getBoundingClientRect();
      mouse.x = e.clientX - rect.left;
      mouse.y = e.clientY - rect.top;
    });

    var inst = { cv: cv, mouse: mouse, dpr: 1 };
    fitCanvas(inst, container);

    if (window.ResizeObserver) {
      new ResizeObserver(function () { fitCanvas(inst, container); }).observe(container);
    } else {
      window.addEventListener('resize', function () { fitCanvas(inst, container); });
    }

    instances.push(inst);
  }

  /* ─── Size canvas to container (DPR-aware) ──────────────────────────────── */
  function fitCanvas(inst, container) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    inst.dpr = dpr;
    var rect = container.getBoundingClientRect();
    inst.cv.width  = Math.round(rect.width  * dpr);
    inst.cv.height = Math.round(rect.height * dpr);
  }

  /* ─── Render one frame for one canvas ──────────────────────────────────── */
  function draw(inst, elapsed) {
    var cv   = inst.cv;
    var dpr  = inst.dpr;
    var W    = cv.width;
    var H    = cv.height;
    var ctx  = cv.getContext('2d');
    if (!W || !H) return;

    ctx.clearRect(0, 0, W, H);

    /* Pre-compute orb world positions */
    var orbPos = CFG.orbs.map(function (o, i) {
      var phase = elapsed * o.sp + i * 1.618;
      return {
        cx: (o.rx + Math.sin(phase * 1.07) * 0.07) * W,
        cy: (o.ry + Math.cos(phase * 0.85) * 0.06) * H,
        r:  o.r * dpr,
        h:  o.h, s: o.s, l: o.l, a: o.a,
        fadeR: o.r * dpr * 0.58,
      };
    });

    /* 1 ─ Orbs */
    orbPos.forEach(function (o) {
      var g = ctx.createRadialGradient(o.cx, o.cy, 0, o.cx, o.cy, o.r);
      g.addColorStop(0,    'hsla(' + o.h + ',' + o.s + '%,' + o.l + '%,' + o.a + ')');
      g.addColorStop(0.45, 'hsla(' + o.h + ',' + o.s + '%,' + o.l + '%,' + (o.a * 0.22).toFixed(3) + ')');
      g.addColorStop(1,    'hsla(' + o.h + ',' + o.s + '%,' + o.l + '%,0)');
      ctx.beginPath();
      ctx.arc(o.cx, o.cy, o.r, 0, 6.2832);
      ctx.fillStyle = g;
      ctx.fill();
    });

    /* 2 ─ Dot grid */
    var sp  = CFG.spacing * dpr;
    var dr  = CFG.dotR    * dpr;
    var mR  = CFG.mouseR  * dpr;
    var mx  = inst.mouse.x * dpr;
    var my  = inst.mouse.y * dpr;
    var cols = Math.ceil(W / sp) + 1;
    var rows = Math.ceil(H / sp) + 1;

    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= cols; col++) {
        var bx = col * sp;
        var by = row * sp;

        /* Mouse push */
        var dx = bx - mx, dy = by - my;
        var d2 = dx * dx + dy * dy;
        var wx = bx, wy = by;
        if (d2 < mR * mR && d2 > 0.01) {
          var d    = Math.sqrt(d2);
          var push = (1 - d / mR) * CFG.mousePush * sp;
          wx = bx + (dx / d) * push;
          wy = by + (dy / d) * push;
        }

        /* Alpha: fade inside orb cores */
        var alpha = CFG.dotAlpha;
        for (var k = 0; k < orbPos.length; k++) {
          var o = orbPos[k];
          var odx = bx - o.cx, ody = by - o.cy;
          var od = Math.sqrt(odx * odx + ody * ody);
          if (od < o.fadeR) {
            alpha -= 0.20 * (1 - od / o.fadeR);
          }
        }
        if (alpha < 0.04) alpha = 0.04;

        ctx.fillStyle = 'rgba(255,255,255,' + alpha.toFixed(3) + ')';
        ctx.beginPath();
        ctx.arc(wx, wy, dr, 0, 6.2832);
        ctx.fill();
      }
    }
  }

  /* ─── Main loop ─────────────────────────────────────────────────────────── */
  function loop() {
    var elapsed = performance.now() - t0;
    for (var i = 0; i < instances.length; i++) {
      draw(instances[i], elapsed);
    }
    rafId = requestAnimationFrame(loop);
  }

  /* ─── Init ───────────────────────────────────────────────────────────────── */
  function init() {
    var targets = document.querySelectorAll('[data-grid-target="true"]');
    if (!targets.length) return;
    for (var i = 0; i < targets.length; i++) {
      mount(targets[i]);
    }
    loop();
  }

  /* ─── Boot ───────────────────────────────────────────────────────────────── */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    // Already loaded — defer one tick so DOM is stable
    setTimeout(init, 0);
  }

}(window));
