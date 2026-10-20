# Frequency Response demos (Chapter 7)

Four classroom demos of what a linear system does to a sinusoid: the output
is a sinusoid at **the same frequency**, scaled by |G(jω)| and shifted by
∠G(jω). Each folder has its own README with how to run the demo and what to
say in class.

| Folder | System | G(s) | Main file |
| --- | --- | --- | --- |
| `Servo (First Order)` | DC motor speed servo (low-pass) | K/(τs+1) | `FR_Servo_Demo.m` |
| `Spring Damper (High Pass)` | spring and dashpot in series (zero at the origin, high-pass) | τs/(τs+1) | `FR_SpringDamper_Demo.m` |
| `Mass Spring Damper (Second Order)` | force-driven mass-spring-damper (resonant low-pass) | ωn²/(s²+2ζωn s+ωn²) | `FR_MSD_Demo.m` |
| `Muffled Song` | a jungle track played through the filters, real-time audio | 1/(τs+1), τs/(τs+1), second order | `FR_Muffled_Song_Demo.m` |

The three mechanical demos share the same layout:
- the animated mechanism driven by a sinusoidal input of adjustable frequency and amplitude
- the input and output on one time plot, with the time shift between the peaks marked
- the Bode plot, with a marker at the current frequency
- a verdict, AMPLIFIED or ATTENUATED, with the theoretical |G(jω)| and ∠G(jω) next to the values measured from the simulation

They need only base MATLAB (R2021a or newer). The song demo uses the Audio
Toolbox for real-time audio, if available.

Suggested order in class: servo (low-pass), spring-damper (high-pass), mass-spring-damper (resonance), then the song, to *hear* the same Bode plots.
