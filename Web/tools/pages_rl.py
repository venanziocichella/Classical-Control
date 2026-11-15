"""Page definitions of the Root Locus demos that are not a plant sim (Chapter 6)."""

RL_PAGES = {}

RL_PAGES['root-locus-animation'] = dict(
    title='Root Locus Animation', h1='Root locus: closed-loop poles as K varies',
    lead='Type the open loop L(s) = K·N(s)/D(s) (only N(s)/D(s); K stays in front) and slide K: '
         'the closed-loop poles move along the root locus.',
    matlab='Root Locus/Root Locus Animation/RL_Animation_Demo.m',
    scripts=['engine.js', 'rlocus.js'],
    js=r"""
// N(s)/D(s) is typed like C(s) in the other demos: numbers, s, + - * / ^ and parentheses.
// Starts with L(s) = K/((s-1)(s+5)(s+10)).
RootLocusSim.run({ L: '1/((s-1)*(s+5)*(s+10))' });
""")
