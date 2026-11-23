/* GoatCounter analytics: page views + link clicks (no cookies).
   Set GC_CODE to your GoatCounter site code (the "xyz" in xyz.goatcounter.com). */
(function () {
  var GC_CODE = 'me3600';
  if (GC_CODE === 'YOURCODE') return;
  var s = document.createElement('script');
  s.async = true;
  s.src = 'https://gc.zgo.at/count.js';
  s.setAttribute('data-goatcounter', 'https://' + GC_CODE + '.goatcounter.com/count');
  document.head.appendChild(s);

  // Count every link click (lecture notes, homework PDFs, .m files, "Run in the browser").
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href]');
    if (!a || !window.goatcounter || !window.goatcounter.count) return;
    var url = new URL(a.href, location.href);
    var path = url.origin === location.origin ? decodeURIComponent(url.pathname) : url.href;
    var card = a.closest('.hm-card');
    var h = card && card.querySelector('h3');
    window.goatcounter.count({
      path: 'click: ' + path,
      title: (h ? h.textContent + ' | ' : '') + a.textContent.trim(),
      event: true
    });
  });
})();
