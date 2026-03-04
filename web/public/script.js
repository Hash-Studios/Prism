/* ── Nav: add .scrolled class on scroll ──────────────────────── */
(function () {
  const nav = document.getElementById('nav');
  if (!nav) return;

  function updateNav() {
    if (window.scrollY > 20) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
  }

  window.addEventListener('scroll', updateNav, { passive: true });
  updateNav();
})();

/* ── Fade-up scroll animations (IntersectionObserver) ─────────── */
(function () {
  const elements = document.querySelectorAll('.fade-up');
  if (!elements.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: '0px 0px -40px 0px' }
  );

  elements.forEach((el) => observer.observe(el));

  // Immediately reveal hero elements since they're above the fold
  document.querySelectorAll('.hero .fade-up').forEach((el) => {
    el.classList.add('visible');
  });
})();

/* ── Screenshots: drag to scroll on desktop ───────────────────── */
(function () {
  const track = document.getElementById('screenshots-inner');
  if (!track) return;

  let isDown = false;
  let startX;
  let scrollLeft;

  track.addEventListener('mousedown', (e) => {
    isDown = true;
    track.style.cursor = 'grabbing';
    startX = e.pageX - track.offsetLeft;
    scrollLeft = track.scrollLeft;
  });

  track.addEventListener('mouseleave', () => {
    isDown = false;
    track.style.cursor = '';
  });

  track.addEventListener('mouseup', () => {
    isDown = false;
    track.style.cursor = '';
  });

  track.addEventListener('mousemove', (e) => {
    if (!isDown) return;
    e.preventDefault();
    const x = e.pageX - track.offsetLeft;
    const walk = (x - startX) * 1.5;
    track.scrollLeft = scrollLeft - walk;
  });
})();

/* ── Auto-scroll screenshots strip (slow, looping) ───────────── */
(function () {
  const track = document.getElementById('screenshots-inner');
  if (!track) return;

  let animationId;
  let isPaused = false;
  const speed = 0.5; // px per frame

  function step() {
    if (!isPaused) {
      track.scrollLeft += speed;
      // Loop back smoothly
      if (track.scrollLeft >= track.scrollWidth - track.clientWidth - 1) {
        track.scrollLeft = 0;
      }
    }
    animationId = requestAnimationFrame(step);
  }

  animationId = requestAnimationFrame(step);

  // Pause on hover / touch
  track.addEventListener('mouseenter', () => { isPaused = true; });
  track.addEventListener('mouseleave', () => { isPaused = false; });
  track.addEventListener('touchstart', () => { isPaused = true; }, { passive: true });
  track.addEventListener('touchend', () => {
    setTimeout(() => { isPaused = false; }, 2000);
  }, { passive: true });
})();
