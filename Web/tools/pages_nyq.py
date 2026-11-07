"""Page definitions of the Nyquist demos (Chapter 9)."""

NYQ_PAGES = {}

NYQ_PAGES['contour-mapping'] = dict(
    title='Contour Mapping', h1='Nyquist: mapping contours through L(s)',
    lead='Draw a curve or a closed contour on the s-plane and watch its image L(s) on the L-plane, live. '
         'Count the encirclements of the origin (Cauchy) or of −1 (Nyquist), and follow the phasors of the poles and zeros.',
    matlab='Nyquist/Contour Mapping/NYQ_Mapping_Demo.m',
    scripts=['engine.js', 'nyquist.js'],
    js=r"""
// L(s) is typed like C(s) in the other demos: numbers, s, + - * / ^ and parentheses.
// Default: 3 zeros (2, 2 ± 2j) and 3 poles (-4, -1, 3), contour around one pole and three zeros.
NyquistSim.run({ preset: 5 });
""")
