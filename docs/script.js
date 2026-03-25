/* ============================================
   DANTE TERMINAL — Landing Page Scripts
   Typewriter effect + form handling
   ============================================ */

(function () {
  'use strict';

  // --- Typewriter Effect ---
  function typewrite(element, text, speed, callback) {
    let i = 0;
    element.textContent = '';
    element.classList.remove('done');

    function tick() {
      if (i < text.length) {
        element.textContent += text.charAt(i);
        i++;
        setTimeout(tick, speed);
      } else {
        element.classList.add('done');
        if (callback) callback();
      }
    }
    tick();
  }

  // Run typewriter on hero lines sequentially
  function initTypewriter() {
    var lines = document.querySelectorAll('[data-typewriter]');
    var idx = 0;

    function nextLine() {
      if (idx >= lines.length) {
        // Show the cursor block at the end
        var endCursor = document.getElementById('end-cursor');
        if (endCursor) endCursor.style.display = 'inline-block';
        return;
      }
      var el = lines[idx];
      var text = el.getAttribute('data-typewriter');
      var speed = parseInt(el.getAttribute('data-speed') || '40', 10);
      el.style.visibility = 'visible';
      typewrite(el, text, speed, function () {
        idx++;
        setTimeout(nextLine, 200);
      });
    }

    // Hide all lines initially, then start
    lines.forEach(function (el) {
      el.style.visibility = 'hidden';
    });
    // Small delay so the page paints first
    setTimeout(nextLine, 500);
  }

  // --- Buttondown Form Handling ---
  function initForm() {
    var form = document.getElementById('signup-form');
    var successMsg = document.getElementById('signup-success');
    if (!form) return;

    form.addEventListener('submit', function (e) {
      // Buttondown handles the actual submission via form action.
      // For a non-Buttondown fallback (mailto), we handle it here.
      var emailInput = form.querySelector('input[type="email"]');
      if (!emailInput || !emailInput.value) {
        e.preventDefault();
        return;
      }

      // If using Buttondown, let the form submit naturally.
      // The form's action points to Buttondown's API.
      // Show a local success message optimistically.
      if (successMsg) {
        setTimeout(function () {
          form.style.display = 'none';
          successMsg.classList.add('visible');
        }, 100);
      }
    });
  }

  // --- Fade-in on scroll ---
  function initScrollReveal() {
    var sections = document.querySelectorAll('.terminal-box, .signup, .stores');
    if (!('IntersectionObserver' in window)) {
      // Fallback: just show everything
      sections.forEach(function (s) { s.style.opacity = '1'; });
      return;
    }

    sections.forEach(function (s) {
      s.style.opacity = '0';
      s.style.transition = 'opacity 0.6s ease';
    });

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15 });

    sections.forEach(function (s) { observer.observe(s); });
  }

  // --- Init ---
  document.addEventListener('DOMContentLoaded', function () {
    initTypewriter();
    initForm();
    initScrollReveal();
  });
})();
