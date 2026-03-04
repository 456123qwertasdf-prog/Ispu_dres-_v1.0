(function() {
    'use strict';
    var SU_TOUR_STEPS = window.SU_TOUR_STEPS || [];
    var suTourIndex = 0;
    var suTourOverlay = null;
    var suTourPopover = null;
    var suTourHighlightRing = null;
    var suTourSpotTop = null;
    var suTourSpotLeft = null;
    var suTourSpotRight = null;
    var suTourSpotBottom = null;
    var suTourResizeHandler = null;
    var PAD = 10;
    var OVERLAP = 2;

    function suTourPositionSpotlight(el) {
        var r = el && el.getBoundingClientRect ? el.getBoundingClientRect() : null;
        var vw = window.innerWidth;
        var vh = window.innerHeight;
        var left = r ? (r.left - PAD) : 0;
        var top = r ? (r.top - PAD) : 0;
        var w = r ? (r.width + PAD * 2) : 0;
        var h = r ? (r.height + PAD * 2) : 0;
        if (suTourSpotTop) {
            suTourSpotTop.style.left = '0'; suTourSpotTop.style.top = '0'; suTourSpotTop.style.right = '0';
            suTourSpotTop.style.height = Math.max(0, top + OVERLAP) + 'px';
        }
        if (suTourSpotBottom) {
            suTourSpotBottom.style.left = '0'; suTourSpotBottom.style.right = '0'; suTourSpotBottom.style.bottom = '0';
            suTourSpotBottom.style.top = (top + h - OVERLAP) + 'px';
            suTourSpotBottom.style.height = Math.max(0, vh - (top + h) + OVERLAP) + 'px';
        }
        if (suTourSpotLeft) {
            suTourSpotLeft.style.left = '0'; suTourSpotLeft.style.top = (top + OVERLAP) + 'px';
            suTourSpotLeft.style.width = Math.max(0, left + OVERLAP) + 'px';
            suTourSpotLeft.style.height = Math.max(0, h - OVERLAP * 2) + 'px';
        }
        if (suTourSpotRight) {
            suTourSpotRight.style.right = '0'; suTourSpotRight.style.top = (top + OVERLAP) + 'px';
            suTourSpotRight.style.width = Math.max(0, vw - (left + w) + OVERLAP) + 'px';
            suTourSpotRight.style.height = Math.max(0, h - OVERLAP * 2) + 'px';
        }
    }

    function suTourPositionRing(el) {
        if (!suTourHighlightRing) return;
        if (!el || !el.getBoundingClientRect) {
            suTourHighlightRing.style.display = 'none';
            return;
        }
        var r = el.getBoundingClientRect();
        suTourHighlightRing.style.display = 'block';
        suTourHighlightRing.style.left = (r.left - PAD) + 'px';
        suTourHighlightRing.style.top = (r.top - PAD) + 'px';
        suTourHighlightRing.style.width = (r.width + PAD * 2) + 'px';
        suTourHighlightRing.style.height = (r.height + PAD * 2) + 'px';
    }

    function suTourClose() {
        if (suTourHighlightRing && suTourHighlightRing.parentNode) suTourHighlightRing.parentNode.removeChild(suTourHighlightRing);
        if (suTourResizeHandler) {
            window.removeEventListener('resize', suTourResizeHandler);
            window.removeEventListener('scroll', suTourResizeHandler, true);
        }
        if (suTourOverlay && suTourOverlay.parentNode) suTourOverlay.parentNode.removeChild(suTourOverlay);
        if (suTourPopover && suTourPopover.parentNode) suTourPopover.parentNode.removeChild(suTourPopover);
        suTourHighlightRing = null;
        suTourSpotTop = suTourSpotLeft = suTourSpotRight = suTourSpotBottom = null;
        suTourOverlay = null;
        suTourPopover = null;
        suTourResizeHandler = null;
        suTourIndex = 0;
    }

    function suTourShowStep(i) {
        if (i < 0 || i >= SU_TOUR_STEPS.length) { suTourClose(); return; }
        suTourIndex = i;
        var step = SU_TOUR_STEPS[i];
        var el = document.querySelector(step.sel);
        if (el) {
            el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        if (!suTourPopover) return;
        suTourPopover.querySelector('.su-tour-title').textContent = step.title;
        suTourPopover.querySelector('.su-tour-desc').textContent = step.desc;
        suTourPopover.querySelector('.su-tour-progress').textContent = (i + 1) + ' of ' + SU_TOUR_STEPS.length;
        suTourPopover.querySelector('.su-tour-prev').disabled = i === 0;
        suTourPopover.querySelector('.su-tour-next').textContent = i === SU_TOUR_STEPS.length - 1 ? 'Done' : 'Next →';
        function updateSpotlight() {
            suTourPositionSpotlight(el);
            if (suTourHighlightRing) {
                if (el) {
                    suTourPositionRing(el);
                } else {
                    suTourHighlightRing.style.display = 'none';
                }
            }
        }
        if (el) {
            requestAnimationFrame(updateSpotlight);
            setTimeout(updateSpotlight, 400);
            if (!suTourResizeHandler) {
                suTourResizeHandler = function() {
                    var stepEl = document.querySelector(SU_TOUR_STEPS[suTourIndex].sel);
                    if (stepEl) {
                        suTourPositionSpotlight(stepEl);
                        suTourPositionRing(stepEl);
                    }
                };
                window.addEventListener('resize', suTourResizeHandler);
                window.addEventListener('scroll', suTourResizeHandler, true);
            }
        } else {
            suTourPositionSpotlight(null);
            if (suTourHighlightRing) suTourHighlightRing.style.display = 'none';
        }
    }

    function startSuperUserTour() {
        if (!SU_TOUR_STEPS.length) return;
        suTourClose();
        suTourOverlay = document.createElement('div');
        suTourOverlay.className = 'su-tour-overlay';
        suTourSpotTop = document.createElement('div');
        suTourSpotLeft = document.createElement('div');
        suTourSpotRight = document.createElement('div');
        suTourSpotBottom = document.createElement('div');
        [suTourSpotTop, suTourSpotLeft, suTourSpotRight, suTourSpotBottom].forEach(function(panel) {
            panel.className = 'su-tour-spotlight-panel';
            panel.addEventListener('click', suTourClose);
            suTourOverlay.appendChild(panel);
        });
        document.body.appendChild(suTourOverlay);
        suTourHighlightRing = document.createElement('div');
        suTourHighlightRing.className = 'su-tour-highlight-ring';
        suTourHighlightRing.setAttribute('aria-hidden', 'true');
        document.body.appendChild(suTourHighlightRing);
        suTourPopover = document.createElement('div');
        suTourPopover.className = 'su-tour-popover';
        suTourPopover.innerHTML = '<button type="button" class="su-tour-close" aria-label="Close">&times;</button><h3 class="su-tour-title"></h3><p class="su-tour-desc"></p><div class="su-tour-popover-footer"><span class="su-tour-progress"></span><span><button type="button" class="su-tour-prev">&larr; Previous</button><button type="button" class="su-tour-next">Next →</button></span></div>';
        suTourPopover.querySelector('.su-tour-close').onclick = suTourClose;
        suTourPopover.querySelector('.su-tour-prev').onclick = function() { suTourShowStep(suTourIndex - 1); };
        suTourPopover.querySelector('.su-tour-next').onclick = function() {
            if (suTourIndex === SU_TOUR_STEPS.length - 1) suTourClose();
            else suTourShowStep(suTourIndex + 1);
        };
        document.body.appendChild(suTourPopover);
        suTourShowStep(0);
    }

    window.startSuperUserTour = startSuperUserTour;

    document.addEventListener('DOMContentLoaded', function() {
        var tourBtn = document.getElementById('su-take-tour-btn');
        if (tourBtn) tourBtn.addEventListener('click', startSuperUserTour);
    });
})();
