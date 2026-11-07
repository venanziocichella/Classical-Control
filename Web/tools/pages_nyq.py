"""Page definitions of the Nyquist demos (Chapter 9)."""

NYQ_PAGES = {}

NYQ_PAGES['contour-mapping'] = dict(
    title='Contour Mapping', h1='Nyquist: mapping contours through L(s)',
    lead='Draw a curve or a closed contour on the s-plane and watch its image L(s) on the L-plane, live. '
         'Count the encirclements of −1, and follow the phasors of the poles and zeros.',
    matlab='Nyquist/Contour Mapping/NYQ_Mapping_Demo.m',
    scripts=['engine.js', 'nyquist.js'],
    js=r"""
// L(s) is typed like C(s) in the other demos: numbers, s, + - * / ^ and parentheses.
// Starts with L(s) = 50/((s+1)(s+2)(s+3)) and the Nyquist contour.
NyquistSim.run({ L: '50/((s+1)*(s+2)*(s+3))' });
""")
